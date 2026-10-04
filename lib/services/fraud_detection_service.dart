import 'dart:math';

enum FraudRiskLevel { legitimate, suspicious, fraudulent }

class BookingPatternFeatures {
  final double userLat;
  final double userLng;
  final double accuracyMeters;
  final double distanceToStationMeters;
  final double timeDifferenceSeconds; // Time since last booking
  final double distanceMovedFromLastBookingKm; // Spatial delta
  final bool isQrScanned;
  final bool isOffline;
  final String deviceId;

  BookingPatternFeatures({
    required this.userLat,
    required this.userLng,
    required this.accuracyMeters,
    required this.distanceToStationMeters,
    required this.timeDifferenceSeconds,
    required this.distanceMovedFromLastBookingKm,
    required this.isQrScanned,
    required this.isOffline,
    required this.deviceId,
  });
}

class FraudAnalysisResult {
  final double riskScore; // 0.0 (Legitimate) to 1.0 (Fraudulent)
  final FraudRiskLevel riskLevel;
  final String primaryPatternDetected;
  final List<String> flaggedAnomalies;
  final bool isTicketAllowed;

  FraudAnalysisResult({
    required this.riskScore,
    required this.riskLevel,
    required this.primaryPatternDetected,
    required this.flaggedAnomalies,
    required this.isTicketAllowed,
  });
}

class FraudDetectionService {
  static final List<FraudAnalysisResult> _recentDetections = [];
  static List<FraudAnalysisResult> get recentDetections => List.unmodifiable(_recentDetections);

  /// RO2: ML-based pattern analysis for suspicious ticket booking detection
  static FraudAnalysisResult analyzeBookingAttempt(BookingPatternFeatures features) {
    double anomalyPoints = 0.0;
    final List<String> anomalies = [];

    // Feature 1: Velocity / Impossible Travel Calculation (Teleportation Detection)
    if (features.timeDifferenceSeconds > 0) {
      final speedKmH = (features.distanceMovedFromLastBookingKm / (features.timeDifferenceSeconds / 3600.0));
      if (speedKmH > 250.0) {
        anomalyPoints += 0.45;
        anomalies.add('Impossible Travel Velocity: ${speedKmH.toStringAsFixed(0)} km/h detected between consecutive bookings (GPS Spoofing)');
      } else if (speedKmH > 120.0) {
        anomalyPoints += 0.20;
        anomalies.add('High Velocity Movement: ${speedKmH.toStringAsFixed(0)} km/h');
      }
    }

    // Feature 2: Rapid Consecutive Booking Anomaly (Hoarding / Bot Detection)
    if (features.timeDifferenceSeconds > 0 && features.timeDifferenceSeconds < 15) {
      anomalyPoints += 0.35;
      anomalies.add('Rapid Consecutive Booking Anomaly (${features.timeDifferenceSeconds.toStringAsFixed(1)}s interval)');
    }

    // Feature 3: GPS Accuracy Anomaly (Location Spoofing Mock Location Indicator)
    if (features.accuracyMeters > 100.0) {
      anomalyPoints += 0.25;
      anomalies.add('Extreme GPS Uncertainty (±${features.accuracyMeters.toStringAsFixed(0)}m accuracy penalty)');
    }

    // Feature 4: Geofence Boundary Exploitation Check
    if (features.distanceToStationMeters > 500.0 && features.distanceToStationMeters < 550.0 && !features.isQrScanned) {
      anomalyPoints += 0.15;
      anomalies.add('Borderline Geofence Exploitation Pattern (Near 500m radius threshold)');
    }

    // Feature 5: Offline Mode Anomaly Rate
    if (features.isOffline) {
      anomalyPoints += 0.10;
      anomalies.add('Unverified Offline Ticket Request Flag');
    }

    // Normalize final score [0.0 - 1.0]
    final riskScore = min(1.0, anomalyPoints);
    FraudRiskLevel riskLevel = FraudRiskLevel.legitimate;
    String primaryPattern = 'Normal Legitimate Traveler';

    if (riskScore >= 0.70) {
      riskLevel = FraudRiskLevel.fraudulent;
      primaryPattern = 'High Risk GPS Spoofing / Bot Automated Ticket Generation';
    } else if (riskScore >= 0.30) {
      riskLevel = FraudRiskLevel.suspicious;
      primaryPattern = 'Suspicious Location Anomaly / Rapid Booking Flagged';
    }

    final result = FraudAnalysisResult(
      riskScore: riskScore,
      riskLevel: riskLevel,
      primaryPatternDetected: primaryPattern,
      flaggedAnomalies: anomalies.isEmpty ? ['None — Clean Verification'] : anomalies,
      isTicketAllowed: riskLevel != FraudRiskLevel.fraudulent,
    );

    _recentDetections.insert(0, result);
    if (_recentDetections.length > 20) _recentDetections.removeLast();

    return result;
  }
}
