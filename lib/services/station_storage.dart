import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/station.dart';
import 'api_service.dart';
import 'custom_station_persistence.dart';

class StationStorage {
  /// Loads all stations by querying the real PostgreSQL backend authority.
  /// Falls back gracefully to local assets when offline.
  static Future<List<RailwayStation>> loadAllStations() async {
    List<RailwayStation> stations = [];

    // 1. Query LOCO FastAPI Backend (PostgreSQL database authority)
    try {
      final isOnline = await ApiService.isServerAvailable();
      if (isOnline) {
        final backendStations = await ApiService.getStations(limit: 100);
        if (backendStations.isNotEmpty) {
          for (final s in backendStations) {
            final stationId = s['id']?.toString() ?? s['code']?.toString() ?? '';
            final stationName = s['name']?.toString() ?? '';
            final lat = (s['latitude'] as num?)?.toDouble() ?? 18.9398;
            final lng = (s['longitude'] as num?)?.toDouble() ?? 72.8354;
            final zone = s['zone']?.toString() ?? 'Western';

            stations.add(RailwayStation(
              id: stationId,
              name: stationName,
              latitude: lat,
              longitude: lng,
              line: zone,
              isJunction: false,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('Notice: Backend stations query fallback: $e');
    }

    // 2. If backend was unreachable or returned empty, load default stations from assets as offline fallback
    if (stations.isEmpty) {
      try {
        final String jsonString = await rootBundle.loadString('assets/default_stations.json');
        final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
        stations.addAll(jsonList.map((j) => RailwayStation.fromJson(j as Map<String, dynamic>)));
      } catch (e) {
        debugPrint('Warning: Default stations asset not loaded: $e');
      }
    }

    // 3. Load custom user-added stations from local file/local storage
    try {
      final List<RailwayStation> customStations = await customStationPersistence.loadCustomStations();
      for (var station in customStations) {
        if (!stations.any((s) => s.id == station.id)) {
          stations.add(station);
        }
      }
    } catch (e) {
      debugPrint('Error loading custom stations: $e');
    }

    return stations;
  }

  /// Adds and saves a new custom railway station to local storage.
  static Future<void> saveCustomStation(RailwayStation newStation) async {
    try {
      List<RailwayStation> customStations = await customStationPersistence.loadCustomStations();

      final index = customStations.indexWhere((s) => s.id == newStation.id);
      if (index != -1) {
        customStations[index] = newStation;
      } else {
        customStations.add(newStation);
      }

      await customStationPersistence.saveCustomStations(customStations);
    } catch (e) {
      debugPrint('Error saving custom station: $e');
    }
  }

  /// Deletes a custom station from local storage by ID.
  static Future<void> deleteCustomStation(String id) async {
    try {
      List<RailwayStation> customStations = await customStationPersistence.loadCustomStations();
      customStations.removeWhere((s) => s.id == id);
      await customStationPersistence.saveCustomStations(customStations);
    } catch (e) {
      debugPrint('Error deleting custom station: $e');
    }
  }
}
