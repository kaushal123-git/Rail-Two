"""
LOCO Machine Learning Fraud Detection - Feature Schema Definition
Schema Version: LOCO-FRAUD-FEATURE-v1.0

Defines the 52 structured fraud features extracted from commuter activity,
location integrity, journey tracking, ticketing, payment, device, and network telemetry.
"""

from typing import Dict, Any, List
from pydantic import BaseModel, Field


FEATURE_SCHEMA_VERSION = "LOCO-FRAUD-FEATURE-v1.0"

# Ordered list of feature names for model input consistency
FEATURE_NAMES: List[str] = [
    # 1. Location Features (12)
    "gps_accuracy",
    "distance_from_expected_station",
    "distance_from_route",
    "speed_kmh",
    "acceleration",
    "bearing_change",
    "location_jump_distance",
    "location_jump_time",
    "location_update_frequency",
    "location_confidence",
    "mock_location_signal",
    "location_replay_signal",
    # 2. Journey Features (8)
    "journey_duration",
    "expected_journey_duration",
    "journey_progress",
    "route_deviation_distance",
    "boarding_station_match",
    "destination_match",
    "station_transition_time",
    "number_of_route_deviations",
    # 3. Ticket Features (8)
    "tickets_created_24h",
    "tickets_created_7d",
    "active_ticket_count",
    "ticket_reuse_count",
    "ticket_age",
    "ticket_validity_remaining",
    "ticket_location_mismatch",
    "ticket_state_consistency",
    # 4. Payment Features (6)
    "payment_attempts_24h",
    "payment_failures_24h",
    "payment_success_rate",
    "payment_amount",
    "payment_retry_count",
    "payment_ticket_consistency",
    # 5. Account Features (6)
    "account_age_days",
    "login_count_24h",
    "otp_requests_24h",
    "otp_failures_24h",
    "device_change_count",
    "session_count_24h",
    # 6. Device Features (8)
    "device_age_days",
    "device_integrity_status",
    "root_detected",
    "jailbreak_detected",
    "emulator_detected",
    "app_integrity_status",
    "play_integrity_status",
    "app_attest_status",
    # 7. Network Features (4)
    "network_change_frequency",
    "suspicious_network_signal",
    "vpn_signal",
    "proxy_signal",
]

NUM_FEATURES: int = len(FEATURE_NAMES)


class FraudFeatureVector(BaseModel):

    """
    Validated 52-dimensional tabular feature vector for LOCO fraud detection.
    Missing signals are populated with safe defaults and lower confidence.
    """

    # --- 1. Location Features ---
    gps_accuracy: float = Field(default=15.0, description="GPS uncertainty radius in meters")
    distance_from_expected_station: float = Field(default=50.0, description="Meters from current/expected station geofence")
    distance_from_route: float = Field(default=20.0, description="Meters from railway track centerline")
    speed_kmh: float = Field(default=35.0, description="Calculated movement speed in km/h")
    acceleration: float = Field(default=0.2, description="Calculated acceleration in m/s^2")
    bearing_change: float = Field(default=5.0, description="Absolute change in direction in degrees")
    location_jump_distance: float = Field(default=0.0, description="Displacement from previous observation in meters")
    location_jump_time: float = Field(default=10.0, description="Seconds elapsed since last observation")
    location_update_frequency: float = Field(default=6.0, description="Location updates per minute")
    location_confidence: float = Field(default=1.0, description="Heuristic location confidence [0.0, 1.0]")
    mock_location_signal: float = Field(default=0.0, description="1.0 if mock provider active, else 0.0")
    location_replay_signal: float = Field(default=0.0, description="1.0 if location event ID replayed, else 0.0")

    # --- 2. Journey Features ---
    journey_duration: float = Field(default=600.0, description="Seconds elapsed in active journey")
    expected_journey_duration: float = Field(default=1800.0, description="Expected timetable travel duration in seconds")
    journey_progress: float = Field(default=0.3, description="Progress fraction [0.0, 1.0]")
    route_deviation_distance: float = Field(default=0.0, description="Max deviation from corridor in meters")
    boarding_station_match: float = Field(default=1.0, description="1.0 if boarded at origin station, else 0.0")
    destination_match: float = Field(default=1.0, description="1.0 if on path to destination, else 0.0")
    station_transition_time: float = Field(default=180.0, description="Seconds between last 2 stations")
    number_of_route_deviations: float = Field(default=0.0, description="Count of corridor departure warnings")

    # --- 3. Ticket Features ---
    tickets_created_24h: float = Field(default=1.0, description="Total tickets booked in last 24h")
    tickets_created_7d: float = Field(default=4.0, description="Total tickets booked in last 7 days")
    active_ticket_count: float = Field(default=1.0, description="Simultaneous active tickets")
    ticket_reuse_count: float = Field(default=0.0, description="Number of times QR code re-scanned")
    ticket_age: float = Field(default=900.0, description="Seconds elapsed since ticket issuance")
    ticket_validity_remaining: float = Field(default=6300.0, description="Seconds remaining until expiration")
    ticket_location_mismatch: float = Field(default=0.0, description="1.0 if scanned far from journey corridor")
    ticket_state_consistency: float = Field(default=1.0, description="1.0 if state machine transition is valid, 0.0 if illegal")

    # --- 4. Payment Features ---
    payment_attempts_24h: float = Field(default=1.0, description="Payment orders initiated in last 24h")
    payment_failures_24h: float = Field(default=0.0, description="Failed payment transactions in last 24h")
    payment_success_rate: float = Field(default=1.0, description="Ratio of successful payments [0.0, 1.0]")
    payment_amount: float = Field(default=15.0, description="Fare amount in INR")
    payment_retry_count: float = Field(default=0.0, description="Payment retries for current ticket")
    payment_ticket_consistency: float = Field(default=1.0, description="1.0 if paid amount exactly matches tariff")

    # --- 5. Account Features ---
    account_age_days: float = Field(default=60.0, description="Days since user registered")
    login_count_24h: float = Field(default=1.0, description="Login sessions initiated in last 24h")
    otp_requests_24h: float = Field(default=1.0, description="OTP requests generated in last 24h")
    otp_failures_24h: float = Field(default=0.0, description="Failed OTP entries in last 24h")
    device_change_count: float = Field(default=0.0, description="Different devices registered in last 30d")
    session_count_24h: float = Field(default=1.0, description="Active user sessions in last 24h")

    # --- 6. Device Features ---
    device_age_days: float = Field(default=45.0, description="Days since device first registered")
    device_integrity_status: float = Field(default=1.0, description="1.0=PASSED, 0.5=UNVERIFIED, 0.0=FAILED")
    root_detected: float = Field(default=0.0, description="1.0 if su/magisk detected, else 0.0")
    jailbreak_detected: float = Field(default=0.0, description="1.0 if iOS jailbreak detected, else 0.0")
    emulator_detected: float = Field(default=0.0, description="1.0 if running on Android/iOS emulator, else 0.0")
    app_integrity_status: float = Field(default=1.0, description="1.0 if APK/binary signature valid, else 0.0")
    play_integrity_status: float = Field(default=1.0, description="1.0 if Google Play Integrity passes, else 0.0")
    app_attest_status: float = Field(default=1.0, description="1.0 if Apple App Attest passes, else 0.0")

    # --- 7. Network Features ---
    network_change_frequency: float = Field(default=1.0, description="Network interfaces changed per hour")
    suspicious_network_signal: float = Field(default=0.0, description="1.0 if Tor/known anonymizer, else 0.0")
    vpn_signal: float = Field(default=0.0, description="1.0 if VPN routing tunnel active, else 0.0")
    proxy_signal: float = Field(default=0.0, description="1.0 if HTTP proxy headers present, else 0.0")

    def to_dict(self) -> Dict[str, float]:
        """Convert to dictionary matching schema keys."""
        return {name: float(getattr(self, name)) for name in FEATURE_NAMES}

    def to_feature_list(self) -> List[float]:
        """Convert to ordered feature list strictly matching FEATURE_NAMES."""
        return [float(getattr(self, name)) for name in FEATURE_NAMES]

    def to_list(self) -> List[float]:
        """Alias for to_feature_list()."""
        return self.to_feature_list()

