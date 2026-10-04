import 'package:flutter_test/flutter_test.dart';
import 'package:railway_station_finder/models/ai_models.dart';
import 'package:railway_station_finder/services/ai_intent_engine.dart';
import 'package:railway_station_finder/services/live_rail_telemetry_engine.dart';
import 'package:railway_station_finder/services/app_guide_engine.dart';
import 'package:railway_station_finder/services/gemini_rail_service.dart';

void main() {
  group('LOCO AI Model 2.0 Engine Tests', () {
    test('AIIntentEngine parses intent, origin, and destination correctly', () {
      final engine = AIIntentEngine();

      final result1 = engine.parseQuery('Churchgate se Borivali fast train timing kya hai?');
      expect(result1.intentType, equals(AIIntentType.planRoute));
      expect(result1.origin, equals('Churchgate'));
      expect(result1.destination, equals('Borivali'));
      expect(result1.suggestedAction?.actionType, equals('PLAN_JOURNEY'));

      final result2 = engine.parseQuery('Where can I book ticket from Dadar to Thane?');
      expect(result2.intentType, equals(AIIntentType.bookTicket));
      expect(result2.suggestedAction?.actionType, equals('BOOK_TICKET'));

      final result3 = engine.parseQuery('Activate guardian mode emergency safety');
      expect(result3.intentType, equals(AIIntentType.guardianSOS));
      expect(result3.suggestedAction?.actionType, equals('ACTIVATE_GUARDIAN'));

      final result4 = engine.parseQuery('Dadar me train kaise badle interchange help');
      expect(result4.intentType, equals(AIIntentType.exitNavigation));
      expect(result4.station, equals('Dadar'));

      final result5 = engine.parseQuery('Dadar station ke paas kya food aur misal hai?');
      expect(result5.intentType, equals(AIIntentType.nearbyPOI));
    });

    test('LiveRailTelemetryEngine generates live schedules and coach crowd radar', () {
      final telemetry = LiveRailTelemetryEngine();

      final report = telemetry.getLiveScheduleReport(origin: 'Borivali', destination: 'Churchgate');
      expect(report, contains('Live Suburban Rail Telemetry'));
      expect(report, contains('Borivali'));
      expect(report, contains('Churchgate'));

      final crowd = telemetry.getCoachCrowdRadar('Dadar', 'Western');
      expect(crowd, contains('Crowd Radar'));

      final interchange = telemetry.getInterchangeGuide('Dadar');
      expect(interchange, contains('Dadar Master Interchange Guide'));

      final poi = telemetry.getStationPOISpots('Dadar');
      expect(poi.isNotEmpty, isTrue);
      expect(poi.first.name, equals('Aaswad Upahar'));
    });

    test('AppGuideEngine provides feature and ticketing policy guides', () {
      final guide = AppGuideEngine();

      final ticketGuide = guide.getFeatureGuide(AIIntentType.bookTicket, origin: 'Borivali', destination: 'Dadar');
      expect(ticketGuide, contains('How to Book Tickets on LOCO'));

      final passGuide = guide.getFeatureGuide(AIIntentType.renewPass);
      expect(passGuide, contains('Season Ticket (Pass) Guide'));

      final guardianGuide = guide.getFeatureGuide(AIIntentType.guardianSOS);
      expect(guardianGuide, contains('Journey Guardian'));
    });

    test('GeminiRailService processes query and attaches executable AI actions', () async {
      final service = GeminiRailService();

      final msg1 = await service.processQuery('How do I book ticket from Dadar to Borivali?');
      expect(msg1.text, contains('How to Book Tickets on LOCO'));
      expect(msg1.actionPayload?.actionType, equals('BOOK_TICKET'));

      final msg2 = await service.processQuery('Show me food options near Dadar station');
      expect(msg2.text, contains('Station Spotlight near Dadar'));
      expect(msg2.text, contains('Aaswad Upahar'));
    });
  });
}
