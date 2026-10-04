import 'dart:async';
import '../models/security_models.dart';

class LocationTrustService {
  static final LocationTrustService _instance = LocationTrustService._internal();
  factory LocationTrustService() => _instance;
  LocationTrustService._internal();

  LocationTrustLevel _currentLevel = LocationTrustLevel.trusted;
  LocationTrustLevel get currentLevel => _currentLevel;

  final _trustController = StreamController<LocationTrustLevel>.broadcast();
  Stream<LocationTrustLevel> get trustStream => _trustController.stream;

  String _statusMessage = 'GPS signal high accuracy. Station geofence verified.';
  String get statusMessage => _statusMessage;

  void evaluateLocation({
    required double accuracyMeters,
    required double speedKmH,
    required bool isMockProvider,
  }) {
    if (isMockProvider) {
      _currentLevel = LocationTrustLevel.critical;
      _statusMessage = 'Mock location provider detected on device.';
    } else if (speedKmH > 160.0) {
      _currentLevel = LocationTrustLevel.suspicious;
      _statusMessage = 'Unrealistic displacement velocity (${speedKmH.toStringAsFixed(0)} km/h). Location verification needed.';
    } else if (accuracyMeters > 80.0) {
      _currentLevel = LocationTrustLevel.uncertain;
      _statusMessage = 'GPS accuracy degraded (${accuracyMeters.toStringAsFixed(0)}m). Retrying fix...';
    } else {
      _currentLevel = LocationTrustLevel.trusted;
      _statusMessage = 'Location verified. Active geofence secure.';
    }
    _trustController.add(_currentLevel);
  }

  /// Demo helper: Injects a GPS Spoof anomaly
  void injectSpoofAnomaly() {
    _currentLevel = LocationTrustLevel.suspicious;
    _statusMessage = 'LOCO noticed an unusual location signal. Please verify your journey.';
    _trustController.add(_currentLevel);
  }

  void resetTrust() {
    _currentLevel = LocationTrustLevel.trusted;
    _statusMessage = 'Location verified. Active geofence secure.';
    _trustController.add(_currentLevel);
  }
}

class FraudDetectionService {
  static final FraudDetectionService _instance = FraudDetectionService._internal();
  factory FraudDetectionService() => _instance;
  FraudDetectionService._internal();

  final List<SecurityEvent> _events = [];
  List<SecurityEvent> get securityEvents => List.unmodifiable(_events);

  final _eventsController = StreamController<List<SecurityEvent>>.broadcast();
  Stream<List<SecurityEvent>> get eventsStream => _eventsController.stream;

  final Map<String, DateTime> _lastValidationTimestamp = {};
  final Map<String, String> _lastValidationStation = {};

  /// Validates a ticket scan against potential impossible travel time
  bool validateTicketScan({
    required String ticketId,
    required String currentStationName,
  }) {
    final now = DateTime.now();
    if (_lastValidationTimestamp.containsKey(ticketId)) {
      final lastTime = _lastValidationTimestamp[ticketId]!;
      final lastStation = _lastValidationStation[ticketId] ?? 'Unknown';
      final diffMinutes = now.difference(lastTime).inMinutes;

      // If scanned within 3 minutes at a DIFFERENT station, trigger reuse anomaly!
      if (lastStation != currentStationName && diffMinutes < 3) {
        final event = SecurityEvent(
          id: 'SEC-${DateTime.now().millisecondsSinceEpoch}',
          timestamp: now,
          title: 'Suspicious Ticket Activity',
          type: SecurityEventType.ticketReuse,
          description: 'Ticket $ticketId scanned at $currentStationName just $diffMinutes min after being validated at $lastStation. Impossible transit time.',
          riskScore: 84,
          requiresAction: true,
        );
        _events.insert(0, event);
        _eventsController.add(_events);
        return false;
      }
    }

    _lastValidationTimestamp[ticketId] = now;
    _lastValidationStation[ticketId] = currentStationName;
    return true;
  }

  /// Demo helper: Injects a ticket reuse event
  void injectTicketReuseEvent(String ticketId) {
    final event = SecurityEvent(
      id: 'SEC-REUSE-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      title: 'Ticket Reuse Alert',
      type: SecurityEventType.ticketReuse,
      description: 'Ticket $ticketId was re-scanned at Andheri while already marked active at Borivali.',
      riskScore: 88,
      requiresAction: true,
    );
    _events.insert(0, event);
    _eventsController.add(_events);
  }

  void clearEvents() {
    _events.clear();
    _eventsController.add(_events);
  }
}
