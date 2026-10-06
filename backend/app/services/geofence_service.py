import json
from typing import Optional, Tuple, List
from app.repositories.geofence_repository import GeofenceRepository
from app.repositories.station_repository import StationRepository
from app.schemas.journey import LocationEvidenceInput, GeofenceValidationResult
from app.core.s2 import calculate_haversine_distance, get_s2_cell_token
from app.core.logging import logger


class GeofenceService:
    def __init__(
        self,
        geofence_repo: GeofenceRepository,
        station_repo: StationRepository,
        redis=None,
    ):
        self.geofence_repo = geofence_repo
        self.station_repo = station_repo
        self.redis = redis

    async def get_station_geofence(self, station_id: str):
        """Retrieve active geofence for a station."""
        return await self.geofence_repo.get_by_station_id(station_id)

    async def validate_location_for_station(
        self,
        station_id: str,
        location: LocationEvidenceInput,
        client_key: Optional[str] = None,
    ) -> GeofenceValidationResult:
        """
        Validates whether location evidence reliably places the user inside a station geofence.
        Considers GPS uncertainty (accuracy_meters), geofence radius, and hysteresis debouncing.
        """
        station = await self.station_repo.get_by_id(station_id)
        if not station:
            return GeofenceValidationResult(
                station_id=station_id,
                station_name="Unknown Station",
                distance_meters=999999.0,
                geofence_radius_meters=300.0,
                accuracy_meters=location.accuracy_meters,
                is_inside=False,
                state="UNKNOWN",
                confidence=0.0,
                uncertainty_margin_meters=location.accuracy_meters,
                message=f"Station {station_id} not found in transit registry.",
            )

        geofence = await self.geofence_repo.get_by_station_id(station_id)
        center_lat = geofence.center_latitude if geofence else station.latitude
        center_lng = geofence.center_longitude if geofence else station.longitude
        radius = geofence.radius_meters if geofence else 300.0

        # 1. Great-circle spherical distance
        distance = calculate_haversine_distance(
            location.latitude,
            location.longitude,
            center_lat,
            center_lng,
        )

        acc = max(1.0, location.accuracy_meters)

        # 2. Uncertainty assessment
        # If accuracy is worse than 150m or larger than 75% of the station radius, location evidence is weak
        is_low_accuracy = acc > 150.0 or acc > (radius * 0.75)

        # Calculate normalized location confidence [0.0 - 1.0]
        # High accuracy (<15m) -> 1.0; low accuracy (>150m) -> degraded
        if acc <= 15.0:
            confidence = 1.0
        elif acc <= 50.0:
            confidence = 0.85
        elif acc <= 100.0:
            confidence = 0.65
        elif acc <= 200.0:
            confidence = 0.40
        else:
            confidence = 0.15

        if location.is_mock:
            confidence *= 0.2

        # 3. Geometric state classification
        # Inside threshold requires distance <= radius + uncertainty tolerance
        raw_is_inside = distance <= radius

        # Boundary zone: within +/- half of accuracy radius around geofence perimeter
        uncertainty_margin = acc / 2.0
        inner_bound = max(0.0, radius - uncertainty_margin)
        outer_bound = radius + uncertainty_margin

        if is_low_accuracy:
            preliminary_state = "LOW_CONFIDENCE"
            is_inside_decision = False
        elif distance <= inner_bound:
            preliminary_state = "INSIDE"
            is_inside_decision = True
        elif distance >= outer_bound:
            preliminary_state = "OUTSIDE"
            is_inside_decision = False
        else:
            # Inside boundary jitter zone
            preliminary_state = "ENTERING" if distance <= radius else "EXITING"
            is_inside_decision = distance <= radius

        # 4. Hysteresis / Debouncing via Redis
        final_state = preliminary_state
        if self.redis and client_key:
            hysteresis_key = f"geofence:hysteresis:{client_key}:{station_id}"
            try:
                cached_data = await self.redis.get(hysteresis_key)
                if cached_data:
                    state_info = json.loads(cached_data)
                    last_state = state_info.get("last_state", preliminary_state)
                    streak = state_info.get("streak", 1)

                    if preliminary_state == last_state:
                        streak += 1
                    else:
                        # State changed. Require at least 2 consecutive readings to flip between INSIDE and OUTSIDE
                        if preliminary_state in ("INSIDE", "OUTSIDE") and last_state in ("INSIDE", "OUTSIDE"):
                            if streak >= 2:
                                # First reading of flipped state: debounce to boundary state
                                preliminary_state = "ENTERING" if preliminary_state == "INSIDE" else "EXITING"
                                streak = 1
                            else:
                                streak = 1
                    final_state = preliminary_state
                    await self.redis.set(
                        hysteresis_key,
                        json.dumps({"last_state": preliminary_state, "streak": streak}),
                        ex=300,
                    )
                else:
                    await self.redis.set(
                        hysteresis_key,
                        json.dumps({"last_state": preliminary_state, "streak": 1}),
                        ex=300,
                    )
            except Exception as e:
                logger.warning("Redis hysteresis check failed: %s", e)

        message = (
            f"Within {distance:.1f}m of {station.display_name} (radius: {radius:.0f}m, uncertainty: ±{acc:.1f}m)"
            if is_inside_decision
            else f"Outside {station.display_name} geofence by {max(0.0, distance - radius):.1f}m (dist: {distance:.1f}m)"
        )

        return GeofenceValidationResult(
            station_id=station_id,
            station_name=station.display_name,
            distance_meters=round(distance, 1),
            geofence_radius_meters=radius,
            accuracy_meters=round(acc, 1),
            is_inside=is_inside_decision,
            state=final_state,
            confidence=round(confidence, 2),
            uncertainty_margin_meters=round(uncertainty_margin, 1),
            message=message,
        )

    async def check_nearby_station_ambiguity(
        self,
        location: LocationEvidenceInput,
        candidate_station_ids: List[str],
    ) -> Tuple[Optional[str], bool, str]:
        """
        Resolves station ambiguity when multiple stations are nearby (e.g. Dadar WR & Dadar CR).
        Returns (best_station_id, is_ambiguous, reason).
        """
        if not candidate_station_ids:
            return None, False, "No candidate stations"

        results = []
        for sid in candidate_station_ids:
            res = await self.validate_location_for_station(sid, location)
            results.append(res)

        results.sort(key=lambda r: r.distance_meters)
        best = results[0]

        if len(results) > 1:
            second_best = results[1]
            diff = abs(second_best.distance_meters - best.distance_meters)
            # If difference between the two nearest stations is less than GPS accuracy and both inside/near
            if diff < location.accuracy_meters and best.distance_meters <= (best.geofence_radius_meters * 1.5):
                return (
                    best.station_id,
                    True,
                    f"Ambiguity detected between {best.station_name} ({best.distance_meters}m) and "
                    f"{second_best.station_name} ({second_best.distance_meters}m) within GPS uncertainty (±{location.accuracy_meters}m)",
                )

        return best.station_id, False, f"Nearest station {best.station_name} at {best.distance_meters}m"
