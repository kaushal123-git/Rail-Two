import '../models/ai_models.dart';

/// Legacy engine preserved for interface compatibility.
/// Fake DateTime.now() schedule generation and crowd prediction have been removed.
/// Live railway telemetry will connect via LOCO Backend in Phase 4.
@Deprecated('Use LocoAssistService and TrainRepository directly')
class LiveRailTelemetryEngine {
  static final LiveRailTelemetryEngine _instance = LiveRailTelemetryEngine._internal();
  factory LiveRailTelemetryEngine() => _instance;
  LiveRailTelemetryEngine._internal();

  /// Live schedule status (Phase 0: honest unavailable state)
  String getLiveScheduleReport({String? origin, String? destination, String? line}) {
    return 'Live railway timetable feed unavailable. Real-time timetable integration scheduled for Phase 4.';
  }

  /// Delay risk report (Phase 0: honest unavailable state)
  String getDelayRiskReport(String? stationName) {
    return 'Track signal and delay telemetry unavailable. Real-time railway feed scheduled for Phase 4.';
  }

  /// Coach crowd radar (Removed from LOCO product scope)
  String getCoachCrowdRadar(String? stationName, String? line) {
    return 'Crowd prediction has been removed from LOCO product scope.';
  }

  /// Returns 12-coach crowd breakdown data (Empty list in Phase 0)
  List<CoachCrowdData> getCoachCrowdList(String? stationName) {
    return const [];
  }

  /// Provides interchange guide for major junctions (Dadar, Kurla, Bandra)
  String getInterchangeGuide(String stationName) {
    final s = stationName.toUpperCase();
    if (s.contains('DADAR')) {
      return '🚉 Dadar Master Interchange Guide:\n\n'
          '• Western Line (PF 1-3) ↔️ Central Line (PF 4-8):\n'
          '  Use the central FOB connector located at Coach C7 position. Walk 90 seconds East across the bridge.\n'
          '• For Thane/Kalyan fast trains: Proceed to Central Platform 4.\n'
          '• For CSMT fast trains: Proceed to Central Platform 6.\n'
          '• Food Spot: Aaswad Upahar (Misal Pav) is 200m from West exit gate!';
    } else if (s.contains('KURLA')) {
      return '🚉 Kurla Interchange Guide:\n\n'
          '• Central Main Line (PF 1-4) ↔️ Harbour Line (PF 7-8):\n'
          '  Use the North FOB at Coach C11 position for seamless elevated transfer to Harbour Line.\n'
          '• For Navi Mumbai / Panvel: Board from Platform 7.';
    }

    return '🚉 Interchange Guidance for $stationName:\n\n'
        '• Follow overhead blue platform signs for Foot Overbridge (FOB) connectors.\n'
        '• Board middle coaches for nearest stairway access.';
  }

  /// Retrieves local station food & landmark highlights
  List<DestinationSpot> getStationPOISpots(String stationName) {
    final s = stationName.toUpperCase();
    if (s.contains('DADAR')) {
      return [
        DestinationSpot(
          id: 'd1',
          name: 'Aaswad Upahar',
          category: 'Iconic Food',
          distanceText: '250 m from West exit',
          rating: 4.8,
          description: 'Award-winning Maharashtrian Misal Pav & Thalipeeth.',
          icon: '🍲',
          stationName: 'Dadar',
          exitGate: 'Dadar West',
        ),
        DestinationSpot(
          id: 'd2',
          name: 'Shivaji Park',
          category: 'Park & Culture',
          distanceText: '900 m away',
          rating: 4.7,
          description: 'Historic cultural park with seaside sea-breeze walks.',
          icon: '🌳',
          stationName: 'Dadar',
          exitGate: 'Dadar West',
        ),
        DestinationSpot(
          id: 'd3',
          name: 'Dadar Flower Market',
          category: 'Shopping & Visuals',
          distanceText: '150 m from Flyover',
          rating: 4.6,
          description: 'Largest floral market in Asia with vibrant morning blossoms.',
          icon: '🌸',
          stationName: 'Dadar',
          exitGate: 'Dadar West',
        ),
      ];
    } else if (s.contains('BANDRA')) {
      return [
        DestinationSpot(
          id: 'b1',
          name: 'Subko Coffee Roasters',
          category: 'Artisanal Cafe',
          distanceText: '800 m away',
          rating: 4.9,
          description: 'Specialty craft coffees and sourdough baked treats.',
          icon: '☕',
          stationName: 'Bandra',
          exitGate: 'Bandra West',
        ),
        DestinationSpot(
          id: 'b2',
          name: 'Elco Pani Puri',
          category: 'Iconic Street Food',
          distanceText: '600 m away (Hill Road)',
          rating: 4.7,
          description: 'Famous hygienic mineral water Pani Puri and Chaat.',
          icon: '🥟',
          stationName: 'Bandra',
          exitGate: 'Bandra West',
        ),
      ];
    }

    return [
      DestinationSpot(
        id: 'gen1',
        name: 'Station Front Market',
        category: 'Quick Bites',
        distanceText: '80 m from platform exit',
        rating: 4.5,
        description: 'Fresh Mumbai cutting chai, samosa, and hot vada pav.',
        icon: '☕',
        stationName: stationName,
      ),
      DestinationSpot(
        id: 'gen2',
        name: 'Auto & Cab Stand',
        category: 'Transit Connection',
        distanceText: '30 m from West gate',
        rating: 4.4,
        description: 'Regulated meter autorickshaw and sharing transit stand.',
        icon: '🚖',
        stationName: stationName,
      ),
    ];
  }
}
