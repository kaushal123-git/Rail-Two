import '../services/s2_helper.dart';

class RailwayStation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String line; // Western, Central, Harbour
  final bool isJunction;
  final List<String> facilities;
  final int platformsCount;
  final String crowdLevel; // Low, Moderate, High, Very High
  late final String s2CellToken;
  late final String s2CellId;

  RailwayStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.line = 'Western',
    this.isJunction = false,
    this.facilities = const ['ATVM', 'Wi-Fi', 'Water', 'Toilets'],
    this.platformsCount = 4,
    this.crowdLevel = 'Moderate',
  }) {
    _calculateS2Properties();
  }

  void _calculateS2Properties() {
    s2CellToken = s2Helper.getCellToken(latitude, longitude);
    s2CellId = s2Helper.getCellIdString(latitude, longitude);
  }

  factory RailwayStation.fromJson(Map<String, dynamic> json) {
    return RailwayStation(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      line: json['line'] as String? ?? 'Western',
      isJunction: json['isJunction'] as bool? ?? false,
      facilities: (json['facilities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const ['ATVM', 'Wi-Fi', 'Water', 'Toilets'],
      platformsCount: (json['platformsCount'] as num?)?.toInt() ?? 4,
      crowdLevel: json['crowdLevel'] as String? ?? 'Moderate',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'line': line,
      'isJunction': isJunction,
      'facilities': facilities,
      'platformsCount': platformsCount,
      'crowdLevel': crowdLevel,
    };
  }

  RailwayStation copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? line,
    bool? isJunction,
    List<String>? facilities,
    int? platformsCount,
    String? crowdLevel,
  }) {
    return RailwayStation(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      line: line ?? this.line,
      isJunction: isJunction ?? this.isJunction,
      facilities: facilities ?? this.facilities,
      platformsCount: platformsCount ?? this.platformsCount,
      crowdLevel: crowdLevel ?? this.crowdLevel,
    );
  }

  String get code => getStationCode(name);
}

String getStationCode(String name) {
  final Map<String, String> codes = {
    'VIRAR': 'VR',
    'BORIVALI': 'BVI',
    'VASAI ROAD': 'BSR',
    'DAHISAR': 'DIC',
    'NALASOPARA': 'NSP',
    'NAIGAON': 'NIG',
    'BHAYANDAR': 'BYR',
    'MIRA ROAD': 'MIRA',
    'KANDIVALI': 'KILE',
    'MALAD': 'MDD',
    'GOREGAON': 'GMN',
    'RAM MANDIR': 'RMAR',
    'JOGESHWARI': 'JOS',
    'ANDHERI': 'ADH',
    'VILLE PARLE': 'VLP',
    'SANTA CRUZ': 'STC',
    'KHAR ROAD': 'KHAR',
    'BANDRA': 'BA',
    'MAHIM': 'MM',
    'MATUNGA ROAD': 'MRU',
    'DADAR': 'DDR',
    'PRABHADEVI': 'PBHD',
    'LOWER PAREL': 'PL',
    'MAHALAXMI': 'MX',
    'MUMBAI CENTRAL': 'MMCT',
    'GRANT ROAD': 'GTR',
    'CHARNI ROAD': 'CYR',
    'MARINE LINES': 'MEL',
    'CHURCHGATE': 'CCG',
    'CSMT': 'CSMT',
    'BYCULLA': 'BY',
    'KURLA': 'CLA',
    'GHATKOPAR': 'GC',
    'THANE': 'TNA',
    'KALYAN': 'KYN',
    'WADALA ROAD': 'VDLR',
    'CHEMBUR': 'CMBR',
    'VASHI': 'VSH',
    'NERUL': 'NEU',
    'PANVEL': 'PNVL',
  };
  final upper = name.toUpperCase().trim();
  if (codes.containsKey(upper)) return codes[upper]!;
  for (var entry in codes.entries) {
    if (upper.contains(entry.key) || entry.key.contains(upper)) {
      return entry.value;
    }
  }
  return upper.length >= 3 ? upper.substring(0, 3) : upper;
}
