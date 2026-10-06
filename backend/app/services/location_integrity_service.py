import json
import math
from datetime import datetime, timezone
from typing import List, Tuple, Optional, Dict, Any
from app.models.fraud_event import FraudEvent, FraudEventType, FraudSeverity
from app.models.journey import Journey, JourneySecurityState
from app.models.location_event import LocationEvent
from app.schemas.journey import LocationEvidenceInput
from app.repositories.fraud_event_repository import FraudEventRepository
from app.core.s2 import calculate_haversine_distance
from app.core.logging import logger


class IntegrityEvaluationResult:
    def __init__(
        self,
        security_state: str,
        location_confidence: float,
        risk_score: float,
        signals: List[Dict[str, Any]],
        fraud_events: List[FraudEvent],
    ):
        self.security_state = security_state
        self.location_confidence = location_confidence
        self.risk_score = risk_score
        self.signals = signals
        self.fraud_events = fraud_events


class LocationIntegrityService:
    def __init__(
        self,
        fraud_repo: FraudEventRepository,
        redis=None,
    ):
        self.fraud_repo = fraud_repo
        self.redis = redis

    async def evaluate_location(
        self,
        user_id: str,
        device_id: str,
        current_location: LocationEvidenceInput,
        journey: Optional[Journey] = None,
        last_event: Optional[LocationEvent] = None,
        server_now: Optional[datetime] = None,
    ) -> IntegrityEvaluationResult:
        """
        Multi-signal location integrity analysis.
        Evaluates location evidence across physical speed, spatial continuity,
        mock indicators, clock consistency, sensor coherence, and anti-replay.
        """
        if server_now is None:
            server_now = datetime.now(timezone.utc)

        signals: List[Dict[str, Any]] = []
        fraud_events: List[FraudEvent] = []
        risk_points = 0.0
        confidence = 1.0

        journey_id = journey.id if journey else None
        ticket_id = journey.ticket_id if journey else None

        # -------------------------------------------------------------
        # Signal 1: GPS Accuracy & Uncertainty
        # -------------------------------------------------------------
        acc = current_location.accuracy_meters
        if acc > 250.0:
            signals.append({
                "type": FraudEventType.LOW_ACCURACY.value,
                "severity": FraudSeverity.LOW.value,
                "value": acc,
                "threshold": 250.0,
                "description": f"Severe GPS uncertainty of ±{acc:.0f}m detected.",
            })
            risk_points += 0.20
            confidence *= 0.35
            fraud_events.append(
                FraudEvent(
                    user_id=user_id,
                    ticket_id=ticket_id,
                    journey_id=journey_id,
                    device_id=device_id,
                    event_type=FraudEventType.LOW_ACCURACY.value,
                    severity=FraudSeverity.LOW.value,
                    confidence=0.90,
                    metadata_json=json.dumps({"accuracy_meters": acc}),
                )
            )
        elif acc > 150.0:
            signals.append({
                "type": FraudEventType.LOW_ACCURACY.value,
                "severity": FraudSeverity.INFO.value,
                "value": acc,
                "threshold": 150.0,
                "description": f"Moderate GPS uncertainty of ±{acc:.0f}m.",
            })
            risk_points += 0.10
            confidence *= 0.60

        # -------------------------------------------------------------
        # Signal 2: Mock Location Indicator
        # -------------------------------------------------------------
        if current_location.is_mock or current_location.mock_confidence >= 0.5:
            severity = FraudSeverity.HIGH.value
            signals.append({
                "type": FraudEventType.MOCK_LOCATION.value,
                "severity": severity,
                "value": current_location.mock_confidence,
                "threshold": 0.5,
                "description": "Device mock/fake location provider actively asserted.",
            })
            risk_points += 0.45
            confidence *= 0.20
            fraud_events.append(
                FraudEvent(
                    user_id=user_id,
                    ticket_id=ticket_id,
                    journey_id=journey_id,
                    device_id=device_id,
                    event_type=FraudEventType.MOCK_LOCATION.value,
                    severity=severity,
                    confidence=max(0.8, current_location.mock_confidence),
                    metadata_json=json.dumps({
                        "is_mock": current_location.is_mock,
                        "mock_confidence": current_location.mock_confidence,
                        "provider": current_location.provider,
                    }),
                )
            )

        # -------------------------------------------------------------
        # Signal 3: Device Clock vs Authoritative Server Clock
        # -------------------------------------------------------------
        if current_location.timestamp_device is not None:
            # Ensure both are timezone-aware UTC for comparison
            dev_dt = current_location.timestamp_device
            if dev_dt.tzinfo is None:
                dev_dt = dev_dt.replace(tzinfo=timezone.utc)
            delta_seconds = abs((server_now - dev_dt).total_seconds())

            if delta_seconds > 120.0:
                signals.append({
                    "type": FraudEventType.CLOCK_ANOMALY.value,
                    "severity": FraudSeverity.MEDIUM.value,
                    "value": delta_seconds,
                    "threshold": 120.0,
                    "description": f"Clock drift anomaly of {delta_seconds:.0f}s between device and server.",
                })
                risk_points += 0.20
                confidence *= 0.75
                fraud_events.append(
                    FraudEvent(
                        user_id=user_id,
                        ticket_id=ticket_id,
                        journey_id=journey_id,
                        device_id=device_id,
                        event_type=FraudEventType.CLOCK_ANOMALY.value,
                        severity=FraudSeverity.MEDIUM.value,
                        confidence=0.85,
                        metadata_json=json.dumps({
                            "device_timestamp": dev_dt.isoformat(),
                            "server_timestamp": server_now.isoformat(),
                            "drift_seconds": delta_seconds,
                        }),
                    )
                )

        # -------------------------------------------------------------
        # Signal 4: Movement Physics (Velocity & Teleportation)
        # -------------------------------------------------------------
        if last_event is not None:
            # Use authoritative server timestamps between consecutive observations
            t_last = last_event.timestamp_server
            if t_last.tzinfo is None:
                t_last = t_last.replace(tzinfo=timezone.utc)
            time_delta_sec = max(0.1, (server_now - t_last).total_seconds())

            dist_meters = calculate_haversine_distance(
                last_event.latitude,
                last_event.longitude,
                current_location.latitude,
                current_location.longitude,
            )

            speed_mps = dist_meters / time_delta_sec
            speed_kmh = speed_mps * 3.6

            # Teleportation: large distance jump in very short time
            if dist_meters > 5000.0 and time_delta_sec < 30.0:
                signals.append({
                    "type": FraudEventType.TELEPORTATION.value,
                    "severity": FraudSeverity.CRITICAL.value,
                    "value": dist_meters,
                    "time_seconds": time_delta_sec,
                    "speed_kmh": round(speed_kmh, 1),
                    "threshold": 5000.0,
                    "description": f"Teleportation jump of {dist_meters / 1000.0:.1f}km in {time_delta_sec:.1f}s.",
                })
                risk_points += 0.60
                confidence *= 0.10
                fraud_events.append(
                    FraudEvent(
                        user_id=user_id,
                        ticket_id=ticket_id,
                        journey_id=journey_id,
                        device_id=device_id,
                        event_type=FraudEventType.TELEPORTATION.value,
                        severity=FraudSeverity.CRITICAL.value,
                        confidence=0.98,
                        metadata_json=json.dumps({
                            "distance_meters": dist_meters,
                            "time_delta_seconds": time_delta_sec,
                            "speed_kmh": round(speed_kmh, 1),
                            "prev_lat": last_event.latitude,
                            "prev_lng": last_event.longitude,
                            "cur_lat": current_location.latitude,
                            "cur_lng": current_location.longitude,
                        }),
                    )
                )
            elif speed_kmh > 160.0:
                # Physically implausible speed on urban suburban railway
                signals.append({
                    "type": FraudEventType.IMPOSSIBLE_SPEED.value,
                    "severity": FraudSeverity.HIGH.value,
                    "value": round(speed_kmh, 1),
                    "threshold": 160.0,
                    "description": f"Impossible travel speed: {speed_kmh:.1f} km/h between observations.",
                })
                risk_points += 0.40
                confidence *= 0.30
                fraud_events.append(
                    FraudEvent(
                        user_id=user_id,
                        ticket_id=ticket_id,
                        journey_id=journey_id,
                        device_id=device_id,
                        event_type=FraudEventType.IMPOSSIBLE_SPEED.value,
                        severity=FraudSeverity.HIGH.value,
                        confidence=0.92,
                        metadata_json=json.dumps({
                            "calculated_speed_kmh": round(speed_kmh, 1),
                            "distance_meters": dist_meters,
                            "time_delta_seconds": time_delta_sec,
                        }),
                    )
                )

        # -------------------------------------------------------------
        # Signal 5: Sensor Consistency (GPS Speed vs Accelerometer)
        # -------------------------------------------------------------
        if (
            current_location.device_moving_sensor is not None
            and current_location.speed_mps is not None
        ):
            gps_speed_kmh = current_location.speed_mps * 3.6
            # If GPS reports train movement > 40 km/h but accelerometer says device is completely stationary
            if not current_location.device_moving_sensor and gps_speed_kmh > 40.0:
                signals.append({
                    "type": FraudEventType.SENSOR_INCONSISTENCY.value,
                    "severity": FraudSeverity.MEDIUM.value,
                    "value": round(gps_speed_kmh, 1),
                    "description": f"Inconsistency: GPS reports {gps_speed_kmh:.0f} km/h but motion sensor indicates stationary.",
                })
                risk_points += 0.25
                confidence *= 0.65
                fraud_events.append(
                    FraudEvent(
                        user_id=user_id,
                        ticket_id=ticket_id,
                        journey_id=journey_id,
                        device_id=device_id,
                        event_type=FraudEventType.SENSOR_INCONSISTENCY.value,
                        severity=FraudSeverity.MEDIUM.value,
                        confidence=0.80,
                        metadata_json=json.dumps({
                            "gps_speed_kmh": gps_speed_kmh,
                            "sensor_moving": current_location.device_moving_sensor,
                        }),
                    )
                )

        # -------------------------------------------------------------
        # Signal 6: Location Replay Protection
        # -------------------------------------------------------------
        if self.redis:
            # Check client event ID deduplication
            if current_location.client_event_id:
                replay_key = f"location:replay:{current_location.client_event_id}"
                is_replayed = await self.redis.get(replay_key)
                if is_replayed:
                    signals.append({
                        "type": FraudEventType.LOCATION_REPLAY.value,
                        "severity": FraudSeverity.HIGH.value,
                        "value": current_location.client_event_id,
                        "description": "Replay detected: Event ID has already been submitted.",
                    })
                    risk_points += 0.50
                    confidence *= 0.10
                    fraud_events.append(
                        FraudEvent(
                            user_id=user_id,
                            ticket_id=ticket_id,
                            journey_id=journey_id,
                            device_id=device_id,
                            event_type=FraudEventType.LOCATION_REPLAY.value,
                            severity=FraudSeverity.HIGH.value,
                            confidence=0.99,
                            metadata_json=json.dumps({"event_id": current_location.client_event_id}),
                        )
                    )
                else:
                    await self.redis.set(replay_key, "1", ex=3600)

        # -------------------------------------------------------------
        # Normalize Explainable Risk Score & Security State
        # -------------------------------------------------------------
        final_risk_score = round(min(1.0, max(0.0, risk_points)), 2)
        final_confidence = round(min(1.0, max(0.05, confidence)), 2)

        if final_risk_score >= 0.70:
            security_state = JourneySecurityState.SUSPICIOUS.value
        elif final_risk_score >= 0.40:
            security_state = JourneySecurityState.SECURITY_WARNING.value
        elif final_confidence < 0.50 or acc > 150.0:
            security_state = JourneySecurityState.LOCATION_UNCERTAIN.value
        else:
            security_state = JourneySecurityState.NORMAL.value

        # Persist generated fraud events for audit and ML model training datasets
        for fe in fraud_events:
            await self.fraud_repo.create(fe)

        return IntegrityEvaluationResult(
            security_state=security_state,
            location_confidence=final_confidence,
            risk_score=final_risk_score,
            signals=signals,
            fraud_events=fraud_events,
        )
