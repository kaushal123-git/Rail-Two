import 'package:flutter_test/flutter_test.dart';
import 'package:railway_station_finder/models/ai_models.dart';
import 'package:railway_station_finder/services/ai_intent_engine.dart';
import 'package:railway_station_finder/services/live_rail_telemetry_engine.dart';
import 'package:railway_station_finder/services/app_guide_engine.dart';
import 'package:railway_station_finder/services/gemini_rail_service.dart';

void main() {
  group('LIVE AI MODEL INTERACTIVE DEMO', () {
    test('Demonstrating Query 1: Train Timings & Route Deep Link Action', () async {
      final service = GeminiRailService();
      const query = 'Churchgate se Borivali fast train timing kya hai?';
      
      print('\n======================================================');
      print('USER QUERY: "$query"');
      
      final response = await service.processQuery(query);
      print('AI RESPONSE:\n${response.text}');
      print('ATTACHED ACTION: ${response.actionPayload?.actionType} (Label: ${response.actionPayload?.label})');
      print('======================================================\n');

      expect(response.actionPayload?.actionType, equals('PLAN_JOURNEY'));
    });

    test('Demonstrating Query 2: Ticket Booking & Deep Link Action', () async {
      final service = GeminiRailService();
      const query = 'I want to book ticket from Dadar to Thane';

      print('\n======================================================');
      print('USER QUERY: "$query"');

      final response = await service.processQuery(query);
      print('AI RESPONSE:\n${response.text}');
      print('ATTACHED ACTION: ${response.actionPayload?.actionType} (Label: ${response.actionPayload?.label})');
      print('======================================================\n');

      expect(response.actionPayload?.actionType, equals('BOOK_TICKET'));
    });

    test('Demonstrating Query 3: Live Coach Crowd Radar Telemetry', () async {
      final telemetry = LiveRailTelemetryEngine();

      print('\n======================================================');
      print('LIVE TELEMETRY: Dadar Coach Crowd Radar');
      final crowd = telemetry.getCoachCrowdRadar('Dadar', 'Western');
      print(crowd);
      print('======================================================\n');

      expect(crowd, contains('Crowd Radar'));
    });

    test('Demonstrating Query 4: Emergency Safety SOS Deep Link', () async {
      final engine = AIIntentEngine();
      const query = 'Activate guardian mode emergency safety';

      print('\n======================================================');
      print('USER QUERY: "$query"');
      final parsed = engine.parseQuery(query);
      print('PARSED INTENT: ${parsed.intentType}');
      print('SUGGESTED ACTION: ${parsed.suggestedAction?.actionType}');
      print('======================================================\n');

      expect(parsed.intentType, equals(AIIntentType.guardianSOS));
    });
  });
}
