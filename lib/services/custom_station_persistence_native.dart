import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/station.dart';
import 'custom_station_persistence.dart';

CustomStationPersistence getPersistence() => CustomStationPersistenceNative();

class CustomStationPersistenceNative implements CustomStationPersistence {
  static const String _fileName = 'custom_stations.json';

  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  @override
  Future<List<RailwayStation>> loadCustomStations() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final String jsonString = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
        return jsonList
            .map((j) => RailwayStation.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Error loading custom stations: $e');
    }
    return [];
  }

  @override
  Future<void> saveCustomStations(List<RailwayStation> customStations) async {
    try {
      final file = await _localFile;
      final jsonList = customStations.map((s) => s.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      print('Error saving custom stations: $e');
    }
  }
}
