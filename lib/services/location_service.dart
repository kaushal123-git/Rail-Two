import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static const String _keyCustomLat = 'custom_location_lat';
  static const String _keyCustomLng = 'custom_location_lng';
  static const String _keyCustomName = 'custom_location_name';

  static Position? _cachedCustomPosition;
  static String? _cachedLocationName;

  /// Returns current location permission status
  static Future<LocationPermission> getLocationPermissionStatus() async {
    return await Geolocator.checkPermission();
  }

  /// Forces requesting location permission from the browser/OS
  static Future<LocationPermission> requestLocationPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Checks if location services are enabled and if permission is granted.
  /// Requests permission if it hasn't been granted yet.
  static Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && !kIsWeb) {
        return false;
      }
    } catch (_) {
      // On web, isLocationServiceEnabled can throw or be unsupported
    }

    try {
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  /// Set a custom location (e.g., Virar, Dadar) and persist it
  static Future<void> setCustomLocation(double lat, double lng, {String? name}) async {
    _cachedCustomPosition = Position(
      longitude: lng,
      latitude: lat,
      timestamp: DateTime.now(),
      accuracy: 1.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
    _cachedLocationName = name;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyCustomLat, lat);
    await prefs.setDouble(_keyCustomLng, lng);
    if (name != null) {
      await prefs.setString(_keyCustomName, name);
    } else {
      await prefs.remove(_keyCustomName);
    }
  }

  /// Clear custom location override & revert to real device GPS
  static Future<void> clearCustomLocation() async {
    _cachedCustomPosition = null;
    _cachedLocationName = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCustomLat);
    await prefs.remove(_keyCustomLng);
    await prefs.remove(_keyCustomName);
  }

  /// Default Virar Position (Virar Western Railway, Palghar/Mumbai Suburban)
  static final Position defaultVirarPosition = Position(
    longitude: 72.811989,
    latitude: 19.454787,
    timestamp: DateTime.now(),
    accuracy: 5.0,
    altitude: 0.0,
    altitudeAccuracy: 0.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );

  /// Backward-compatible alias
  static Position get defaultVasaiPosition => defaultVirarPosition;

  /// Check if custom location override is active
  static Future<bool> isCustomOverrideActive() async {
    if (_cachedCustomPosition != null && _cachedLocationName != null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyCustomLat) && prefs.containsKey(_keyCustomLng);
  }

  /// Get active custom location name if set
  static Future<String?> getCustomLocationName() async {
    if (_cachedLocationName != null) return _cachedLocationName;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCustomName) ?? 'Virar';
  }

  /// Retrieves current position from real browser/device GPS.
  /// Falls back to default Virar position only if GPS is disabled or permission denied.
  static Future<Position> getCurrentLocation({bool forceRealGps = false}) async {
    // 1. If not forcing real GPS, check custom override in memory or SharedPreferences
    if (!forceRealGps) {
      if (_cachedCustomPosition != null) {
        return _cachedCustomPosition!;
      }

      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_keyCustomLat) && prefs.containsKey(_keyCustomLng)) {
        final lat = prefs.getDouble(_keyCustomLat)!;
        final lng = prefs.getDouble(_keyCustomLng)!;
        _cachedLocationName = prefs.getString(_keyCustomName) ?? 'Selected Location';
        _cachedCustomPosition = Position(
          longitude: lng,
          latitude: lat,
          timestamp: DateTime.now(),
          accuracy: 1.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
        return _cachedCustomPosition!;
      }
    }

    // 2. Query real device / browser GPS
    try {
      final hasPermission = await handleLocationPermission();
      if (hasPermission) {
        final realPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 6),
        );
        _cachedCustomPosition = realPos;
        _cachedLocationName =
            'Live GPS (${realPos.latitude.toStringAsFixed(3)}, ${realPos.longitude.toStringAsFixed(3)})';
        return realPos;
      }
    } catch (e) {
      debugPrint('Real GPS fetch error: $e');
    }

    // 3. Fallback position is Virar (default terminal station)
    _cachedCustomPosition = defaultVirarPosition;
    _cachedLocationName = 'Virar (Default)';
    return _cachedCustomPosition!;
  }

  /// Force fetch live GPS from device/browser
  static Future<Position> forceFetchDeviceGps() async {
    await clearCustomLocation();
    return getCurrentLocation(forceRealGps: true);
  }

  /// Returns location evidence dictionary suitable for Phase 4 API requests
  static Future<Map<String, dynamic>> getLocationEvidence() async {
    final pos = await getCurrentLocation();
    return {
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'accuracy_meters': pos.accuracy,
      'altitude': pos.altitude,
      'speed_mps': pos.speed,
      'bearing': pos.heading,
      'timestamp_device': pos.timestamp.toUtc().toIso8601String(),
      'provider': 'gps',
      'is_mock': pos.isMocked,
      'mock_confidence': pos.isMocked ? 1.0 : 0.0,
    };
  }

  /// Returns a stream of position updates to track user movement in real-time.
  static Stream<Position> getLocationStream({int distanceFilter = 15}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter, // Update when user moves configured meters
      ),
    );
  }
}

/// Abstract contract for device location fetching.
abstract class LocationRepository {
  Future<Position> getCurrentPosition();
  Stream<Position> getPositionStream();
}

/// Abstract contract for server-side geofence and location validation.
abstract class LocationValidationService {
  Future<bool> validateLocation({
    required double latitude,
    required double longitude,
    required String stationId,
  });
}

/// Abstract contract for station geofence boundary verification.
abstract class GeofenceService {
  Future<bool> isInsideGeofence({
    required double userLat,
    required double userLng,
    required double stationLat,
    required double stationLng,
    double radiusMeters = 300.0,
  });
}
