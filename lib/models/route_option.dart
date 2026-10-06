class RouteOption {
  final String id;
  final String title; // FASTEST, CHEAPEST, FEWEST TRANSFERS, AC COMFORT
  final String badgeText;
  final int durationMinutes;
  final int fare;
  final String trainType; // Fast Local, Slow Local, AC Superfast
  final int nextDepartureInMin;
  final String crowdLevel; // Deprecated in Phase 0 (Crowd AI removed)
  final int transfers;
  final String description;
  final List<String> intermediateStops;
  final String platform;
  final int acFare;
  final String? networkVersion;
  final List<Map<String, dynamic>> legs;

  RouteOption({
    required this.id,
    required this.title,
    required this.badgeText,
    required this.durationMinutes,
    required this.fare,
    required this.trainType,
    required this.nextDepartureInMin,
    this.crowdLevel = '',
    this.transfers = 0,
    required this.description,
    required this.intermediateStops,
    this.platform = '1',
    this.acFare = 65,
    this.networkVersion,
    this.legs = const [],
  });

  factory RouteOption.fromBackendJson(Map<String, dynamic> json) {
    final rawLegs = (json['legs'] as List<dynamic>?) ?? [];
    final List<Map<String, dynamic>> parsedLegs =
        rawLegs.map((l) => Map<String, dynamic>.from(l as Map)).toList();

    final Set<String> stopsSet = {};
    for (final leg in parsedLegs) {
      final seq = (leg['station_sequence'] as List<dynamic>?) ?? [];
      for (final st in seq) {
        stopsSet.add(st.toString());
      }
    }

    String trainType = 'Slow Local';
    final title = (json['title'] ?? 'FASTEST').toString().toUpperCase();
    if (title.contains('AC') || parsedLegs.any((l) => (l['service_type'] ?? '').toString().contains('AC'))) {
      trainType = 'AC Superfast';
    } else if (title.contains('FAST') || parsedLegs.any((l) => (l['service_type'] ?? '').toString().contains('FAST'))) {
      trainType = 'Fast Local';
    }

    final transfers = (json['transfers_count'] as num?)?.toInt() ?? 0;
    String desc;
    if (transfers > 0) {
      desc = '${json['origin_station_name']} → ${json['destination_station_name']} via $transfers transfer(s)';
    } else if (parsedLegs.isNotEmpty) {
      desc = '${parsedLegs.first['line_name'] ?? 'Direct'} • Direct journey without transfers';
    } else {
      desc = '${json['origin_station_name']} to ${json['destination_station_name']}';
    }

    return RouteOption(
      id: json['route_id'] ?? '',
      title: json['title'] ?? 'FASTEST',
      badgeText: json['badge_text'] ?? '⚡ Fastest',
      durationMinutes: (json['total_duration_minutes'] as num?)?.toInt() ?? 0,
      fare: (json['fare_estimate'] as num?)?.toInt() ?? 10,
      trainType: trainType,
      nextDepartureInMin: 4,
      transfers: transfers,
      description: desc,
      intermediateStops: stopsSet.toList(),
      platform: '1',
      acFare: (json['ac_fare_estimate'] as num?)?.toInt() ?? 65,
      networkVersion: json['network_version'],
      legs: parsedLegs,
    );
  }

  bool get isFast => trainType.toLowerCase().contains('fast');
  bool get isAc => trainType.toLowerCase().contains('ac');
  List<String> get stops => intermediateStops;
  int get departsInMinutes => nextDepartureInMin;
  int get duration => durationMinutes;
}
