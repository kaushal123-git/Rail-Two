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

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

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

    return true;
  }

  /// Set a custom location (e.g., Vasai Road) and persist it
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

  /// Default Vasai Road Position (Vasai Road, Thane/Palghar)
  static final Position defaultVasaiPosition = Position(
    longitude: 72.8325893,
    latitude: 19.3825255,
    timestamp: DateTime.now(),
    accuracy: 1.0,
    altitude: 0.0,
    altitudeAccuracy: 0.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );

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
    return prefs.getString(_keyCustomName) ?? 'Vasai Road';
  }

  /// Retrieves current position (defaults to Vasai Road so Vasai, Naigaon & Nalasopara are suggested)
  static Future<Position> getCurrentLocation() async {
    if (_cachedCustomPosition != null) {
      return _cachedCustomPosition!;
    }

    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_keyCustomLat) && prefs.containsKey(_keyCustomLng)) {
      final lat = prefs.getDouble(_keyCustomLat)!;
      final lng = prefs.getDouble(_keyCustomLng)!;
      _cachedLocationName = prefs.getString(_keyCustomName) ?? 'Vasai Road';
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

    // Default position is Vasai Road to ensure Vasai Road, Naigaon & Nalasopara are offered
    _cachedCustomPosition = defaultVasaiPosition;
    _cachedLocationName = 'Vasai Road';
    return _cachedCustomPosition!;
  }

  /// Force fetch live GPS from device/browser
  static Future<Position> forceFetchDeviceGps() async {
    try {
      final hasPermission = await handleLocationPermission();
      if (hasPermission) {
        final realPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 4),
        );
        _cachedCustomPosition = realPos;
        _cachedLocationName = 'Browser GPS (${realPos.latitude.toStringAsFixed(2)}, ${realPos.longitude.toStringAsFixed(2)})';
        return realPos;
      }
    } catch (e) {
      print('Device GPS fetch failed: $e');
    }
    _cachedCustomPosition = defaultVasaiPosition;
    _cachedLocationName = 'Vasai Road';
    return defaultVasaiPosition;
  }

  /// Returns a stream of position updates to track user movement in real-time.
  static Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update when user moves 10 meters
      ),
    );
  }
}



