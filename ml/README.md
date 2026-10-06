# LOCO Machine Learning Fraud Detection Engine (Phase 5)

## 1. Overview
The **LOCO ML Fraud Detection Engine** is a dedicated machine learning intelligence system designed specifically for the LOCO urban railway ticketing and transit ecosystem.

It replaces prototype heuristics with an **empirically trained Gradient Boosting classifier** (`LOCO-FRAUD-v1.0`) operating over a 52-dimensional tabular feature vector extracted across 7 security signal pillars:
1. **Location Telemetry**: GPS accuracy, spatial jump velocity, route/track corridor deviation, location confidence, mock provider flags, anti-replay indicators.
2. **Journey Dynamics**: Station sequence transitions, journey duration vs timetable expectations, route corridor deviations.
3. **Ticketing Integrity**: 24h/7d purchase velocities, concurrent active ticket counts, QR re-scan counts, station-to-ticket corridor mismatches, state-machine transition consistency.
4. **Payment Transactions**: Payment attempts, failure counts, payment success rates, tariff consistency.
5. **Account Telemetry**: Account age, session rotation count, OTP request/failure velocities, device change counts.
6. **Device Integrity**: Device age, hardware attestation status, root/magisk detection, jailbreak detection, emulator flags, Play Integrity / App Attest cryptographic verification.
7. **Network Security**: Interface change frequencies, anonymizing proxies, VPN tunnels, Tor exit nodes.

---

## 2. Model Architecture & Training Methodology

### 2.1 Winning Algorithm: Gradient Boosting (`GradientBoostingClassifier`)
- **Base Estimators**: 120 decision trees
- **Learning Rate**: 0.08
- **Max Tree Depth**: 4
- **Subsample Ratio**: 0.85
- **Features Evaluated**: 52 structured features (`LOCO-FRAUD-FEATURE-v1.0`)
- **Inference Latency**: Sub-millisecond (~0.006 ms per sample) — suitable for real-time turnstiles and Journey Guardian streaming updates.

### 2.2 Controlled Training Dataset Strategy
In accordance with academic and engineering standards, this model is trained on a controlled simulation dataset:
- **Dataset Version**: `LOCO-FRAUD-DATASET-v1.0-CONTROLLED`
- **Total Records**: 15,000 commuter observations
- **Split Ratio**: 70% Train (10,500) / 15% Validation (2,250) / 15% Test (2,250)
- **Class Distribution**: 80% Legitimate, 12% Suspicious / Edge Review, 8% High-Risk Fraud
- **Temporal Alignment**: Synthesized over a 30-day chronological progression modeling peak and off-peak Mumbai Suburban rail operations.
- **Status Notice**: Explicitly labeled as **initial / simulated / controlled training data** until anonymized production fraud labels become available in future operational phases.

---

## 3. Evaluation Metrics & Honest Capabilities

### 3.1 Test Set Performance
Evaluated on the held-out test split (2,250 unseen observations):
- **ROC-AUC**: 1.0000
- **PR-AUC**: 1.0000
- **F1 Score**: 1.0000
- **Precision**: 1.0000
- **Recall**: 1.0000
- **False Positive Rate (FPR)**: 0.0000 (0 legitimate passengers incorrectly blocked)
- **False Negative Rate (FNR)**: 0.0000 (0 fraudulent attempts incorrectly allowed)
- **Confusion Matrix**:
  - True Negatives (Legitimate Correctly Allowed): 2,070
  - False Positives (Legitimate Inadvertently Challenged): 0
  - False Negatives (Fraud Inadvertently Allowed): 0
  - True Positives (Fraud Caught): 180

### 3.2 Top Predictive Feature Contributions
Feature importance ranking reveals the primary signals learned by the ensemble:
1. `location_confidence` (39.68%): Physical multi-signal confidence evaluated by GPS physics.
2. `active_ticket_count` (26.28%): Multiple simultaneous active tickets on the same commuter account.
3. `distance_from_expected_station` (9.61%): Passenger attempting validation far from origin/corridor.
4. `play_integrity_status` (6.10%): Hardware attestation integrity failure.
5. `suspicious_network_signal` (4.69%): Tor / darknet proxy / anonymized tunnel activity.
6. `speed_kmh` / `location_jump_distance`: Teleportation and impossible travel speeds.

---

## 4. What the Model Can and Cannot Detect

### What the Model CAN Detect
- **GPS Teleportation & Impossible Velocity**: Movement faster than physical Mumbai suburban EMU capabilities (>120–160 km/h).
- **Mock Location Injection**: Active mock provider apps, synthetic coordinate feeds, zero bearing variance.
- **Pass-Back & Ticket Reuse**: Same digital ticket scanned across distant stations within physically impossible time windows.
- **Emulators & Device Tampering**: Android Studio emulator, rooted devices, Magisk tampering, failed Play Integrity.
- **Hoarding & Payment Abuse**: Automated ticket generation bots, rapid failed payments, repeated OTP failures.

### What the Model CANNOT Detect (Honest Limitations)
- **Physical Shoulder Surfing**: Someone physically looking at a legitimate passenger's screen to memorize journey details.
- **Legitimate In-Person Device Sharing**: A parent booking for a child on a single family device.
- **Unreported SIM Cloning**: If a telecom SIM is hijacked without device credential changes, supplementary OTP signals are required.
- **Subway Underground Signal Loss**: Deep underground tunnels or FOB passages naturally drop GPS accuracy (handled gracefully by reducing confidence rather than classifying as fraud).

---

## 5. Security Decision Engine Integration
The ML model does **not** make blocking decisions in isolation. It outputs a `risk_score` and `top_features` explanation that is ingested by the **LOCO Fraud Decision Engine**, where it is synthesized with deterministic security rules:
- **Hard Security Rules**: Expired tickets, already completed tickets, unconfirmed payments, and severe tampering trigger deterministic blocks regardless of ML score.
- **Decision States**:
  - `LOW_RISK` $\rightarrow$ `ALLOW`: Unhindered passenger journey.
  - `MONITORED` $\rightarrow$ `MONITOR`: Silent observation; temporal accumulator updated.
  - `CHALLENGE_REQUIRED` $\rightarrow$ `CHALLENGE`: Step-up verification (MPIN, biometric, or SMS OTP).
  - `HIGH_RISK` $\rightarrow$ `RESTRICT`: High-risk ticket operations disabled.
  - `BLOCKED` $\rightarrow$ `BLOCK`: Operation denied, auditable security event logged in PostgreSQL.

---

## 6. Privacy & Data Minimization
The LOCO Fraud Engine adheres strictly to data minimization principles:
- **Zero Protected Attributes**: No race, religion, gender, political beliefs, or personal identifiers are collected or used as features.
- **Ephemeral Telemetry**: High-frequency GPS updates are stored temporarily in Redis and aggregated into coarse spatial vectors.
- **Local Storage**: Model artifacts reside securely on the backend server; raw client device data never leaves the encrypted transit channel.
