import '../models/route_option.dart';
import '../models/station.dart';
import 'route_repository.dart';

/// Central Route Recommendation Service powered by LOCO's backend Railway Graph Routing Engine.
class RouteRecommendationService {
  static final RouteRepository _repository = DefaultRouteRepository();

  static Future<List<RouteOption>> getRecommendationsAsync({
    required RailwayStation fromStation,
    required RailwayStation toStation,
    String preference = 'FASTEST',
  }) async {
    return _repository.getRoutes(
      fromStation: fromStation,
      toStation: toStation,
      preference: preference,
    );
  }

  static List<RouteOption> getRecommendations({
    required RailwayStation fromStation,
    required RailwayStation toStation,
  }) {
    return const [];
  }

  Future<List<RouteOption>> getRecommendedRoutesAsync({
    required RailwayStation from,
    required RailwayStation to,
    String preference = 'FASTEST',
  }) async {
    return _repository.getRoutes(
      fromStation: from,
      toStation: to,
      preference: preference,
    );
  }

  List<RouteOption> getRecommendedRoutes({
    required RailwayStation from,
    required RailwayStation to,
  }) {
    return const [];
  }
}
