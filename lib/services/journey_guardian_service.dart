import 'dart:async';
import '../models/journey.dart';
import '../models/station.dart';
import '../models/ticket.dart';
import '../models/train.dart';
import 'ticket_storage.dart';

class JourneyGuardianService {
  static final JourneyGuardianService _instance = JourneyGuardianService._internal();
  factory JourneyGuardianService() => _instance;
  JourneyGuardianService._internal();

  ActiveJourney? _activeJourney;
  ActiveJourney? get activeJourney => _activeJourney;
  bool get hasActiveJourney => _activeJourney != null && _activeJourney!.state != JourneyState.completed;

  final _journeyController = StreamController<ActiveJourney?>.broadcast();
  Stream<ActiveJourney?> get journeyStream => _journeyController.stream;

  Timer? _progressTimer;

  void startJourney({
    required BookedTicket ticket,
    required RailwayStation originStation,
    required RailwayStation destinationStation,
    LocoTrain? train,
  }) {
    _activeJourney = ActiveJourney(
      ticket: ticket,
      originStation: originStation,
      destinationStation: destinationStation,
      currentStation: originStation,
      nextStation: destinationStation,
      assignedTrain: train,
      state: JourneyState.boarded,
      progressPercent: 12.0,
      speedKmH: 52.0,
      etaMinutes: 28,
      delayMinutes: 0,
      crowdLevel: train?.crowdLevel ?? 'Moderate',
      guardianActive: true,
      startTime: DateTime.now(),
    );

    _journeyController.add(_activeJourney);
    _startLiveTrackingSimulation();
  }

  void _startLiveTrackingSimulation() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_activeJourney == null || _activeJourney!.state == JourneyState.completed) {
        timer.cancel();
        return;
      }

      double newProgress = _activeJourney!.progressPercent + 3.5;
      int newEta = _activeJourney!.etaMinutes > 1 ? _activeJourney!.etaMinutes - 1 : 1;
      JourneyState newState = _activeJourney!.state;

      if (newProgress >= 85.0 && newProgress < 98.0) {
        newState = JourneyState.destinationApproach;
      } else if (newProgress >= 100.0) {
        newProgress = 100.0;
        newState = JourneyState.completed;
        completeJourney();
        return;
      }

      _activeJourney = _activeJourney!.copyWith(
        progressPercent: newProgress,
        etaMinutes: newEta,
        state: newState,
        speedKmH: (newState == JourneyState.destinationApproach) ? 28.0 : 58.0,
      );

      _journeyController.add(_activeJourney);
    });
  }

  /// Injects simulated train delay and generates alternative route suggestion
  void injectDelay({required int delayMinutes, String? alternativeRoute}) {
    if (_activeJourney == null) return;

    _activeJourney = _activeJourney!.copyWith(
      delayMinutes: delayMinutes,
      etaMinutes: _activeJourney!.etaMinutes + delayMinutes,
      isAlternativeAvailable: true,
      alternativeReason: alternativeRoute ?? 'WR-90215 (AC Local) leaves in 4 min from Platform 4. Arrives 8 min earlier.',
    );
    _journeyController.add(_activeJourney);
  }

  /// "I'm running late" feature action
  void handleRunningLate() {
    if (_activeJourney == null) return;
    _activeJourney = _activeJourney!.copyWith(
      isAlternativeAvailable: true,
      alternativeReason: 'Re-routing: Next Superfast local leaves at 10:14 AM. Platform 3.',
    );
    _journeyController.add(_activeJourney);
  }

  /// Sets destination approaching state
  void setDestinationApproaching() {
    if (_activeJourney == null) return;
    _activeJourney = _activeJourney!.copyWith(
      state: JourneyState.destinationApproach,
      progressPercent: 92.0,
      etaMinutes: 3,
      speedKmH: 26.0,
    );
    _journeyController.add(_activeJourney);
  }

  /// Completes journey, marks ticket completed in storage
  Future<void> completeJourney() async {
    if (_activeJourney == null) return;
    _progressTimer?.cancel();

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
    );

    _journeyController.add(_activeJourney);
  }

  void clearJourney() {
    _progressTimer?.cancel();
    _activeJourney = null;
    _journeyController.add(null);
  }
}
