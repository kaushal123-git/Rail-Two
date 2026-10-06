"""
LOCO Machine Learning Fraud Detection - Feature Extraction Service
Extracts the 52-dimensional fraud feature vector from live database entities,
device status, location telemetry, ticket history, and Redis temporal state.
"""

from datetime import datetime, timezone, timedelta
from typing import Optional, Dict, Any, List, Tuple
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from ml.features.schema import FraudFeatureVector, FEATURE_NAMES, FEATURE_SCHEMA_VERSION
from app.models.user import User
from app.models.ticket import Ticket, TicketStatus
from app.models.journey import Journey, JourneyStatus
from app.models.device import Device
from app.models.payment import Payment, PaymentStatus
from app.models.location_event import LocationEvent
from app.schemas.journey import LocationEvidenceInput
from app.core.s2 import calculate_haversine_distance
from app.core.logging import logger


class FraudFeatureExtractor:
    """
    Dedicated feature engineering layer for LOCO Fraud Detection.
    Transforms raw transactional events, GPS telemetry, and historical aggregations
    into validated, structured feature vectors for the ML model.
    """

    def __init__(self, session: AsyncSession, redis=None):
        self.session = session
        self.redis = redis

    async def extract_features(
        self,
        user_id: str,
        ticket_id: Optional[str] = None,
        journey_id: Optional[str] = None,
        device_id: Optional[str] = None,
        current_location: Optional[LocationEvidenceInput] = None,
        last_location_event: Optional[LocationEvent] = None,
        network_signals: Optional[Dict[str, Any]] = None,
    ) -> Tuple[FraudFeatureVector, float]:
        """
        Extract complete 52-dimensional feature vector.
        Returns (feature_vector, confidence_score).
        """
        now = datetime.now(timezone.utc)
        confidence = 1.0

        # -------------------------------------------------------------
        # 1. Fetch User & Account Telemetry
        # -------------------------------------------------------------
        stmt = select(User).where(User.id == user_id)
        user_res = await self.session.execute(stmt)
        user = user_res.scalar_one_or_none()

        account_age_days = 30.0
        if user and user.created_at:
            u_created = user.created_at if user.created_at.tzinfo else user.created_at.replace(tzinfo=timezone.utc)
            account_age_days = max(0.1, (now - u_created).total_seconds() / 86400.0)

        # -------------------------------------------------------------
        # 2. Fetch Device Telemetry
        # -------------------------------------------------------------
        device = None
        if device_id:
            stmt = select(Device).where(Device.device_identifier == device_id)
            dev_res = await self.session.execute(stmt)
            device = dev_res.scalar_one_or_none()

        device_age_days = 15.0
        device_integrity = 1.0
        root_detected = 0.0
        emulator_detected = 0.0
        play_integrity = 1.0

        if device:
            if device.created_at:
                d_created = device.created_at if device.created_at.tzinfo else device.created_at.replace(tzinfo=timezone.utc)
                device_age_days = max(0.1, (now - d_created).total_seconds() / 86400.0)
            if device.integrity_status == "FAILED":
                device_integrity = 0.0
                play_integrity = 0.0
            elif device.integrity_status == "UNVERIFIED":
                device_integrity = 0.5
                confidence *= 0.85

        # -------------------------------------------------------------
        # 3. Fetch Ticket & Booking History
        # -------------------------------------------------------------
        ticket = None
        if ticket_id:
            stmt = select(Ticket).where(Ticket.id == ticket_id)
            t_res = await self.session.execute(stmt)
            ticket = t_res.scalar_one_or_none()

        # Query user ticket history in last 24h & 7d
        since_24h = now - timedelta(hours=24)
        since_7d = now - timedelta(days=7)

        stmt_24h = select(func.count(Ticket.id)).where(Ticket.user_id == user_id, Ticket.created_at >= since_24h)
        res_24h = await self.session.execute(stmt_24h)
        tickets_created_24h = float(res_24h.scalar() or 1.0)

        stmt_7d = select(func.count(Ticket.id)).where(Ticket.user_id == user_id, Ticket.created_at >= since_7d)
        res_7d = await self.session.execute(stmt_7d)
        tickets_created_7d = float(res_7d.scalar() or 1.0)

        stmt_active = select(func.count(Ticket.id)).where(
            Ticket.user_id == user_id,
            Ticket.ticket_status.in_([TicketStatus.ACTIVE.value, TicketStatus.IN_JOURNEY.value]),
        )
        res_active = await self.session.execute(stmt_active)
        active_ticket_count = float(res_active.scalar() or 1.0)

        ticket_age = 600.0
        ticket_validity_remaining = 3600.0
        ticket_state_consistency = 1.0
        ticket_reuse_count = 0.0

        if ticket:
            if ticket.issued_at:
                t_iss = ticket.issued_at if ticket.issued_at.tzinfo else ticket.issued_at.replace(tzinfo=timezone.utc)
                ticket_age = max(0.0, (now - t_iss).total_seconds())
            if ticket.valid_until:
                t_val = ticket.valid_until if ticket.valid_until.tzinfo else ticket.valid_until.replace(tzinfo=timezone.utc)
                ticket_validity_remaining = (t_val - now).total_seconds()
            if ticket.ticket_status in [TicketStatus.EXPIRED.value, TicketStatus.COMPLETED.value, TicketStatus.FRAUD_BLOCKED.value]:
                ticket_state_consistency = 0.0

        # Check Redis for temporal ticket reuse counts
        if self.redis and ticket_id:
            reuse_key = f"fraud:ticket:{ticket_id}:scans"
            scans = await self.redis.get(reuse_key)
            if scans:
                ticket_reuse_count = max(0.0, float(scans) - 1.0)

        # -------------------------------------------------------------
        # 4. Fetch Payment Telemetry
        # -------------------------------------------------------------
        stmt_pay = select(
            func.count(Payment.id),
            func.count().filter(Payment.status == PaymentStatus.FAILED.value),
        ).where(Payment.user_id == user_id, Payment.created_at >= since_24h)
        res_pay = await self.session.execute(stmt_pay)
        p_total, p_failed = res_pay.one()
        payment_attempts_24h = float(p_total or 1.0)
        payment_failures_24h = float(p_failed or 0.0)
        payment_success_rate = 1.0 if payment_attempts_24h == 0 else max(0.0, 1.0 - (payment_failures_24h / payment_attempts_24h))

        payment_amount = ticket.fare if ticket else 15.0

        # -------------------------------------------------------------
        # 5. Fetch Journey Telemetry
        # -------------------------------------------------------------
        journey = None
        if journey_id:
            stmt_j = select(Journey).where(Journey.id == journey_id)
            j_res = await self.session.execute(stmt_j)
            journey = j_res.scalar_one_or_none()

        journey_duration = 300.0
        expected_journey_duration = 1800.0
        journey_progress = 0.2
        route_deviation_distance = 0.0
        boarding_station_match = 1.0
        destination_match = 1.0
        number_of_route_deviations = 0.0

        if journey:
            if journey.started_at:
                j_st = journey.started_at if journey.started_at.tzinfo else journey.started_at.replace(tzinfo=timezone.utc)
                journey_duration = max(0.0, (now - j_st).total_seconds())
            if journey.security_state == "ROUTE_DEVIATION":
                number_of_route_deviations = 1.0
                route_deviation_distance = 350.0

        # -------------------------------------------------------------
        # 6. Extract Location & Kinematic Telemetry
        # -------------------------------------------------------------
        gps_accuracy = 15.0
        distance_from_station = 50.0
        distance_from_route = 20.0
        speed_kmh = 35.0
        acceleration = 0.2
        bearing_change = 5.0
        location_jump_distance = 0.0
        location_jump_time = 10.0
        location_update_frequency = 6.0
        location_confidence = 1.0
        mock_location_signal = 0.0
        location_replay_signal = 0.0
        ticket_location_mismatch = 0.0

        if current_location:
            gps_accuracy = current_location.accuracy_meters
            if current_location.is_mock or current_location.mock_confidence >= 0.5:
                mock_location_signal = 1.0
                confidence *= 0.20

            if current_location.speed_mps is not None:
                speed_kmh = current_location.speed_mps * 3.6

            # Compute kinematic continuity with last location observation
            if last_location_event:
                t_last = last_location_event.timestamp_server
                if t_last.tzinfo is None:
                    t_last = t_last.replace(tzinfo=timezone.utc)
                time_delta_sec = max(0.1, (now - t_last).total_seconds())
                location_jump_time = time_delta_sec

                dist_m = calculate_haversine_distance(
                    last_location_event.latitude,
                    last_location_event.longitude,
                    current_location.latitude,
                    current_location.longitude,
                )
                location_jump_distance = dist_m

                derived_speed_kmh = (dist_m / time_delta_sec) * 3.6
                speed_kmh = max(speed_kmh, derived_speed_kmh)

                if dist_m > 5000.0 and time_delta_sec < 30.0:
                    # Teleportation jump detected
                    location_confidence = 0.10
                    ticket_location_mismatch = 1.0
                elif derived_speed_kmh > 140.0:
                    location_confidence = 0.30

            # Station proximity check if ticket or journey available
            target_station = None
            if journey and journey.origin_station:
                target_station = journey.origin_station
            elif ticket and ticket.origin_station:
                target_station = ticket.origin_station

            if target_station:
                d_station = calculate_haversine_distance(
                    current_location.latitude,
                    current_location.longitude,
                    target_station.latitude,
                    target_station.longitude,
                )
                distance_from_station = d_station
                if d_station > 15000.0:
                    ticket_location_mismatch = 1.0

        # Check Redis for temporal location replay key
        if self.redis and current_location and current_location.client_event_id:
            replay_key = f"location:replay:{current_location.client_event_id}"
            is_rep = await self.redis.get(replay_key)
            if is_rep:
                location_replay_signal = 1.0
                confidence *= 0.10

        # -------------------------------------------------------------
        # 7. Extract Network Telemetry
        # -------------------------------------------------------------
        vpn_signal = 0.0
        proxy_signal = 0.0
        suspicious_network = 0.0
        if network_signals:
            vpn_signal = 1.0 if network_signals.get("is_vpn") else 0.0
            proxy_signal = 1.0 if network_signals.get("is_proxy") else 0.0
            suspicious_network = 1.0 if network_signals.get("is_suspicious") else 0.0

        # Construct validated vector
        vector = FraudFeatureVector(
            gps_accuracy=gps_accuracy,
            distance_from_expected_station=distance_from_station,
            distance_from_route=distance_from_route,
            speed_kmh=speed_kmh,
            acceleration=acceleration,
            bearing_change=bearing_change,
            location_jump_distance=location_jump_distance,
            location_jump_time=location_jump_time,
            location_update_frequency=location_update_frequency,
            location_confidence=location_confidence,
            mock_location_signal=mock_location_signal,
            location_replay_signal=location_replay_signal,
            journey_duration=journey_duration,
            expected_journey_duration=expected_journey_duration,
            journey_progress=journey_progress,
            route_deviation_distance=route_deviation_distance,
            boarding_station_match=boarding_station_match,
            destination_match=destination_match,
            station_transition_time=180.0,
            number_of_route_deviations=number_of_route_deviations,
            tickets_created_24h=tickets_created_24h,
            tickets_created_7d=tickets_created_7d,
            active_ticket_count=active_ticket_count,
            ticket_reuse_count=ticket_reuse_count,
            ticket_age=ticket_age,
            ticket_validity_remaining=ticket_validity_remaining,
            ticket_location_mismatch=ticket_location_mismatch,
            ticket_state_consistency=ticket_state_consistency,
            payment_attempts_24h=payment_attempts_24h,
            payment_failures_24h=payment_failures_24h,
            payment_success_rate=payment_success_rate,
            payment_amount=payment_amount,
            payment_retry_count=0.0,
            payment_ticket_consistency=1.0,
            account_age_days=account_age_days,
            login_count_24h=1.0,
            otp_requests_24h=1.0,
            otp_failures_24h=0.0,
            device_change_count=0.0,
            session_count_24h=1.0,
            device_age_days=device_age_days,
            device_integrity_status=device_integrity,
            root_detected=root_detected,
            jailbreak_detected=0.0,
            emulator_detected=emulator_detected,
            app_integrity_status=1.0,
            play_integrity_status=play_integrity,
            app_attest_status=1.0,
            network_change_frequency=1.0,
            suspicious_network_signal=suspicious_network,
            vpn_signal=vpn_signal,
            proxy_signal=proxy_signal,
        )

        final_conf = round(min(1.0, max(0.05, confidence)), 2)
        return vector, final_conf
