import 'station.dart';
import 'ticket.dart';
import 'train.dart';

enum JourneyState {
  none,
  planned,
  atStation,
  boarded,
  inTransit,
  destinationApproach,
  completed,
  abandoned,
  suspicious,
}

class ActiveJourney {
  final BookedTicket ticket;
  final RailwayStation originStation;
  final RailwayStation destinationStation;
  final RailwayStation currentStation;
  final RailwayStation nextStation;
  final LocoTrain? assignedTrain;
  final JourneyState state;
  final double progressPercent; // 0 to 100
  final double speedKmH;
  final int etaMinutes;
  final int delayMinutes;
  final String crowdLevel;
  final bool guardianActive;
  final bool isAlternativeAvailable;
  final String? alternativeReason;
  final DateTime startTime;

  // Phase 4 Backend Integration Fields
  final String? serverJourneyId;
  final String? serverTicketId;
  final String securityState; // NORMAL, LOCATION_UNCERTAIN, ROUTE_DEVIATION, SECURITY_WARNING, SUSPICIOUS
  final double locationConfidence; // 0.0 to 1.0
  final double riskScore; // 0.0 to 1.0
  final List<String> routeStationNames;
  final int currentStationIndex;
  final DateTime? serverLastValidated;
  final Map<String, dynamic>? lastIntegrityReport;

  ActiveJourney({
    required this.ticket,
    required this.originStation,
    required this.destinationStation,
    required this.currentStation,
    required this.nextStation,
    this.assignedTrain,
    this.state = JourneyState.planned,
    this.progressPercent = 0.0,
    this.speedKmH = 0.0,
    this.etaMinutes = 35,
    this.delayMinutes = 0,
    this.crowdLevel = 'Moderate',
    this.guardianActive = true,
    this.isAlternativeAvailable = false,
    this.alternativeReason,
    DateTime? startTime,
    this.serverJourneyId,
    this.serverTicketId,
    this.securityState = 'NORMAL',
    this.locationConfidence = 1.0,
    this.riskScore = 0.0,
    this.routeStationNames = const [],
    this.currentStationIndex = 0,
    this.serverLastValidated,
    this.lastIntegrityReport,
  }) : startTime = startTime ?? DateTime.now();

  ActiveJourney copyWith({
    BookedTicket? ticket,
    RailwayStation? originStation,
    RailwayStation? destinationStation,
    RailwayStation? currentStation,
    RailwayStation? nextStation,
    LocoTrain? assignedTrain,
    JourneyState? state,
    double? progressPercent,
    double? speedKmH,
    int? etaMinutes,
    int? delayMinutes,
    String? crowdLevel,
    bool? guardianActive,
    bool? isAlternativeAvailable,
    String? alternativeReason,
    DateTime? startTime,
    String? serverJourneyId,
    String? serverTicketId,
    String? securityState,
    double? locationConfidence,
    double? riskScore,
    List<String>? routeStationNames,
    int? currentStationIndex,
    DateTime? serverLastValidated,
    Map<String, dynamic>? lastIntegrityReport,
  }) {
    return ActiveJourney(
      ticket: ticket ?? this.ticket,
      originStation: originStation ?? this.originStation,
      destinationStation: destinationStation ?? this.destinationStation,
      currentStation: currentStation ?? this.currentStation,
      nextStation: nextStation ?? this.nextStation,
      assignedTrain: assignedTrain ?? this.assignedTrain,
      state: state ?? this.state,
      progressPercent: progressPercent ?? this.progressPercent,
      speedKmH: speedKmH ?? this.speedKmH,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      delayMinutes: delayMinutes ?? this.delayMinutes,
      crowdLevel: crowdLevel ?? this.crowdLevel,
      guardianActive: guardianActive ?? this.guardianActive,
      isAlternativeAvailable: isAlternativeAvailable ?? this.isAlternativeAvailable,
      alternativeReason: alternativeReason ?? this.alternativeReason,
      startTime: startTime ?? this.startTime,
      serverJourneyId: serverJourneyId ?? this.serverJourneyId,
      serverTicketId: serverTicketId ?? this.serverTicketId,
      securityState: securityState ?? this.securityState,
      locationConfidence: locationConfidence ?? this.locationConfidence,
      riskScore: riskScore ?? this.riskScore,
      routeStationNames: routeStationNames ?? this.routeStationNames,
      currentStationIndex: currentStationIndex ?? this.currentStationIndex,
      serverLastValidated: serverLastValidated ?? this.serverLastValidated,
      lastIntegrityReport: lastIntegrityReport ?? this.lastIntegrityReport,
    );
  }
}
