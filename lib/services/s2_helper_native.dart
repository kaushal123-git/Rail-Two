import 'package:s2geometry/s2geometry.dart';
import 's2_helper.dart';

S2Helper getS2Helper() => S2HelperNative();

class S2HelperNative implements S2Helper {
  @override
  String getCellToken(double lat, double lng) {
    try {
      final latLng = S2LatLng.fromDegrees(lat, lng);
      final cellId = S2CellId.fromLatLng(latLng);
      return cellId.toToken();
    } catch (e) {
      return 'invalid';
    }
  }

  @override
  String getCellIdString(double lat, double lng) {
    try {
      final latLng = S2LatLng.fromDegrees(lat, lng);
      final cellId = S2CellId.fromLatLng(latLng);
      return cellId.id.toString();
    } catch (e) {
      return 'invalid';
    }
  }

  @override
  double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    try {
      final point1 = S2LatLng.fromDegrees(lat1, lng1);
      final point2 = S2LatLng.fromDegrees(lat2, lng2);
      final angle = point1.getDistance(point2);
      return angle.radians * 6371000.0;
    } catch (e) {
      return haversineDistance(lat1, lng1, lat2, lng2);
    }
  }
}
