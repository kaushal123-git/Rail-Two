import '../models/route_option.dart';
import '../models/station.dart';

class RouteRecommendationService {
  static List<RouteOption> getRecommendations({
    required RailwayStation fromStation,
    required RailwayStation toStation,
  }) {
    final fromName = fromStation.name;
    final toName = toStation.name;

    return [
      RouteOption(
        id: 'opt_fastest',
        title: 'FASTEST',
        badgeText: 'Recommended • 34 min',
        durationMinutes: 34,
        fare: 15,
        trainType: 'Fast Local',
        nextDepartureInMin: 3,
        crowdLevel: 'Moderate',
        transfers: 0,
        description: 'Direct Fast train via $fromName to $toName. Skips minor halts.',
        intermediateStops: [fromName, 'Andheri', 'Bandra', toName],
      ),
      RouteOption(
        id: 'opt_least_crowded',
        title: 'LEAST CROWDED',
        badgeText: 'Comfort Choice',
        durationMinutes: 41,
        fare: 15,
        trainType: 'Slow Local',
        nextDepartureInMin: 7,
        crowdLevel: 'Low',
        transfers: 0,
        description: 'Originating local train with guaranteed seating space.',
        intermediateStops: [fromName, 'Kandivali', 'Malad', 'Goregaon', 'Andheri', 'Bandra', toName],
      ),
      RouteOption(
        id: 'opt_ac_comfort',
        title: 'AC COMFORT',
        badgeText: 'Air Conditioned',
        durationMinutes: 36,
        fare: 65,
        trainType: 'AC EMU Superfast',
        nextDepartureInMin: 12,
        crowdLevel: 'Low',
        transfers: 0,
        description: 'Fully air-conditioned rake with automatic closed doors.',
        intermediateStops: [fromName, 'Andheri', 'Bandra', toName],
      ),
      RouteOption(
        id: 'opt_cheapest',
        title: 'CHEAPEST',
        badgeText: 'Best Value • ₹10',
        durationMinutes: 44,
        fare: 10,
        trainType: 'Ordinary Local',
        nextDepartureInMin: 15,
        crowdLevel: 'High',
        transfers: 0,
        description: 'Standard 2nd Class passenger tariff for budget commute.',
        intermediateStops: [fromName, 'Goregaon', 'Andheri', toName],
      ),
    ];
  }
}
