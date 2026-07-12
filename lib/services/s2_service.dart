import 's2_helper.dart';

class S2Service {
  /// Converts latitude and longitude to an S2 cell token (hex representation).
  static String getCellToken(double lat, double lng) {
    return s2Helper.getCellToken(lat, lng);
  }

  /// Converts latitude and longitude to a 64-bit integer S2 cell ID.
  static String getCellIdString(double lat, double lng) {
    return s2Helper.getCellIdString(lat, lng);
  }

  /// Calculates the spherical distance in meters between two coordinates.
  static double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return s2Helper.calculateDistance(lat1, lng1, lat2, lng2);
  }
}

