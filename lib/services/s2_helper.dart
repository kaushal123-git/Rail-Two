import 's2_helper_stub.dart'
    if (dart.library.html) 's2_helper_web.dart'
    if (dart.library.io) 's2_helper_native.dart';

import 'dart:math' as math;

abstract class S2Helper {
  String getCellToken(double lat, double lng);
  String getCellIdString(double lat, double lng);
  double calculateDistance(double lat1, double lng1, double lat2, double lng2);
}

double haversineDistance(double lat1, double lng1, double lat2, double lng2) {
  const double earthRadiusMeters = 6371000.0;
  final double dLat = (lat2 - lat1) * math.pi / 180.0;
  final double dLng = (lng2 - lng1) * math.pi / 180.0;
  final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180.0) *
          math.cos(lat2 * math.pi / 180.0) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

final S2Helper s2Helper = getS2Helper();
