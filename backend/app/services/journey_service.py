import json
from datetime import datetime, timezone
from typing import Optional, List, Tuple, Dict, Any
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.journey import Journey, JourneyStatus, JourneySecurityState
from app.models.ticket import Ticket, TicketStatus
from app.models.location_event import LocationEvent, LocationIntegrityStatus
from app.models.fraud_event import FraudEventType, FraudSeverity
from app.repositories.journey_repository import JourneyRepository
from app.repositories.ticket_repository import TicketRepository
from app.repositories.station_repository import StationRepository
from app.repositories.location_event_repository import LocationEventRepository
from app.services.geofence_service import GeofenceService
from app.services.location_integrity_service import LocationIntegrityService
from app.schemas.journey import (
    LocationEvidenceInput,
    JourneyRead,
    JourneyStatusResponse,
)
from app.core.s2 import get_s2_cell_token, calculate_haversine_distance
from app.core.logging import logger


class JourneyService:
    def __init__(
        self,
        journey_repo: JourneyRepository,
        ticket_repo: TicketRepository,
        station_repo: StationRepository,
        location_repo: LocationEventRepository,
        geofence_service: GeofenceService,
        integrity_service: LocationIntegrityService,
        redis=None,
        decision_engine=None,
        fraud_extractor=None,
    ):
        self.journey_repo = journey_repo
        self.ticket_repo = ticket_repo
        self.station_repo = station_repo
        self.location_repo = location_repo
        self.geofence_service = geofence_service
        self.integrity_service = integrity_service
        self.redis = redis
        self.decision_engine = decision_engine
        self.fraud_extractor = fraud_extractor

    async def start_journey(
        self,
        user_id: str,
        ticket_id: str,
        location: LocationEvidenceInput,
        device_id: Optional[str] = None,
        route_id: Optional[str] = None,
    ) -> Tuple[bool, str, Optional[Journey]]:
        """
        Server-controlled journey start workflow.
        Verifies ticket ownership, valid status, active locks, and origin station geofence evidence.
        """
        device_id = device_id or "loco-client-app"
        server_now = datetime.now(timezone.utc)

        # 1. Fetch ticket and verify ownership
        ticket = await self.ticket_repo.get_by_id(ticket_id)
        if not ticket:
            return False, "Ticket not found.", None

        if ticket.user_id != user_id:
            return False, "Unauthorized: Ticket does not belong to the current commuter.", None

        # 2. Check ticket lifecycle status
        valid_start_statuses = [
            TicketStatus.ISSUED.value,
            TicketStatus.ACTIVE.value,
        ]
        if ticket.ticket_status not in valid_start_statuses:
            return False, f"Ticket cannot be started. Current status is {ticket.ticket_status}.", None

        # 3. Check validity window
        if ticket.valid_until is not None:
            v_until = ticket.valid_until
            if v_until.tzinfo is None:
                v_until = v_until.replace(tzinfo=timezone.utc)
            if server_now > v_until:
                return False, "Ticket has expired.", None

        # 4. Check for active journey locks (prevent duplicate journeys for same ticket/user)
        active_for_ticket = await self.journey_repo.get_active_for_ticket(ticket_id)
        if active_for_ticket:
            return False, f"An active journey ({active_for_ticket.id}) already exists for this ticket.", None

        if self.redis:
            user_lock_key = f"journey:lock:user:{user_id}"
            has_lock = await self.redis.get(user_lock_key)
            if has_lock:
                return False, "Another active journey is currently in progress for this commuter account.", None

        # 5. Origin Station Geofence Validation
        geofence_result = await self.geofence_service.validate_location_for_station(
            station_id=ticket.origin_station_id,
            location=location,
            client_key=user_id,
        )

        # If commuter is outside origin station geofence, reject start
        if not geofence_result.is_inside and geofence_result.state != "ENTERING":
            logger.warning(
                "Journey start rejected for user %s: outside origin station %s (distance: %sm, radius: %sm)",
                user_id,
                ticket.origin_station_id,
                geofence_result.distance_meters,
                geofence_result.geofence_radius_meters,
            )
            return (
                False,
                f"You must be at or near {geofence_result.station_name} to start your journey. "
                f"Currently {geofence_result.distance_meters:.0f}m away (boundary radius: {geofence_result.geofence_radius_meters:.0f}m).",
                None,
            )

        # 6. Evaluate initial location integrity signals
        integrity_res = await self.integrity_service.evaluate_location(
            user_id=user_id,
            device_id=device_id,
            current_location=location,
            journey=None,
            last_event=None,
            server_now=server_now,
        )

        # 7. Create Journey record
        journey = Journey(
            ticket_id=ticket_id,
            user_id=user_id,
            device_id=device_id,
            origin_station_id=ticket.origin_station_id,
            destination_station_id=ticket.destination_station_id,
            route_id=route_id,
            status=JourneyStatus.ACTIVE.value,
            started_at=server_now,
            current_station_id=ticket.origin_station_id,
            last_validated_station_id=ticket.origin_station_id,
            security_state=integrity_res.security_state,
            location_confidence=integrity_res.location_confidence,
            risk_score=integrity_res.risk_score,
        )
        await self.journey_repo.create(journey)

        # 8. Record initial LocationEvent
        s2_token = get_s2_cell_token(location.latitude, location.longitude, level=15)
        dev_ts = location.timestamp_device or server_now
        if dev_ts.tzinfo is None:
            dev_ts = dev_ts.replace(tzinfo=timezone.utc)

        loc_event = LocationEvent(
            user_id=user_id,
            device_id=device_id,
            journey_id=journey.id,
            ticket_id=ticket_id,
            latitude=location.latitude,
            longitude=location.longitude,
            accuracy_meters=location.accuracy_meters,
            altitude=location.altitude,
            speed_mps=location.speed_mps,
            bearing=location.bearing,
            timestamp_device=dev_ts,
            timestamp_server=server_now,
            provider=location.provider,
            is_mock=location.is_mock,
            mock_confidence=location.mock_confidence,
            location_source="journey_start",
            integrity_status=(
                LocationIntegrityStatus.VALID.value
                if integrity_res.risk_score < 0.70
                else LocationIntegrityStatus.SUSPICIOUS.value
            ),
            s2_cell_token=s2_token,
        )
        await self.location_repo.create(loc_event)

        # 9. Update ticket status to IN_JOURNEY
        ticket.ticket_status = TicketStatus.IN_JOURNEY.value
        await self.ticket_repo.update(ticket)

        # 10. Set Redis active journey locks
        if self.redis:
            await self.redis.set(f"journey:lock:user:{user_id}", journey.id, ex=86400)
            await self.redis.set(f"journey:active:{journey.id}", json.dumps({
                "journey_id": journey.id,
                "ticket_id": ticket_id,
                "status": journey.status,
                "origin_id": journey.origin_station_id,
                "destination_id": journey.destination_station_id,
            }), ex=86400)

        logger.info(
            "Journey %s started successfully for ticket %s (Commuter: %s, Origin: %s)",
            journey.id,
            ticket_id,
            user_id,
            ticket.origin_station_id,
        )
        return True, "Journey started and Journey Guardian active.", journey

    async def process_location(
        self,
        journey_id: str,
        user_id: str,
        location: LocationEvidenceInput,
        device_id: Optional[str] = None,
    ) -> Tuple[bool, str, Optional[Journey], List[str]]:
        """
        Ingest a location update during an active journey.
        Verifies ownership, evaluates location integrity, detects current station context,
        and identifies route deviation.
        """
        device_id = device_id or "loco-client-app"
        server_now = datetime.now(timezone.utc)

        # 1. Fetch journey
        journey = await self.journey_repo.get_by_id(journey_id)
        if not journey:
            return False, "Journey not found.", None, []

        if journey.user_id != user_id:
            return False, "Unauthorized: Journey does not belong to commuter.", None, []

        if journey.status != JourneyStatus.ACTIVE.value:
            return False, f"Journey is not active (current status: {journey.status}).", None, []

        # 2. Rate limiting (max 1 submission per 1.5s per journey)
        if self.redis:
            rate_key = f"rate:journey:loc:{journey_id}"
            is_limited = await self.redis.get(rate_key)
            if is_limited:
                # Do not reject completely, but debounce high-frequency flood
                pass
            else:
                await self.redis.set(rate_key, "1", ex=1)

        # 3. Retrieve last location event for movement physics
        last_event = await self.location_repo.get_last_for_journey(journey_id)

        # 4. Evaluate location integrity
        integrity_res = await self.integrity_service.evaluate_location(
            user_id=user_id,
            device_id=device_id,
            current_location=location,
            journey=journey,
            last_event=last_event,
            server_now=server_now,
        )

        # 5. Route stations and station progression evaluation
        route_stations = await self._get_route_station_sequence(journey)
        active_signals = [s["type"] for s in integrity_res.signals]

        is_deviated, deviation_reason = await self._check_route_deviation(
            location=location,
            route_stations=route_stations,
            journey=journey,
        )

        if is_deviated:
            active_signals.append(FraudEventType.ROUTE_DEVIATION.value)
            integrity_res.security_state = JourneySecurityState.ROUTE_DEVIATION.value
            journey.security_state = JourneySecurityState.ROUTE_DEVIATION.value

        # 6. Detect Current Station along route
        nearest_station = await self._detect_current_station(location, route_stations)
        if nearest_station:
            journey.current_station_id = nearest_station.id
            journey.last_validated_station_id = nearest_station.id

        # 7. Update Journey security metrics
        journey.security_state = integrity_res.security_state
        journey.location_confidence = integrity_res.location_confidence
        journey.risk_score = integrity_res.risk_score

        # Phase 5: Custom ML Fraud Decision Engine integration
        if self.decision_engine and self.fraud_extractor:
            try:
                ticket = await self.ticket_repo.get_by_id(journey.ticket_id)
                vector, conf = await self.fraud_extractor.extract_features(
                    user_id=user_id,
                    ticket_id=journey.ticket_id,
                    journey_id=journey.id,
                    device_id=device_id,
                    current_location=location,
                )
                decision, prediction = await self.decision_engine.evaluate_decision(
                    user_id=user_id,
                    feature_vector=vector,
                    ticket=ticket,
                    journey=journey,
                    context_action="JOURNEY_UPDATE",
                )
                journey.risk_score = prediction.risk_score
                if decision.decision in ["BLOCK", "RESTRICT"]:
                    journey.security_state = JourneySecurityState.SUSPICIOUS.value
                    active_signals.append("FRAUD_DECISION_BLOCKED")
                elif decision.decision == "CHALLENGE":
                    journey.security_state = JourneySecurityState.SECURITY_WARNING.value
                    active_signals.append("FRAUD_DECISION_CHALLENGE")
                elif decision.decision == "MONITOR":
                    if journey.security_state == JourneySecurityState.NORMAL.value:
                        journey.security_state = JourneySecurityState.LOCATION_UNCERTAIN.value
            except Exception as e:
                logger.error(f"[JourneyService] Error evaluating fraud decision: {e}")

        await self.journey_repo.update(journey)

        # 8. Record LocationEvent
        s2_token = get_s2_cell_token(location.latitude, location.longitude, level=15)
        dev_ts = location.timestamp_device or server_now
        if dev_ts.tzinfo is None:
            dev_ts = dev_ts.replace(tzinfo=timezone.utc)

        loc_event = LocationEvent(
            user_id=user_id,
            device_id=device_id,
            journey_id=journey_id,
            ticket_id=journey.ticket_id,
            latitude=location.latitude,
            longitude=location.longitude,
            accuracy_meters=location.accuracy_meters,
            altitude=location.altitude,
            speed_mps=location.speed_mps,
            bearing=location.bearing,
            timestamp_device=dev_ts,
            timestamp_server=server_now,
            provider=location.provider,
            is_mock=location.is_mock,
            mock_confidence=location.mock_confidence,
            location_source=location.location_source,
            integrity_status=(
                LocationIntegrityStatus.VALID.value
                if integrity_res.risk_score < 0.70
                else LocationIntegrityStatus.SUSPICIOUS.value
            ),
            s2_cell_token=s2_token,
        )
        await self.location_repo.create(loc_event)

        return True, "Location processed.", journey, active_signals

    async def process_locations_batch(
        self,
        journey_id: str,
        user_id: str,
        locations: List[LocationEvidenceInput],
        device_id: Optional[str] = None,
    ) -> Tuple[bool, str, Optional[Journey], List[str]]:
        """
        Process a batch of chronological location updates from commuter client.
        Reduces battery consumption and mobile network round trips.
        """
        if not locations:
            return False, "Batch must contain at least one location observation.", None, []

        last_journey = None
        all_signals = set()

        for loc in locations:
            success, msg, journey, signals = await self.process_location(
                journey_id=journey_id,
                user_id=user_id,
                location=loc,
                device_id=device_id,
            )
            if success and journey:
                last_journey = journey
                all_signals.update(signals)

        if not last_journey:
            return False, "Failed to process location batch.", None, []

        return True, f"Successfully processed {len(locations)} location events.", last_journey, list(all_signals)

    async def complete_journey(
        self,
        journey_id: str,
        user_id: str,
        location: LocationEvidenceInput,
    ) -> Tuple[bool, str, Optional[Journey]]:
        """
        Server-controlled journey completion.
        Only transitions to COMPLETED when destination station geofence evidence is validated.
        """
        server_now = datetime.now(timezone.utc)
        journey = await self.journey_repo.get_by_id(journey_id)
        if not journey:
            return False, "Journey not found.", None

        if journey.user_id != user_id:
            return False, "Unauthorized: Journey does not belong to commuter.", None

        if journey.status != JourneyStatus.ACTIVE.value:
            return False, f"Journey is already in status {journey.status}.", None

        # 1. Authoritative Destination Geofence Validation
        dest_validation = await self.geofence_service.validate_location_for_station(
            station_id=journey.destination_station_id,
            location=location,
            client_key=user_id,
        )

        if not dest_validation.is_inside and dest_validation.state != "ENTERING":
            return (
                False,
                f"Destination arrival could not be verified. You are {dest_validation.distance_meters:.0f}m away "
                f"from {dest_validation.station_name} (geofence radius: {dest_validation.geofence_radius_meters:.0f}m).",
                None,
            )

        # 2. Record arrival LocationEvent
        s2_token = get_s2_cell_token(location.latitude, location.longitude, level=15)
        dev_ts = location.timestamp_device or server_now
        if dev_ts.tzinfo is None:
            dev_ts = dev_ts.replace(tzinfo=timezone.utc)

        loc_event = LocationEvent(
            user_id=user_id,
            device_id=journey.device_id,
            journey_id=journey.id,
            ticket_id=journey.ticket_id,
            latitude=location.latitude,
            longitude=location.longitude,
            accuracy_meters=location.accuracy_meters,
            altitude=location.altitude,
            speed_mps=location.speed_mps,
            bearing=location.bearing,
            timestamp_device=dev_ts,
            timestamp_server=server_now,
            provider=location.provider,
            is_mock=location.is_mock,
            mock_confidence=location.mock_confidence,
            location_source="journey_complete",
            integrity_status=LocationIntegrityStatus.VALID.value,
            s2_cell_token=s2_token,
        )
        await self.location_repo.create(loc_event)

        # 3. Transition Journey state to COMPLETED
        journey.status = JourneyStatus.COMPLETED.value
        journey.completed_at = server_now
        journey.current_station_id = journey.destination_station_id
        journey.last_validated_station_id = journey.destination_station_id
        await self.journey_repo.update(journey)

        # 4. Transition Ticket state to COMPLETED
        ticket = await self.ticket_repo.get_by_id(journey.ticket_id)
        if ticket:
            ticket.ticket_status = TicketStatus.COMPLETED.value
            await self.ticket_repo.update(ticket)

        # 5. Clear Redis locks
        if self.redis:
            await self.redis.delete(f"journey:lock:user:{user_id}")
            await self.redis.delete(f"journey:active:{journey.id}")

        logger.info(
            "Journey %s completed successfully at destination %s for commuter %s",
            journey.id,
            journey.destination_station_id,
            user_id,
        )
        return True, "Journey completed successfully.", journey

    async def abandon_journey(
        self,
        journey_id: str,
        user_id: str,
        reason: str = "User abandoned journey",
    ) -> Tuple[bool, str, Optional[Journey]]:
        """
        Abandon active journey when commuter exits network or requests cancellation.
        """
        journey = await self.journey_repo.get_by_id(journey_id)
        if not journey:
            return False, "Journey not found.", None

        if journey.user_id != user_id:
            return False, "Unauthorized: Journey does not belong to commuter.", None

        if journey.status != JourneyStatus.ACTIVE.value:
            return False, f"Journey is already in status {journey.status}.", None

        journey.status = JourneyStatus.ABANDONED.value
        journey.completed_at = datetime.now(timezone.utc)
        await self.journey_repo.update(journey)

        ticket = await self.ticket_repo.get_by_id(journey.ticket_id)
        if ticket and ticket.ticket_status == TicketStatus.IN_JOURNEY.value:
            ticket.ticket_status = TicketStatus.EXPIRED.value
            await self.ticket_repo.update(ticket)

        if self.redis:
            await self.redis.delete(f"journey:lock:user:{user_id}")
            await self.redis.delete(f"journey:active:{journey.id}")

        return True, "Journey marked as abandoned.", journey

    async def build_journey_read(self, journey: Journey) -> JourneyRead:
        """
        Builds user-facing JourneyRead model enriched with station names,
        evidence-backed station sequence progression, and next station context.
        """
        origin_station = await self.station_repo.get_by_id(journey.origin_station_id)
        dest_station = await self.station_repo.get_by_id(journey.destination_station_id)
        cur_station = (
            await self.station_repo.get_by_id(journey.current_station_id)
            if journey.current_station_id
            else origin_station
        )

        route_stations = await self._get_route_station_sequence(journey)
        total_count = max(2, len(route_stations))

        # Station sequence progress calculation (derives real station index, not timer)
        cur_idx = 0
        if cur_station and route_stations:
            for idx, s in enumerate(route_stations):
                if s.id == cur_station.id:
                    cur_idx = idx
                    break

        if journey.status == JourneyStatus.COMPLETED.value:
            progress_pct = 100.0
            completed_count = total_count
            next_station = None
        else:
            completed_count = cur_idx + 1
            progress_pct = round((cur_idx / max(1, total_count - 1)) * 100.0, 1)
            next_idx = min(total_count - 1, cur_idx + 1)
            next_station = route_stations[next_idx] if next_idx < len(route_stations) else dest_station

        return JourneyRead(
            id=journey.id,
            ticket_id=journey.ticket_id,
            user_id=journey.user_id,
            device_id=journey.device_id,
            origin_station_id=journey.origin_station_id,
            origin_station_name=origin_station.display_name if origin_station else "Origin",
            destination_station_id=journey.destination_station_id,
            destination_station_name=dest_station.display_name if dest_station else "Destination",
            route_id=journey.route_id,
            status=journey.status,
            started_at=journey.started_at,
            completed_at=journey.completed_at,
            current_station_id=cur_station.id if cur_station else None,
            current_station_name=cur_station.display_name if cur_station else None,
            next_station_id=next_station.id if next_station else None,
            next_station_name=next_station.display_name if next_station else None,
            last_validated_station_id=journey.last_validated_station_id,
            security_state=journey.security_state,
            location_confidence=journey.location_confidence,
            risk_score=journey.risk_score,
            progress_percent=progress_pct,
            completed_stations_count=completed_count,
            total_stations_count=total_count,
        )

    # ----------------- Internal Helper Methods -----------------

    async def _get_route_station_sequence(self, journey: Journey) -> List[Any]:
        """
        Determines the station sequence between origin and destination.
        """
        stations = await self.station_repo.get_all_active()
        if not stations:
            return []

        station_map = {s.id: s for s in stations}
        origin = station_map.get(journey.origin_station_id)
        dest = station_map.get(journey.destination_station_id)

        if not origin or not dest:
            return [origin or dest] if (origin or dest) else []

        # Find stations on the same zone/corridor between origin and dest
        corridor = [s for s in stations if s.zone == origin.zone or s.zone == dest.zone]
        corridor.sort(key=lambda s: s.latitude)

        # Ensure order matches origin -> destination
        if origin.latitude > dest.latitude:
            corridor.reverse()

        # Filter to bounding box range between origin and destination
        min_lat = min(origin.latitude, dest.latitude)
        max_lat = max(origin.latitude, dest.latitude)
        route_sequence = [s for s in corridor if min_lat - 0.02 <= s.latitude <= max_lat + 0.02]

        # Guarantee origin at start and destination at end
        if not route_sequence or route_sequence[0].id != origin.id:
            route_sequence.insert(0, origin)
        if route_sequence[-1].id != dest.id:
            route_sequence.append(dest)

        return route_sequence

    async def _detect_current_station(
        self,
        location: LocationEvidenceInput,
        route_stations: List[Any],
    ) -> Optional[Any]:
        """
        Detects which station along the route the commuter is currently at/near.
        """
        if not route_stations:
            return None

        for station in route_stations:
            dist = calculate_haversine_distance(
                location.latitude,
                location.longitude,
                station.latitude,
                station.longitude,
            )
            # Within 450m of station coordinates
            if dist <= 450.0:
                return station

        return None

    async def _check_route_deviation(
        self,
        location: LocationEvidenceInput,
        route_stations: List[Any],
        journey: Journey,
    ) -> Tuple[bool, Optional[str]]:
        """
        Evaluates whether observed movement is consistently departing from the railway route corridor.
        """
        if not route_stations:
            return False, None

        # Calculate minimum distance to any station along route corridor
        min_dist = min(
            calculate_haversine_distance(
                location.latitude,
                location.longitude,
                s.latitude,
                s.longitude,
            )
            for s in route_stations
        )

        # If user is farther than 3500m from any station on route corridor and accuracy is reasonable
        if min_dist > 3500.0 and location.accuracy_meters < 150.0:
            return True, f"Commuter observed {min_dist / 1000.0:.1f}km away from planned railway corridor."

        return False, None
