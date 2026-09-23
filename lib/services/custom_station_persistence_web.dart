import 'dart:convert';
import 'dart:html' as html;
import '../models/station.dart';
import 'custom_station_persistence.dart';

CustomStationPersistence getPersistence() => CustomStationPersistenceWeb();

class CustomStationPersistenceWeb implements CustomStationPersistence {
  static const String _key = 'custom_stations';

  @override
  Future<List<RailwayStation>> loadCustomStations() async {
    try {
      final data = html.window.localStorage[_key];
      if (data != null) {
        final List<dynamic> jsonList = json.decode(data) as List<dynamic>;
        return jsonList
            .map((j) => RailwayStation.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Error loading custom stations on web: $e');
    }
    return [];
  }

  @override
  Future<void> saveCustomStations(List<RailwayStation> customStations) async {
    try {
      final jsonList = customStations.map((s) => s.toJson()).toList();
      html.window.localStorage[_key] = json.encode(jsonList);
    } catch (e) {
      print('Error saving custom stations on web: $e');
    }
  }
}
