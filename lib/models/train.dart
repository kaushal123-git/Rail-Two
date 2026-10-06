class LocoTrain {
  final String id;
  final String name;
  final String number;
  final String line; // Western, Central, Harbour
  final String trainType; // Fast Local, Slow Local, AC Superfast, AC EMU
  final String originStation;
  final String destinationStation;
  final String currentStation;
  final String nextStation;
  final double progress; // 0.0 to 1.0
  final double speedKmH;
  final int etaMinutes;
  final int delayMinutes;
  final String crowdLevel; // Low, Moderate, High, Very High
  final String status; // On Time, Delayed, Arriving, Boarding
  final List<String> routeStationNames;
  final double lat;
  final double lng;
  final bool isAc;

  LocoTrain({
    required this.id,
    required this.name,
    required this.number,
    required this.line,
    required this.trainType,
    required this.originStation,
    required this.destinationStation,
    required this.currentStation,
    required this.nextStation,
    required this.progress,
    required this.speedKmH,
    required this.etaMinutes,
    this.delayMinutes = 0,
    required this.crowdLevel,
    required this.status,
    required this.routeStationNames,
    required this.lat,
    required this.lng,
    this.isAc = false,
  });

  LocoTrain copyWith({
    String? id,
    String? name,
    String? number,
    String? line,
    String? trainType,
    String? originStation,
    String? destinationStation,
    String? currentStation,
    String? nextStation,
    double? progress,
    double? speedKmH,
    int? etaMinutes,
    int? delayMinutes,
    String? crowdLevel,
    String? status,
    List<String>? routeStationNames,
    double? lat,
    double? lng,
    bool? isAc,
  }) {
    return LocoTrain(
      id: id ?? this.id,
      name: name ?? this.name,
      number: number ?? this.number,
      line: line ?? this.line,
      trainType: trainType ?? this.trainType,
      originStation: originStation ?? this.originStation,
      destinationStation: destinationStation ?? this.destinationStation,
      currentStation: currentStation ?? this.currentStation,
      nextStation: nextStation ?? this.nextStation,
      progress: progress ?? this.progress,
      speedKmH: speedKmH ?? this.speedKmH,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      delayMinutes: delayMinutes ?? this.delayMinutes,
      crowdLevel: crowdLevel ?? this.crowdLevel,
      status: status ?? this.status,
      routeStationNames: routeStationNames ?? this.routeStationNames,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isAc: isAc ?? this.isAc,
    );
  }

  bool get isFast => trainType.toLowerCase().contains('fast');
}
