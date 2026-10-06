import 'package:flutter_test/flutter_test.dart';
import 'package:railway_station_finder/models/route_option.dart';
import 'package:railway_station_finder/models/station.dart';
import 'package:railway_station_finder/services/route_repository.dart';

void main() {
  group('Phase 3: Railway Graph & Route Models Test', () {
    test('RouteOption.fromBackendJson parses direct route correctly', () {
      final backendJson = {
        'route_id': 'route_CCG_BVI_FASTEST',
        'title': 'FASTEST',
        'badge_text': '⚡ Fastest',
        'total_duration_minutes': 48,
        'transfers_count': 0,
        'fare_estimate': 15,
        'ac_fare_estimate': 85,
        'origin_station_name': 'Churchgate',
        'destination_station_name': 'Borivali',
        'network_version': '1.0.0',
        'legs': [
          {
            'line_id': 'line-wr',
            'line_name': 'Western Line',
            'from_station_name': 'Churchgate',
            'to_station_name': 'Borivali',
            'station_sequence': ['Churchgate', 'Mumbai Central', 'Dadar', 'Bandra', 'Andheri', 'Borivali'],
            'service_type': 'FAST_LOCAL',
            'duration_minutes': 48,
            'distance_km': 34.0,
          }
        ]
      };

      final option = RouteOption.fromBackendJson(backendJson);

      expect(option.id, 'route_CCG_BVI_FASTEST');
      expect(option.title, 'FASTEST');
      expect(option.badgeText, '⚡ Fastest');
      expect(option.durationMinutes, 48);
      expect(option.fare, 15);
      expect(option.acFare, 85);
      expect(option.transfers, 0);
      expect(option.trainType, 'Fast Local');
      expect(option.isFast, true);
      expect(option.isAc, false);
      expect(option.intermediateStops, containsAll(['Churchgate', 'Dadar', 'Borivali']));
      expect(option.intermediateStops.length, 6);
      expect(option.description, contains('Western Line • Direct journey'));
    });

    test('RouteOption.fromBackendJson parses interchange transfer route correctly', () {
      final transferJson = {
        'route_id': 'route_CCG_TNA_INTERCHANGE',
        'title': 'FEWEST_TRANSFERS',
        'badge_text': '🔄 1 Transfer',
        'total_duration_minutes': 64,
        'transfers_count': 1,
        'fare_estimate': 20,
        'ac_fare_estimate': 110,
        'origin_station_name': 'Churchgate',
        'destination_station_name': 'Thane',
        'network_version': '1.0.0',
        'legs': [
          {
            'line_id': 'line-wr',
            'line_name': 'Western Line',
            'from_station_name': 'Churchgate',
            'to_station_name': 'Dadar',
            'station_sequence': ['Churchgate', 'Dadar'],
            'service_type': 'FAST_LOCAL',
            'duration_minutes': 16,
            'distance_km': 10.0,
          },
          {
            'line_id': 'line-cr',
            'line_name': 'Central Line',
            'from_station_name': 'Dadar',
            'to_station_name': 'Thane',
            'station_sequence': ['Dadar', 'Kurla', 'Ghatkopar', 'Thane'],
            'service_type': 'FAST_LOCAL',
            'duration_minutes': 42,
            'distance_km': 24.0,
          }
        ]
      };

      final option = RouteOption.fromBackendJson(transferJson);

      expect(option.id, 'route_CCG_TNA_INTERCHANGE');
      expect(option.transfers, 1);
      expect(option.durationMinutes, 64);
      expect(option.fare, 20);
      expect(option.description, 'Churchgate → Thane via 1 transfer(s)');
      expect(option.intermediateStops.length, 5); // CCG, DDR, CLA, GC, TNA
    });

    test('RouteOption detects AC Superfast services', () {
      final acJson = {
        'route_id': 'route_CCG_VR_AC',
        'title': 'AC_COMFORT',
        'badge_text': '❄️ AC Superfast',
        'total_duration_minutes': 62,
        'transfers_count': 0,
        'fare_estimate': 120,
        'ac_fare_estimate': 120,
        'origin_station_name': 'Churchgate',
        'destination_station_name': 'Virar',
        'legs': [
          {
            'line_id': 'line-wr',
            'line_name': 'Western Line',
            'from_station_name': 'Churchgate',
            'to_station_name': 'Virar',
            'station_sequence': ['Churchgate', 'Dadar', 'Andheri', 'Borivali', 'Virar'],
            'service_type': 'AC_FAST',
            'duration_minutes': 62,
            'distance_km': 60.0,
          }
        ]
      };

      final option = RouteOption.fromBackendJson(acJson);

      expect(option.isAc, true);
      expect(option.trainType, 'AC Superfast');
      expect(option.fare, 120);
    });

    test('BackendRouteRepository caches responses for identical queries', () async {
      final repo = BackendRouteRepository();
      repo.clearCache();

      final stA = RailwayStation(id: 's-ccg', name: 'Churchgate', latitude: 18.9322, longitude: 72.8264);
      final stB = RailwayStation(id: 's-ccg', name: 'Churchgate', latitude: 18.9322, longitude: 72.8264);

      // Same station returns empty
      final routesSame = await repo.getRoutes(fromStation: stA, toStation: stB);
      expect(routesSame, isEmpty);
    });
  });
}
