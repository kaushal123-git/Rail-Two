import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/station.dart';
import 'location_service.dart';
import 'station_storage.dart';

/// Global unified state manager for active station & route context across LOCO.
/// When the user's location is detected or a station is chosen, all views
/// (Home, Live Routes, Platform Pass, Booking, and LOCOpilot AI) update automatically.
class StationStateService extends ChangeNotifier {
  static final StationStateService _instance = StationStateService._internal();
  factory StationStateService() => _instance;
  StationStateService._internal();

  List<RailwayStation> _stations = [];
  List<RailwayStation> get stations => List.unmodifiable(_stations);

  // Default initial origin (Virar as shown in UI reference)
  RailwayStation _currentStation = RailwayStation(
    id: 'virar',
    name: 'Virar',
    latitude: 19.4699,
    longitude: 72.8118,
    line: 'Western',
    isJunction: false,
    platformsCount: 8,
    crowdLevel: 'Moderate',
  );

  // Default initial destination (Dadar WR / CR as shown in UI reference)
  RailwayStation _destinationStation = RailwayStation(
    id: 'dadar',
    name: 'Dadar (WR / CR)',
    latitude: 19.0192,
    longitude: 72.8438,
    line: 'Western',
    isJunction: true,
    platformsCount: 8,
    crowdLevel: 'High',
  );

  bool _isDetecting = false;
  bool get isDetecting => _isDetecting;

  String? _lastDetectionMessage;
  String? get lastDetectionMessage => _lastDetectionMessage;

  Position? _lastGpsPosition;
  Position? get lastGpsPosition => _lastGpsPosition;

  RailwayStation get currentStation => _currentStation;
  RailwayStation get destinationStation => _destinationStation;

  /// Initializes stations and attempts transparent GPS location detection
  Future<void> initialize() async {
    try {
      final loaded = await StationStorage.loadAllStations();
      if (loaded.isNotEmpty) {
        _stations = loaded;

        // Try to match or initialize currentStation with loaded data
        final foundVirar = _stations.firstWhere(
          (s) => s.id.toLowerCase() == 'virar' || s.name.toUpperCase().contains('VIRAR'),
          orElse: () => _stations.first,
        );
        _currentStation = foundVirar;

        final foundDadar = _stations.firstWhere(
          (s) => s.id.toLowerCase() == 'dadar' || s.name.toUpperCase().contains('DADAR'),
          orElse: () => _stations.length > 5 ? _stations[5] : _stations.last,
        );
        _destinationStation = foundDadar;
      }
      notifyListeners();

      // Silently attempt GPS location detection
      await detectCurrentLocation(silent: true);
    } catch (e) {
      debugPrint('Error initializing StationStateService: $e');
    }
  }

  /// Detects the user's current GPS position, finds the nearest Mumbai station,
  /// and updates the default origin station across the entire app.
  Future<RailwayStation?> detectCurrentLocation({bool silent = false}) async {
    _isDetecting = true;
    _lastDetectionMessage = 'Detecting current GPS location...';
    if (!silent) notifyListeners();

    try {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        _lastGpsPosition = position;
        final nearest = findNearestStation(position.latitude, position.longitude);
        if (nearest != null) {
          _currentStation = nearest;
          _lastDetectionMessage = 'Detected near ${nearest.name}';
          _isDetecting = false;
          notifyListeners();
          return nearest;
        }
      } else {
        _lastDetectionMessage = 'Location permission not available. Using default station.';
      }
    } catch (e) {
      _lastDetectionMessage = 'Location error: $e';
    } finally {
      _isDetecting = false;
      notifyListeners();
    }
    return null;
  }

  /// Finds the nearest station given latitude and longitude coordinates
  RailwayStation? findNearestStation(double latitude, double longitude) {
    if (_stations.isEmpty) return null;
    RailwayStation? nearest;
    double minDistance = double.infinity;

    for (final s in _stations) {
      final d = Geolocator.distanceBetween(latitude, longitude, s.latitude, s.longitude);
      if (d < minDistance) {
        minDistance = d;
        nearest = s;
      }
    }
    return nearest;
  }

  /// Sets the active origin/current station default across the app
  void setCurrentStation(RailwayStation station) {
    _currentStation = station;
    notifyListeners();
  }

  /// Sets the destination station default across the app
  void setDestinationStation(RailwayStation station) {
    _destinationStation = station;
    notifyListeners();
  }

  /// Swaps origin and destination
  void swapStations() {
    final temp = _currentStation;
    _currentStation = _destinationStation;
    _destinationStation = temp;
    notifyListeners();
  }
}
