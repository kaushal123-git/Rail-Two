/// Legacy crowd service - crowd prediction has been removed from the LOCO product scope (Phase 0).
/// This file remains as an empty shell during Phase 0 cleanup.
@Deprecated('Crowd prediction removed from LOCO product scope')
class CoachCrowdInfo {
  final String coachId;
  final int crowdPercent;
  final String densityLevel;
  final String tip;

  CoachCrowdInfo({
    required this.coachId,
    required this.crowdPercent,
    required this.densityLevel,
    required this.tip,
  });
}

@Deprecated('Crowd prediction removed from LOCO product scope')
class CrowdPredictionService {
  static const bool isLiveApi = false;

  static Future<void> loadModel() async {
    // Crowd ML prediction model removed from LOCO product scope.
  }

  static String predictCrowdLevel({
    required String stationName,
    DateTime? time,
  }) {
    return 'Moderate';
  }

  static double predictCrowdPercentage({
    required String stationName,
    DateTime? time,
    bool isSouthbound = true,
    bool isFast = true,
    bool isAc = false,
  }) {
    return 50.0;
  }

  static List<CoachCrowdInfo> predictCoachCrowd({
    required String stationName,
    int totalCoaches = 15,
    DateTime? time,
    bool isSouthbound = true,
    bool isFast = true,
  }) {
    return [];
  }
}
