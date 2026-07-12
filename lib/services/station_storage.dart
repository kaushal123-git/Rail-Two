import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../models/station.dart';

class StationStorage {
  static const String _fileName = 'custom_stations.json';

  /// Gets the local file reference to read/write custom stations on mobile devices.
  static Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  /// Loads all stations by merging default stations from assets and custom stations from local storage.
  static Future<List<RailwayStation>> loadAllStations() async {
    List<RailwayStation> stations = [];

    // 1. Load default stations from assets
    try {
      final String jsonString = await rootBundle.loadString('assets/default_stations.json');
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      stations.addAll(jsonList.map((j) => RailwayStation.fromJson(j as Map<String, dynamic>)));
    } catch (e) {
      // Asset loading failed or file doesn't exist yet
      print('Warning: Default stations asset not loaded: $e');
    }

    // 2. Load custom user-added stations from local file
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final String jsonString = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
        
        // Merge custom stations, ensuring no ID collision
        for (var item in jsonList) {
          final station = RailwayStation.fromJson(item as Map<String, dynamic>);
          // If a custom station shares an ID with a default one, we prioritize the default
          if (!stations.any((s) => s.id == station.id)) {
            stations.add(station);
          }
        }
      }
    } catch (e) {
      print('Error loading custom stations: $e');
    }

    return stations;
  }

  /// Adds and saves a new custom railway station to local storage.
  static Future<void> saveCustomStation(RailwayStation newStation) async {
    try {
      final file = await _localFile;
      List<RailwayStation> customStations = [];

      // Load existing custom stations
      if (await file.exists()) {
        final String jsonString = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
        customStations = jsonList.map((j) => RailwayStation.fromJson(j as Map<String, dynamic>)).toList();
      }

      // Check if station already exists and update or add it
      final index = customStations.indexWhere((s) => s.id == newStation.id);
      if (index != -1) {
        customStations[index] = newStation;
      } else {
        customStations.add(newStation);
      }

      // Serialize and write back to file
      final jsonList = customStations.map((s) => s.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      print('Error saving custom station: $e');
    }
  }

  /// Deletes a custom station from local storage by ID.
  static Future<void> deleteCustomStation(String id) async {
    try {
      final file = await _localFile;
      if (!await file.exists()) return;

      final String jsonString = await file.readAsString();
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      
      List<RailwayStation> customStations = jsonList
          .map((j) => RailwayStation.fromJson(j as Map<String, dynamic>))
          .toList();

      customStations.removeWhere((s) => s.id == id);

      final updatedJsonList = customStations.map((s) => s.toJson()).toList();
      await file.writeAsString(json.encode(updatedJsonList));
    } catch (e) {
      print('Error deleting custom station: $e');
    }
  }
}
