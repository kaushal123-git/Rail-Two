"""
LOCO Machine Learning Fraud Detection - Controlled Dataset Generator
Dataset Version: LOCO-FRAUD-DATASET-v1.0-CONTROLLED

Generates realistic controlled scenarios based on LOCO transit security signals.
Explicitly labeled as INITIAL / SIMULATED / CONTROLLED TRAINING DATA grounded
in Mumbai Suburban Railway transit physics and commuter operational realities.
"""

import sys
import os

# Ensure project root is in sys.path
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

import json
from datetime import datetime, timedelta, timezone
from typing import Dict, Any, List, Tuple
import numpy as np
import pandas as pd
from ml.features.schema import FEATURE_NAMES, FEATURE_SCHEMA_VERSION


DATASET_VERSION = "LOCO-FRAUD-DATASET-v1.0-CONTROLLED"
RANDOM_SEED = 42


def generate_controlled_scenarios(n_total: int = 15000) -> pd.DataFrame:
    """
    Generate realistic transit feature vectors reflecting:
    - 80% Legitimate commuters (Normal booking, valid GPS, consistent tickets & devices)
    - 12% Suspicious commuters (GPS degradation, route deviation, multiple bookings, clock drift)
    - 8% Fraudulent / High-Risk commuters (Impossible speed, mock location, ticket reuse, device tampering)
    """
    np.random.seed(RANDOM_SEED)

    n_legit = int(n_total * 0.80)
    n_suspicious = int(n_total * 0.12)
    n_fraud = n_total - n_legit - n_suspicious

    records: List[Dict[str, Any]] = []
    base_time = datetime(2026, 9, 1, 6, 0, 0, tzinfo=timezone.utc)

    # =========================================================================
    # 1. LEGITIMATE SCENARIOS (~80%)
    # =========================================================================
    for i in range(n_legit):
        # Progressively spaced over 30 days
        ts = base_time + timedelta(minutes=float(i * 2.5) + np.random.uniform(0, 1.5))

        rec = {
            # Location Features
            "gps_accuracy": float(np.random.gamma(shape=3.0, scale=3.5) + 3.0),  # Mean ~13.5m, realistic mobile GPS
            "distance_from_expected_station": float(np.random.exponential(scale=60.0)),  # Usually near station
            "distance_from_route": float(np.random.exponential(scale=25.0)),  # Close to railway tracks
            "speed_kmh": float(np.clip(np.random.normal(loc=42.0, scale=18.0), 0.0, 95.0)),  # Plausible suburban EMU speed
            "acceleration": float(np.clip(np.random.exponential(scale=0.25), 0.0, 1.2)),  # Smooth EMU acceleration
            "bearing_change": float(np.random.uniform(0.0, 20.0)),  # Smooth heading along track
            "location_jump_distance": float(np.clip(np.random.exponential(scale=80.0), 0.0, 400.0)),
            "location_jump_time": float(np.random.uniform(8.0, 20.0)),  # Regular 10-15s update intervals
            "location_update_frequency": float(np.clip(np.random.normal(loc=5.5, scale=1.0), 2.0, 10.0)),
            "location_confidence": float(np.clip(np.random.uniform(0.85, 1.0), 0.0, 1.0)),
            "mock_location_signal": 0.0,  # Legitimate passenger: no mock provider
            "location_replay_signal": 0.0,  # No replay

            # Journey Features
            "journey_duration": float(np.random.uniform(180.0, 2700.0)),  # 3m to 45m journey
            "expected_journey_duration": float(np.random.uniform(900.0, 3600.0)),
            "journey_progress": float(np.random.uniform(0.05, 0.95)),
            "route_deviation_distance": float(np.random.exponential(scale=15.0)),
            "boarding_station_match": 1.0,
            "destination_match": 1.0,
            "station_transition_time": float(np.random.uniform(120.0, 240.0)),  # 2-4 mins between Mumbai stations
            "number_of_route_deviations": float(np.random.choice([0, 1], p=[0.97, 0.03])),

            # Ticket Features
            "tickets_created_24h": float(np.random.choice([1, 2, 3], p=[0.75, 0.20, 0.05])),
            "tickets_created_7d": float(np.random.choice([2, 5, 8, 12], p=[0.40, 0.35, 0.20, 0.05])),
            "active_ticket_count": 1.0,
            "ticket_reuse_count": 0.0,
            "ticket_age": float(np.random.uniform(60.0, 5400.0)),
            "ticket_validity_remaining": float(np.random.uniform(1800.0, 7200.0)),
            "ticket_location_mismatch": 0.0,
            "ticket_state_consistency": 1.0,

            # Payment Features
            "payment_attempts_24h": float(np.random.choice([1, 2], p=[0.90, 0.10])),
            "payment_failures_24h": 0.0,
            "payment_success_rate": 1.0,
            "payment_amount": float(np.random.choice([5.0, 10.0, 15.0, 20.0, 35.0, 105.0], p=[0.25, 0.35, 0.20, 0.10, 0.05, 0.05])),
            "payment_retry_count": 0.0,
            "payment_ticket_consistency": 1.0,

            # Account Features
            "account_age_days": float(np.random.exponential(scale=180.0) + 1.0),  # Some brand new legitimate users, some old
            "login_count_24h": float(np.random.choice([1, 2, 3], p=[0.80, 0.15, 0.05])),
            "otp_requests_24h": 1.0,
            "otp_failures_24h": 0.0,
            "device_change_count": float(np.random.choice([0, 1], p=[0.95, 0.05])),
            "session_count_24h": float(np.random.choice([1, 2], p=[0.85, 0.15])),

            # Device Features
            "device_age_days": float(np.random.exponential(scale=150.0) + 1.0),
            "device_integrity_status": 1.0,
            "root_detected": 0.0,
            "jailbreak_detected": 0.0,
            "emulator_detected": 0.0,
            "app_integrity_status": 1.0,
            "play_integrity_status": 1.0,
            "app_attest_status": 1.0,

            # Network Features
            "network_change_frequency": float(np.random.choice([0, 1, 2], p=[0.60, 0.30, 0.10])),
            "suspicious_network_signal": 0.0,
            "vpn_signal": float(np.random.choice([0.0, 1.0], p=[0.98, 0.02])),  # Normal benign corporate VPN
            "proxy_signal": 0.0,

            # Metadata & Labels
            "timestamp": ts.isoformat(),
            "scenario_type": "LEGITIMATE_COMMUTER",
            "is_fraud": 0,
            "risk_label": "LOW",
        }
        records.append(rec)

    # =========================================================================
    # 2. SUSPICIOUS SCENARIOS (~12%)
    # Edge cases: urban canyon GPS multipath, border station jumps, multiple legitimate bookings
    # =========================================================================
    for i in range(n_suspicious):
        ts = base_time + timedelta(minutes=float(i * 18.0) + np.random.uniform(0, 5.0))
        suspicious_subtypes = ["URBAN_MULTIPATH_GPS", "ROUTE_DEVIATION", "RAPID_FAMILY_BOOKING", "NEW_DEVICE_TRANSITION"]
        subtype = np.random.choice(suspicious_subtypes)

        rec = {
            # Location Features
            "gps_accuracy": float(np.random.uniform(85.0, 220.0) if subtype == "URBAN_MULTIPATH_GPS" else np.random.uniform(15.0, 50.0)),
            "distance_from_expected_station": float(np.random.uniform(250.0, 600.0) if subtype == "ROUTE_DEVIATION" else np.random.uniform(40.0, 180.0)),
            "distance_from_route": float(np.random.uniform(120.0, 450.0) if subtype == "ROUTE_DEVIATION" else np.random.uniform(20.0, 90.0)),
            "speed_kmh": float(np.clip(np.random.normal(loc=55.0, scale=25.0), 0.0, 115.0)),
            "acceleration": float(np.clip(np.random.exponential(scale=0.6), 0.0, 2.2)),
            "bearing_change": float(np.random.uniform(10.0, 60.0)),
            "location_jump_distance": float(np.random.uniform(200.0, 1200.0)),
            "location_jump_time": float(np.random.uniform(5.0, 45.0)),
            "location_update_frequency": float(np.clip(np.random.normal(loc=3.5, scale=1.5), 1.0, 8.0)),
            "location_confidence": float(np.random.uniform(0.40, 0.75)),
            "mock_location_signal": 0.0,
            "location_replay_signal": 0.0,

            # Journey Features
            "journey_duration": float(np.random.uniform(300.0, 3600.0)),
            "expected_journey_duration": float(np.random.uniform(1200.0, 3600.0)),
            "journey_progress": float(np.random.uniform(0.1, 0.9)),
            "route_deviation_distance": float(np.random.uniform(150.0, 800.0) if subtype == "ROUTE_DEVIATION" else np.random.uniform(10.0, 80.0)),
            "boarding_station_match": float(0.0 if subtype == "ROUTE_DEVIATION" and np.random.rand() > 0.5 else 1.0),
            "destination_match": 1.0,
            "station_transition_time": float(np.random.uniform(180.0, 600.0)),
            "number_of_route_deviations": float(np.random.choice([1, 2, 3], p=[0.70, 0.20, 0.10])),

            # Ticket Features
            "tickets_created_24h": float(np.random.choice([3, 4, 5], p=[0.60, 0.30, 0.10]) if subtype == "RAPID_FAMILY_BOOKING" else 2.0),
            "tickets_created_7d": float(np.random.choice([6, 12, 18], p=[0.50, 0.35, 0.15])),
            "active_ticket_count": float(np.random.choice([1, 2], p=[0.70, 0.30])),
            "ticket_reuse_count": 0.0,
            "ticket_age": float(np.random.uniform(30.0, 7200.0)),
            "ticket_validity_remaining": float(np.random.uniform(600.0, 5400.0)),
            "ticket_location_mismatch": float(1.0 if subtype == "ROUTE_DEVIATION" and np.random.rand() > 0.6 else 0.0),
            "ticket_state_consistency": 1.0,

            # Payment Features
            "payment_attempts_24h": float(np.random.choice([2, 3, 4], p=[0.50, 0.35, 0.15])),
            "payment_failures_24h": float(np.random.choice([1, 2], p=[0.80, 0.20])),
            "payment_success_rate": float(np.random.choice([0.5, 0.67, 0.75], p=[0.30, 0.40, 0.30])),
            "payment_amount": float(np.random.choice([15.0, 30.0, 60.0, 105.0])),
            "payment_retry_count": float(np.random.choice([1, 2], p=[0.70, 0.30])),
            "payment_ticket_consistency": 1.0,

            # Account Features
            "account_age_days": float(np.random.exponential(scale=180.0) + 1.0),
            "login_count_24h": float(np.random.choice([2, 4, 6], p=[0.60, 0.30, 0.10])),
            "otp_requests_24h": float(np.random.choice([2, 3], p=[0.70, 0.30])),
            "otp_failures_24h": float(np.random.choice([0, 1], p=[0.75, 0.25])),
            "device_change_count": float(1.0 if subtype == "NEW_DEVICE_TRANSITION" else 0.0),
            "session_count_24h": float(np.random.choice([2, 3], p=[0.70, 0.30])),

            # Device Features
            "device_age_days": float(np.random.uniform(1.0, 20.0) if subtype == "NEW_DEVICE_TRANSITION" else np.random.exponential(scale=150.0) + 1.0),
            "device_integrity_status": float(0.5 if subtype == "NEW_DEVICE_TRANSITION" else 1.0),
            "root_detected": 0.0,
            "jailbreak_detected": 0.0,
            "emulator_detected": 0.0,
            "app_integrity_status": 1.0,
            "play_integrity_status": 1.0,
            "app_attest_status": 1.0,

            # Network Features
            "network_change_frequency": float(np.random.choice([2, 4, 6], p=[0.50, 0.35, 0.15])),
            "suspicious_network_signal": 0.0,
            "vpn_signal": float(np.random.choice([0.0, 1.0], p=[0.85, 0.15])),
            "proxy_signal": 0.0,

            # Metadata & Labels
            "timestamp": ts.isoformat(),
            "scenario_type": f"SUSPICIOUS_{subtype}",
            "is_fraud": 0,  # Labelled as 0 (not hard fraud) or edge review case
            "risk_label": "MEDIUM",
        }
        records.append(rec)

    # =========================================================================
    # 3. FRAUDULENT / HIGH-RISK SCENARIOS (~8%)
    # Core fraud patterns: Teleportation, Mock Location, Ticket Reuse, Device Tampering, Payment Bot
    # =========================================================================
    fraud_patterns = [
        "IMPOSSIBLE_SPEED_TELEPORTATION",
        "MOCK_LOCATION_SPOOFING",
        "TICKET_REUSE_PASS_BACK",
        "DEVICE_TAMPERING_EMULATOR",
        "TICKET_HOARDING_REPLAY",
    ]

    for i in range(n_fraud):
        ts = base_time + timedelta(minutes=float(i * 25.0) + np.random.uniform(0, 10.0))
        pattern = fraud_patterns[i % len(fraud_patterns)]

        # Base fraud defaults
        rec = {
            # Location Features
            "gps_accuracy": 15.0,
            "distance_from_expected_station": 40.0,
            "distance_from_route": 20.0,
            "speed_kmh": 45.0,
            "acceleration": 0.3,
            "bearing_change": 5.0,
            "location_jump_distance": 50.0,
            "location_jump_time": 10.0,
            "location_update_frequency": 6.0,
            "location_confidence": 0.9,
            "mock_location_signal": 0.0,
            "location_replay_signal": 0.0,

            # Journey Features
            "journey_duration": 600.0,
            "expected_journey_duration": 1800.0,
            "journey_progress": 0.35,
            "route_deviation_distance": 20.0,
            "boarding_station_match": 1.0,
            "destination_match": 1.0,
            "station_transition_time": 180.0,
            "number_of_route_deviations": 0.0,

            # Ticket Features
            "tickets_created_24h": 1.0,
            "tickets_created_7d": 3.0,
            "active_ticket_count": 1.0,
            "ticket_reuse_count": 0.0,
            "ticket_age": 900.0,
            "ticket_validity_remaining": 6000.0,
            "ticket_location_mismatch": 0.0,
            "ticket_state_consistency": 1.0,

            # Payment Features
            "payment_attempts_24h": 1.0,
            "payment_failures_24h": 0.0,
            "payment_success_rate": 1.0,
            "payment_amount": 20.0,
            "payment_retry_count": 0.0,
            "payment_ticket_consistency": 1.0,

            # Account Features
            "account_age_days": float(np.random.exponential(scale=180.0) + 1.0),
            "login_count_24h": 2.0,
            "otp_requests_24h": 1.0,
            "otp_failures_24h": 0.0,
            "device_change_count": 0.0,
            "session_count_24h": 1.0,

            # Device Features
            "device_age_days": float(np.random.exponential(scale=150.0) + 1.0),
            "device_integrity_status": 1.0,
            "root_detected": 0.0,
            "jailbreak_detected": 0.0,
            "emulator_detected": 0.0,
            "app_integrity_status": 1.0,
            "play_integrity_status": 1.0,
            "app_attest_status": 1.0,

            # Network Features
            "network_change_frequency": 1.0,
            "suspicious_network_signal": 0.0,
            "vpn_signal": 0.0,
            "proxy_signal": 0.0,

            # Metadata & Labels
            "timestamp": ts.isoformat(),
            "scenario_type": f"FRAUD_{pattern}",
            "is_fraud": 1,
            "risk_label": "HIGH",
        }

        # Specialize by fraud attack pattern
        if pattern == "IMPOSSIBLE_SPEED_TELEPORTATION":
            jump_dist = float(np.random.uniform(6000.0, 35000.0))  # 6km to 35km teleportation
            jump_time = float(np.random.uniform(5.0, 25.0))  # within 5-25 seconds!
            calculated_speed = (jump_dist / jump_time) * 3.6  # km/h
            rec["location_jump_distance"] = jump_dist
            rec["location_jump_time"] = jump_time
            rec["speed_kmh"] = float(calculated_speed)
            rec["acceleration"] = float(np.random.uniform(8.0, 22.0))
            rec["location_confidence"] = 0.15
            rec["ticket_location_mismatch"] = 1.0

        elif pattern == "MOCK_LOCATION_SPOOFING":
            rec["mock_location_signal"] = 1.0
            rec["gps_accuracy"] = float(np.random.uniform(1.0, 3.0))  # Artificially perfect integer precision
            rec["bearing_change"] = 0.0  # Synthetic static heading
            rec["acceleration"] = 0.0
            rec["location_confidence"] = 0.10
            rec["root_detected"] = float(np.random.choice([0.0, 1.0], p=[0.35, 0.65]))

        elif pattern == "TICKET_REUSE_PASS_BACK":
            rec["ticket_reuse_count"] = float(np.random.choice([1, 2, 3], p=[0.60, 0.30, 0.10]))
            rec["ticket_location_mismatch"] = 1.0
            rec["distance_from_expected_station"] = float(np.random.uniform(3000.0, 15000.0))
            rec["ticket_state_consistency"] = 0.0  # Attempted validation of completed or distant ticket
            rec["active_ticket_count"] = float(np.random.choice([2, 3], p=[0.70, 0.30]))

        elif pattern == "DEVICE_TAMPERING_EMULATOR":
            rec["emulator_detected"] = 1.0
            rec["root_detected"] = 1.0
            rec["device_integrity_status"] = 0.0
            rec["play_integrity_status"] = 0.0
            rec["app_integrity_status"] = 0.0
            rec["device_age_days"] = float(np.random.uniform(0.1, 2.0))
            rec["account_age_days"] = float(np.random.uniform(0.1, 3.0))
            rec["suspicious_network_signal"] = 1.0

        elif pattern == "TICKET_HOARDING_REPLAY":
            rec["location_replay_signal"] = 1.0
            rec["tickets_created_24h"] = float(np.random.uniform(8.0, 25.0))
            rec["active_ticket_count"] = float(np.random.uniform(4.0, 10.0))
            rec["payment_attempts_24h"] = float(np.random.uniform(10.0, 30.0))
            rec["payment_failures_24h"] = float(np.random.uniform(4.0, 12.0))
            rec["payment_success_rate"] = 0.50
            rec["otp_failures_24h"] = float(np.random.choice([2, 3, 5], p=[0.50, 0.30, 0.20]))
            rec["proxy_signal"] = 1.0

        records.append(rec)

    df = pd.DataFrame(records)
    # Sort chronologically by timestamp
    df = df.sort_values(by="timestamp").reset_index(drop=True)
    return df


def split_and_save_datasets(df: pd.DataFrame, output_dir: str):
    """
    Split into Training (70%), Validation (15%), and Test (15%) sets.
    Preserves time-ordered progression and realistic fraud prevalence across splits.
    """
    os.makedirs(os.path.join(output_dir, "raw"), exist_ok=True)
    os.makedirs(os.path.join(output_dir, "processed"), exist_ok=True)

    # 1. Save complete raw dataset
    raw_path = os.path.join(output_dir, "raw", "loco_fraud_controlled_scenarios.csv")
    df.to_csv(raw_path, index=False)
    print(f"[Dataset] Saved raw dataset: {raw_path} ({len(df)} records)")

    # 2. Time-aware split with stratified block sampling
    n_total = len(df)
    n_train = int(n_total * 0.70)
    n_val = int(n_total * 0.15)
    n_test = n_total - n_train - n_val

    # Stratified split to ensure test and val sets have exact fraud distribution
    from sklearn.model_selection import train_test_split

    train_df, temp_df = train_test_split(
        df,
        test_size=(n_val + n_test) / n_total,
        random_state=RANDOM_SEED,
        stratify=df["is_fraud"],
    )

    val_df, test_df = train_test_split(
        temp_df,
        test_size=n_test / (n_val + n_test),
        random_state=RANDOM_SEED,
        stratify=temp_df["is_fraud"],
    )

    # Sort each split chronologically
    train_df = train_df.sort_values(by="timestamp").reset_index(drop=True)
    val_df = val_df.sort_values(by="timestamp").reset_index(drop=True)
    test_df = test_df.sort_values(by="timestamp").reset_index(drop=True)

    train_path = os.path.join(output_dir, "processed", "train.csv")
    val_path = os.path.join(output_dir, "processed", "val.csv")
    test_path = os.path.join(output_dir, "processed", "test.csv")

    train_df.to_csv(train_path, index=False)
    val_df.to_csv(val_path, index=False)
    test_df.to_csv(test_path, index=False)

    print(f"[Dataset] Train set: {train_path} ({len(train_df)} records, fraud rate: {train_df['is_fraud'].mean()*100:.2f}%)")
    print(f"[Dataset] Val set:   {val_path} ({len(val_df)} records, fraud rate: {val_df['is_fraud'].mean()*100:.2f}%)")
    print(f"[Dataset] Test set:  {test_path} ({len(test_df)} records, fraud rate: {test_df['is_fraud'].mean()*100:.2f}%)")

    # 3. Save comprehensive dataset metadata
    metadata = {
        "dataset_name": "LOCO Custom ML Fraud Controlled Dataset",
        "dataset_version": DATASET_VERSION,
        "feature_schema_version": FEATURE_SCHEMA_VERSION,
        "is_synthetic_controlled_data": True,
        "status": "INITIAL_CONTROLLED_SIMULATED_TRAINING_DATA",
        "description": (
            "Controlled training dataset specifically generated for LOCO urban rail fraud detection. "
            "Simulates Mumbai suburban rail commuter movement physics, ticketing rules, and defined security anomalies."
        ),
        "total_records": n_total,
        "feature_count": len(FEATURE_NAMES),
        "feature_names": FEATURE_NAMES,
        "class_distribution": {
            "legitimate_count": int((df["is_fraud"] == 0).sum()),
            "fraud_count": int((df["is_fraud"] == 1).sum()),
            "fraud_prevalence_pct": round(float(df["is_fraud"].mean() * 100), 2),
        },
        "splits": {
            "train_records": len(train_df),
            "val_records": len(val_df),
            "test_records": len(test_df),
            "split_ratio": "70% / 15% / 15%",
            "random_seed": RANDOM_SEED,
        },
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    meta_path = os.path.join(output_dir, "dataset_metadata.json")
    with open(meta_path, "w") as f:
        json.dump(metadata, f, indent=2)
    print(f"[Dataset] Metadata saved: {meta_path}")


if __name__ == "__main__":
    current_dir = os.path.dirname(os.path.abspath(__file__))
    ml_root = os.path.dirname(current_dir)
    output_dir = os.path.join(ml_root, "datasets")
    print(f"Generating controlled dataset for LOCO ML Fraud Detection...")
    df = generate_controlled_scenarios(n_total=15000)
    split_and_save_datasets(df, output_dir)
    print("Done!")
