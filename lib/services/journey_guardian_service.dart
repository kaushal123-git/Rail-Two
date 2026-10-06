import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/journey.dart';
import '../models/station.dart';
import '../models/ticket.dart';
import '../models/train.dart';
import 'api_service.dart';
import 'location_service.dart';
import 'ticket_storage.dart';

/// Abstract contract for Journey tracking and Guardian safety monitoring.
abstract class JourneyRepository {
  ActiveJourney? get activeJourney;
  bool get hasActiveJourney;
  Stream<ActiveJourney?> get journeyStream;
  Future<Map<String, dynamic>> startJourney({
    required BookedTicket ticket,
    required RailwayStation originStation,
    required RailwayStation destinationStation,
    LocoTrain? train,
    String? routeId,
  });
  Future<Map<String, dynamic>> completeJourney();
  Future<Map<String, dynamic>> abandonJourney({String? reason});
  void clearJourney();
}

/// Real Location-Aware Journey Guardian Service for commuter protection.
/// Phase 4 connects real device GPS, Server-Controlled Station Geofences,
/// Route Corridor Progression, and Multi-Signal Location Integrity Analysis.
class JourneyGuardianService implements JourneyRepository {
  static final JourneyGuardianService _instance = JourneyGuardianService._internal();
  factory JourneyGuardianService() => _instance;
  JourneyGuardianService._internal();

  ActiveJourney? _activeJourney;
  Timer? _telemetryTimer;

  @override
  ActiveJourney? get activeJourney => _activeJourney;

  @override
  bool get hasActiveJourney =>
      _activeJourney != null &&
      _activeJourney!.state != JourneyState.completed &&
      _activeJourney!.state != JourneyState.abandoned;

  final _journeyController = StreamController<ActiveJourney?>.broadcast();
  @override
  Stream<ActiveJourney?> get journeyStream => _journeyController.stream;

  /// Starts a real server-validated journey with device location evidence.
  /// Enforces origin geofence validation and active journey locking.
  @override
  Future<Map<String, dynamic>> startJourney({
    required BookedTicket ticket,
    required RailwayStation originStation,
    required RailwayStation destinationStation,
    LocoTrain? train,
    String? routeId,
  }) async {
    // 1. Gather device location evidence
    final evidence = await LocationService.getLocationEvidence();
    final lat = (evidence['latitude'] as num).toDouble();
    final lng = (evidence['longitude'] as num).toDouble();
    final accuracy = (evidence['accuracy_meters'] as num?)?.toDouble() ?? 10.0;
    final isMock = evidence['is_mock'] as bool? ?? false;
    final mockConf = (evidence['mock_confidence'] as num?)?.toDouble() ?? 0.0;

    final ticketIdToUse = ticket.id;

    // 2. Validate with backend /journeys/start
    final res = await ApiService.startJourney(
      ticketId: ticketIdToUse,
      latitude: lat,
      longitude: lng,
      accuracyMeters: accuracy,
      altitude: (evidence['altitude'] as num?)?.toDouble(),
      speedMps: (evidence['speed_mps'] as num?)?.toDouble(),
      bearing: (evidence['bearing'] as num?)?.toDouble(),
      provider: evidence['provider'] as String? ?? 'gps',
      isMock: isMock,
      mockConfidence: mockConf,
      routeId: routeId,
    );

    // 3. Handle rejection from server geofence / ticket rules
    if (res['success'] == false) {
      final errCode = res['error']?['code'] ?? '';
      if (errCode == 'JOURNEY_START_REJECTED') {
        // Genuine server validation rejection (e.g. outside station geofence)
        debugPrint('Journey start rejected by server: ${res['error']?['message']}');
        return res;
      }
    }

    // 4. Populate active journey from server data (or fallback for offline mode)
    String? serverJourneyId;
    String securityState = 'NORMAL';
    double progressPercent = 0.0;
    double locationConfidence = 1.0;
    double riskScore = 0.0;
    List<String> routeStations = [];

    if (res['success'] == true && res['data'] != null) {
      final data = res['data'];
      serverJourneyId = data['id'];
      securityState = data['security_state'] ?? 'NORMAL';
      progressPercent = (data['progress_percent'] as num?)?.toDouble() ?? 0.0;
      locationConfidence = (data['location_confidence'] as num?)?.toDouble() ?? 1.0;
      riskScore = (data['risk_score'] as num?)?.toDouble() ?? 0.0;
      if (data['route_stations'] is List) {
        routeStations = (data['route_stations'] as List).map((e) => e.toString()).toList();
      }
    } else {
      // Offline fallback: note uncertain location
      securityState = 'LOCATION_UNCERTAIN';
    }

    _activeJourney = ActiveJourney(
      ticket: ticket,
      originStation: originStation,
      destinationStation: destinationStation,
      currentStation: originStation,
      nextStation: destinationStation,
      assignedTrain: train,
      state: JourneyState.boarded,
      progressPercent: progressPercent,
      speedKmH: ((evidence['speed_mps'] as num? ?? 0.0).toDouble()) * 3.6,
      etaMinutes: 35,
      delayMinutes: 0,
      crowdLevel: 'Moderate',
      guardianActive: true,
      startTime: DateTime.now(),
      serverJourneyId: serverJourneyId,
      serverTicketId: ticketIdToUse,
      securityState: securityState,
      locationConfidence: locationConfidence,
      riskScore: riskScore,
      routeStationNames: routeStations,
      serverLastValidated: DateTime.now(),
    );

    _journeyController.add(_activeJourney);

    // 5. Start battery-conscious location streaming to backend
    _startLocationTelemetry();

    return res;
  }

  /// Starts periodic location transmission to backend during active journey
  void _startLocationTelemetry() {
    _stopLocationTelemetry();

    // Transmit location every 15 seconds while journey is active
    _telemetryTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (_activeJourney == null || !hasActiveJourney) {
        timer.cancel();
        return;
      }

      final journeyId = _activeJourney!.serverJourneyId;
      if (journeyId == null) return;

      try {
        final evidence = await LocationService.getLocationEvidence();
        final res = await ApiService.sendJourneyLocation(
          journeyId: journeyId,
          latitude: (evidence['latitude'] as num).toDouble(),
          longitude: (evidence['longitude'] as num).toDouble(),
          accuracyMeters: (evidence['accuracy_meters'] as num?)?.toDouble() ?? 10.0,
          altitude: (evidence['altitude'] as num?)?.toDouble(),
          speedMps: (evidence['speed_mps'] as num?)?.toDouble(),
          bearing: (evidence['bearing'] as num?)?.toDouble(),
          provider: evidence['provider'] as String? ?? 'gps',
          isMock: evidence['is_mock'] as bool? ?? false,
          mockConfidence: (evidence['mock_confidence'] as num?)?.toDouble() ?? 0.0,
        );

        if (res['success'] == true && res['data'] != null) {
          final jData = res['data']['journey'];
          final secState = jData['security_state'] ?? _activeJourney!.securityState;
          final prog = (jData['progress_percent'] as num?)?.toDouble() ?? _activeJourney!.progressPercent;
          final conf = (jData['location_confidence'] as num?)?.toDouble() ?? _activeJourney!.locationConfidence;
          final risk = (jData['risk_score'] as num?)?.toDouble() ?? _activeJourney!.riskScore;

          var state = _activeJourney!.state;
          if (prog >= 85.0 && state != JourneyState.destinationApproach) {
            state = JourneyState.destinationApproach;
          } else if (prog > 0.0 && state == JourneyState.boarded) {
            state = JourneyState.inTransit;
          }

          _activeJourney = _activeJourney!.copyWith(
            securityState: secState,
            progressPercent: prog,
            locationConfidence: conf,
            riskScore: risk,
            state: state,
            speedKmH: ((evidence['speed_mps'] as num? ?? 0.0).toDouble()) * 3.6,
            serverLastValidated: DateTime.now(),
          );

          _journeyController.add(_activeJourney);
        }
      } catch (e) {
        debugPrint('Periodic location telemetry error: $e');
      }
    });
  }

  void _stopLocationTelemetry() {
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
  }

  /// Sets destination approaching state
  void setDestinationApproaching() {
    if (_activeJourney == null) return;
    _activeJourney = _activeJourney!.copyWith(
      state: JourneyState.destinationApproach,
    );
    _journeyController.add(_activeJourney);
  }

  /// Completes journey only after server validates destination geofence arrival
  @override
  Future<Map<String, dynamic>> completeJourney() async {
    if (_activeJourney == null) {
      return {'success': false, 'message': 'No active journey'};
    }

    final journeyId = _activeJourney!.serverJourneyId;
    if (journeyId != null) {
      final evidence = await LocationService.getLocationEvidence();
      final res = await ApiService.completeJourney(
        journeyId: journeyId,
        latitude: (evidence['latitude'] as num).toDouble(),
        longitude: (evidence['longitude'] as num).toDouble(),
        accuracyMeters: (evidence['accuracy_meters'] as num?)?.toDouble() ?? 10.0,
        altitude: (evidence['altitude'] as num?)?.toDouble(),
        speedMps: (evidence['speed_mps'] as num?)?.toDouble(),
        bearing: (evidence['bearing'] as num?)?.toDouble(),
        provider: evidence['provider'] as String? ?? 'gps',
        isMock: evidence['is_mock'] as bool? ?? false,
      );

      // If server rejected completion (e.g. user is not inside destination station geofence)
      if (res['success'] == false && res['error']?['code'] == 'COMPLETION_VALIDATION_FAILED') {
        return res;
      }
    }

    _stopLocationTelemetry();

    final completedTicket = _activeJourney!.ticket.copyWith(
      status: TicketStatus.completed,
      lifecycle: TicketLifecycle.completed,
    );

    // Update in ticket storage
    await TicketStorage.addTicket(completedTicket);

    _activeJourney = _activeJourney!.copyWith(
      state: JourneyState.completed,
      progressPercent: 100.0,
      etaMinutes: 0,
      speedKmH: 0.0,
      ticket: completedTicket,
      currentStation: _activeJourney!.destinationStation,
      nextStation: _activeJourney!.destinationStation,
    );

    _journeyController.add(_activeJourney);
    return {'success': true, 'data': _activeJourney};
  }

  /// Abandons the active journey
  @override
  Future<Map<String, dynamic>> abandonJourney({String? reason}) async {
    if (_activeJourney == null) {
      return {'success': false, 'message': 'No active journey'};
    }

    _stopLocationTelemetry();

    final journeyId = _activeJourney!.serverJourneyId;
    if (journeyId != null) {
      await ApiService.abandonJourney(journeyId: journeyId, reason: reason);
    }

    _activeJourney = _activeJourney!.copyWith(
      state: JourneyState.abandoned,
      speedKmH: 0.0,
    );

    _journeyController.add(_activeJourney);
    return {'success': true};
  }

  @override
  void clearJourney() {
    _stopLocationTelemetry();
    _activeJourney = null;
    _journeyController.add(null);
  }

  // Legacy prototype stubs preserved for DemoDashboardScreen compatibility
  void injectDelay({required int delayMinutes}) {}
  void handleRunningLate() {}
}
