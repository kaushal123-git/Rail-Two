import '../models/ai_models.dart';
import 'journey_guardian_service.dart';
import 'loco_assist_service.dart';

class RailAIService {
  static final RailAIService _instance = RailAIService._internal();
  factory RailAIService() => _instance;
  RailAIService._internal();

  List<RailAIMessage> getInitialMessages() {
    final hasJourney = JourneyGuardianService().hasActiveJourney;
    if (hasJourney) {
      final j = JourneyGuardianService().activeJourney!;
      return [
        RailAIMessage(
          id: '1',
          text: 'Hello! Your journey from ${j.originStation.name} to ${j.destinationStation.name} is active. '
              'Journey Guardian is monitoring track signals and platform updates.',
          isUser: false,
          timestamp: DateTime.now(),
          quickReplies: [
            'Is my train delayed?',
            'What is the next station?',
            "I'm running late",
            'Show my active ticket',
          ],
        ),
      ];
    }

    return LocoAssistService().getInitialMessages();
  }

  Future<RailAIMessage> processQueryAsync(String query) async {
    return await LocoAssistService().processQuery(query);
  }

  RailAIMessage processQuery(String query) {
    return RailAIMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: 'Processing live telemetry...',
      isUser: false,
      timestamp: DateTime.now(),
    );
  }

  static List<DestinationSpot> getRecommendationsForStation(String stationName) {
    final s = stationName.toUpperCase();
    if (s.contains('DADAR')) {
      return [
        DestinationSpot(
          id: 'd1',
          name: 'Aaswad Upahar',
          category: 'Iconic Food',
          distanceText: '250 m from West exit',
          rating: 4.8,
          description: 'Award-winning Maharashtrian Misal Pav & Thalipeeth.',
          icon: '🍲',
        ),
        DestinationSpot(
          id: 'd2',
          name: 'Shivaji Park',
          category: 'Park & Culture',
          distanceText: '900 m away',
          rating: 4.7,
          description: 'Historic cultural park with seaside sea-breeze walks.',
          icon: '🌳',
        ),
        DestinationSpot(
          id: 'd3',
          name: 'Dadar Flower Market',
          category: 'Shopping & Visuals',
          distanceText: '150 m from Flyover',
          rating: 4.6,
          description: 'Largest floral market in Asia with vibrant morning blossoms.',
          icon: '🌸',
        ),
      ];
    } else if (s.contains('BANDRA')) {
      return [
        DestinationSpot(
          id: 'b1',
          name: 'Subko Coffee Roasters',
          category: 'Artisanal Cafe',
          distanceText: '800 m away',
          rating: 4.9,
          description: 'Specialty craft coffees and sourdough baked treats.',
          icon: '☕',
        ),
        DestinationSpot(
          id: 'b2',
          name: 'Bandra Bandstand & Fort',
          category: 'Attraction',
          distanceText: '1.8 km away',
          rating: 4.7,
          description: 'Iconic Arabian sea promontory with stunning sunset panoramas.',
          icon: '🌊',
        ),
        DestinationSpot(
          id: 'b3',
          name: 'Hill Road Shopping',
          category: 'Street Fashion',
          distanceText: '600 m away',
          rating: 4.5,
          description: 'Vibrant street apparel, footwear, and accessory boutiques.',
          icon: '🛍️',
        ),
      ];
    } else {
      return [
        DestinationSpot(
          id: 'gen1',
          name: 'Station Front Market',
          category: 'Quick Bites',
          distanceText: '80 m from platform exit',
          rating: 4.5,
          description: 'Fresh Mumbai cutting chai, samosa, and hot vada pav.',
          icon: '☕',
        ),
        DestinationSpot(
          id: 'gen2',
          name: 'Auto & Cab Stand',
          category: 'Transit Connection',
          distanceText: '30 m from West gate',
          rating: 4.4,
          description: 'Regulated meter autorickshaw and sharing transit stand.',
          icon: '🚖',
        ),
      ];
    }
  }
}
