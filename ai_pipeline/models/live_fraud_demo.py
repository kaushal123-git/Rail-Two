"""
LOCO AI Engine: Real-Time Ticket Fraud Detection & Telemetry Analyzer
Demonstrates how the AI system detects and blocks ticket fraud attempts:
1. GPS Spoofing & Teleportation (Impossible Travel Speed)
2. Automated Bot Ticket Generation (Rapid Sub-15s Consecutive Requests)
3. Artificial Mock Location Uncertainty (High Meter Error Bounds)
4. Geofence Boundary Exploitation (Borderline 500m radius tricks)
5. Legitimate Daily Commuter Verification
"""

class BookingPatternFeatures:
    def __init__(self, user_name, origin, dest, time_diff_sec, distance_moved_km, accuracy_meters, dist_to_station_meters, is_qr=False, is_offline=False):
        self.user_name = user_name
        self.origin = origin
        self.dest = dest
        self.time_diff_sec = time_diff_sec
        self.distance_moved_km = distance_moved_km
        self.accuracy_meters = accuracy_meters
        self.dist_to_station_meters = dist_to_station_meters
        self.is_qr = is_qr
        self.is_offline = is_offline

def analyze_fraud_attempt(features: BookingPatternFeatures):
    anomaly_points = 0.0
    anomalies = []

    # Feature 1: Teleportation / Impossible Travel Velocity
    if features.time_diff_sec > 0:
        speed_kmh = features.distance_moved_km / (features.time_diff_sec / 3600.0)
        if speed_kmh > 250.0:
            anomaly_points += 0.45
            anomalies.append(f"IMPOSSIBLE TRAVEL VELOCITY: {speed_kmh:.0f} km/h between bookings (GPS Location Spoofing / Teleportation App)")
        elif speed_kmh > 120.0:
            anomaly_points += 0.20
            anomalies.append(f"High Movement Velocity: {speed_kmh:.0f} km/h")

    # Feature 2: Rapid Consecutive Booking Anomaly (Bot / Script)
    if 0 < features.time_diff_sec < 15:
        anomaly_points += 0.35
        anomalies.append(f"BOT AUTOMATION DETECTED: Rapid consecutive ticket request in {features.time_diff_sec:.1f}s interval")

    # Feature 3: GPS Accuracy Uncertainty (Mock Location Tool)
    if features.accuracy_meters > 100.0:
        anomaly_points += 0.25
        anomalies.append(f"GPS MOCK LOCATION ANOMALY: High coordinate uncertainty (+/- {features.accuracy_meters:.0f}m accuracy)")

    # Feature 4: Geofence Boundary Exploitation
    if 500.0 < features.dist_to_station_meters < 550.0 and not features.is_qr:
        anomaly_points += 0.15
        anomalies.append("GEOFENCE EXPLOITATION: Borderline ticket attempt on 500m perimeter without QR scan")

    # Feature 5: Unverified Offline Request
    if features.is_offline:
        anomaly_points += 0.10
        anomalies.append("Unverified Offline Request Flag")

    risk_score = min(1.0, anomaly_points)
    
    if risk_score >= 0.70:
        risk_level = "FRAUDULENT (TICKET BLOCKED)"
        primary_pattern = "High-Risk Fake Location Spoofing / Multi-Anomaly Bot Scripting"
        ticket_allowed = False
    elif risk_score >= 0.30:
        risk_level = "SUSPICIOUS (FLAGGED FOR AUDIT)"
        primary_pattern = "Suspicious Travel Velocity / Geofence Anomaly"
        ticket_allowed = True
    else:
        risk_level = "LEGITIMATE (APPROVED)"
        primary_pattern = "Normal Commuter Travel Pattern"
        ticket_allowed = True

    return {
        "user": features.user_name,
        "route": f"{features.origin} -> {features.dest}",
        "risk_score": round(risk_score, 2),
        "risk_level": risk_level,
        "pattern": primary_pattern,
        "anomalies": anomalies if anomalies else ["None - Clean GPS & Timing Verification"],
        "ticket_allowed": ticket_allowed
    }

def run_realtime_fraud_simulation():
    print("=" * 78)
    print("  LOCO AI ENGINE: REAL-TIME TICKET FRAUD DETECTION & TELEMETRY MONITOR")
    print("=" * 78)
    print("Simulating real-time incoming ticket requests across Mumbai Suburban Network...\n")

    scenarios = [
        # Scenario 1: Clean Legitimate Commuter
        BookingPatternFeatures(
            user_name="Rahul Sharma (Legitimate Commuter)",
            origin="Dadar", dest="Churchgate",
            time_diff_sec=86400,
            distance_moved_km=2.5,
            accuracy_meters=8.5,
            dist_to_station_meters=180.0
        ),
        # Scenario 2: GPS Teleportation + Bot Automation (Compound Fraud -> BLOCKED)
        BookingPatternFeatures(
            user_name="User_7721 (Fake GPS + Bot Script)",
            origin="Dadar", dest="Borivali",
            time_diff_sec=10.0, # 10s after booking at CSMT (35 km away!)
            distance_moved_km=35.0,
            accuracy_meters=12.0,
            dist_to_station_meters=210.0
        ),
        # Scenario 3: Mock Location Tool + Geofence Perimeter Exploitation + Velocity (Compound Fraud -> BLOCKED)
        BookingPatternFeatures(
            user_name="User_8890 (Mock Location Injector + Boundary Trick)",
            origin="Thane", dest="Kalyan",
            time_diff_sec=8.0, # 8s interval + 350m uncertainty + 25 km distance
            distance_moved_km=25.0,
            accuracy_meters=350.0,
            dist_to_station_meters=520.0
        ),
        # Scenario 4: Single Rapid Booking (Flagged as Suspicious)
        BookingPatternFeatures(
            user_name="User_3301 (Rapid Consecutive Booking)",
            origin="Andheri", dest="Virar",
            time_diff_sec=12.0,
            distance_moved_km=0.1,
            accuracy_meters=5.0,
            dist_to_station_meters=150.0
        )
    ]

    for idx, scenario in enumerate(scenarios, 1):
        print(f"\n--- [TICKET REQUEST #{idx}] Commuter: {scenario.user_name} ---")
        print(f"Requested Route: {scenario.origin} to {scenario.dest}")
        print("Running AI Feature Analysis...")
        
        result = analyze_fraud_attempt(scenario)
        
        print(f"AI Risk Score: {result['risk_score']:.2f} / 1.00")
        print(f"Decision: {result['risk_level']}")
        print(f"Classification: {result['pattern']}")
        print("Flagged Anomalies:")
        for anomaly in result['anomalies']:
            print(f"   * {anomaly}")
        print(f"Ticket Status: {'PASSED - APPROVED' if result['ticket_allowed'] else 'BLOCKED BY AI SYSTEM'}")
        print("-" * 78)

if __name__ == "__main__":
    run_realtime_fraud_simulation()
