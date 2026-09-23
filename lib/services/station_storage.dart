import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/station.dart';
import 'custom_station_persistence.dart';

class StationStorage {
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

    // 2. Load custom user-added stations from local file/local storage
    try {
      final List<RailwayStation> customStations = await customStationPersistence.loadCustomStations();
      
      // Merge custom stations, ensuring no ID collision
      for (var station in customStations) {
        // If a custom station shares an ID with a default one, we prioritize the default
        if (!stations.any((s) => s.id == station.id)) {
          stations.add(station);
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
      List<RailwayStation> customStations = await customStationPersistence.loadCustomStations();

      // Check if station already exists and update or add it
      final index = customStations.indexWhere((s) => s.id == newStation.id);
      if (index != -1) {
        customStations[index] = newStation;
      } else {
        customStations.add(newStation);
      }

      await customStationPersistence.saveCustomStations(customStations);
    } catch (e) {
      print('Error saving custom station: $e');
    }
  }

  /// Deletes a custom station from local storage by ID.
  static Future<void> deleteCustomStation(String id) async {
    try {
      List<RailwayStation> customStations = await customStationPersistence.loadCustomStations();
      
      customStations.removeWhere((s) => s.id == id);

      await customStationPersistence.saveCustomStations(customStations);
    } catch (e) {
      print('Error deleting custom station: $e');
    }
  }
}

