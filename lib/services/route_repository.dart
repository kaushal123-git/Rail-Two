import 'package:flutter/foundation.dart';
import '../models/route_option.dart';
import '../models/station.dart';
import 'api_service.dart';

/// Clean repository interface for Mumbai Suburban train routes.
abstract class RouteRepository {
  Future<List<RouteOption>> getRoutes({
    required RailwayStation fromStation,
    required RailwayStation toStation,
    String preference = 'FASTEST',
  });
}

/// Production Route Repository communicating with the FastAPI Railway Graph Routing Engine.
class BackendRouteRepository implements RouteRepository {
  static final BackendRouteRepository _instance = BackendRouteRepository._internal();
  factory BackendRouteRepository() => _instance;
  BackendRouteRepository._internal();

  final Map<String, List<RouteOption>> _cache = {};

  @override
  Future<List<RouteOption>> getRoutes({
    required RailwayStation fromStation,
    required RailwayStation toStation,
    String preference = 'FASTEST',
  }) async {
    final originCode = fromStation.code.isNotEmpty ? fromStation.code : fromStation.id;
    final destCode = toStation.code.isNotEmpty ? toStation.code : toStation.id;

    if (originCode.isEmpty || destCode.isEmpty || originCode == destCode) {
      return const [];
    }

    final cacheKey = '$originCode:$destCode:$preference';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final res = await ApiService.searchRoutes(
        originStationId: originCode,
        destinationStationId: destCode,
        preferences: preference,
      );

      if (res['success'] == true && res['data'] != null) {
        final rawRoutes = (res['data']['routes'] as List<dynamic>?) ?? [];
        final routes = rawRoutes
            .map((r) => RouteOption.fromBackendJson(Map<String, dynamic>.from(r as Map)))
            .toList();

        if (routes.isNotEmpty) {
          _cache[cacheKey] = routes;
          return routes;
        }
      }
    } catch (e) {
      debugPrint('Error loading backend routes: $e');
    }

    return const [];
  }

  void clearCache() {
    _cache.clear();
  }
}

/// Default implementation delegating to BackendRouteRepository
class DefaultRouteRepository implements RouteRepository {
  static final DefaultRouteRepository _instance = DefaultRouteRepository._internal();
  factory DefaultRouteRepository() => _instance;
  DefaultRouteRepository._internal();

  final RouteRepository _backendRepo = BackendRouteRepository();

  @override
  Future<List<RouteOption>> getRoutes({
    required RailwayStation fromStation,
    required RailwayStation toStation,
    String preference = 'FASTEST',
  }) {
    return _backendRepo.getRoutes(
      fromStation: fromStation,
      toStation: toStation,
      preference: preference,
    );
  }
}

/// Abstract contract for high-level route resolution and ranking service.
abstract class RoutingService {
  Future<List<RouteOption>> calculateRoutes({
    required String originStationCode,
    required String destinationStationCode,
    DateTime? departureTime,
  });
}

/// Abstract contract for graph-based railway topology and adjacency representation.
abstract class RailwayGraphRepository {
  Future<Map<String, List<String>>> getStationAdjacencyGraph();
  Future<double> getTrackDistanceKm(String stationCodeA, String stationCodeB);
}
