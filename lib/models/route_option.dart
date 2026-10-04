class RouteOption {
  final String id;
  final String title; // FASTEST, LEAST CROWDED, CHEAPEST, FEWEST TRANSFERS, AC COMFORT
  final String badgeText; // "Recommended", "Least Crowded", "Best Value", "Air Conditioned"
  final int durationMinutes;
  final int fare;
  final String trainType; // Fast Local, Slow Local, AC Superfast
  final int nextDepartureInMin;
  final String crowdLevel; // Low, Moderate, High, Very High
  final int transfers;
  final String description;
  final List<String> intermediateStops;

  RouteOption({
    required this.id,
    required this.title,
    required this.badgeText,
    required this.durationMinutes,
    required this.fare,
    required this.trainType,
    required this.nextDepartureInMin,
    required this.crowdLevel,
    this.transfers = 0,
    required this.description,
    required this.intermediateStops,
  });
}
