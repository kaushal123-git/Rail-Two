import 's2_helper.dart';

S2Helper getS2Helper() => S2HelperWeb();

class S2HelperWeb implements S2Helper {
  @override
  String getCellToken(double lat, double lng) {
    // Generate a pseudo-S2 token deterministically for UI display on Web
    final latInt = (lat * 100000).abs().toInt();
    final lngInt = (lng * 100000).abs().toInt();
    final hash = (latInt ^ lngInt).toRadixString(16);
    return hash.padLeft(8, '0').substring(0, 8);
  }

  @override
  String getCellIdString(double lat, double lng) {
    // Generate a pseudo-S2 numeric ID deterministically for UI display on Web
    final latInt = (lat * 100000).abs().toInt();
    final lngInt = (lng * 100000).abs().toInt();
    final pseudoId = (latInt * 1000000 + lngInt).toString();
    return pseudoId.padRight(19, '0').substring(0, 19);
  }

  @override
  double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return haversineDistance(lat1, lng1, lat2, lng2);
  }
}
