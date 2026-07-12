import '../services/s2_helper.dart';

class RailwayStation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  late final String s2CellToken;
  late final String s2CellId;

  RailwayStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  RailwayStation copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
  }) {
    return RailwayStation(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
