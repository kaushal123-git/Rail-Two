import 'package:flutter_test/flutter_test.dart';
import 'package:railway_station_finder/models/assist_models.dart';
import 'package:railway_station_finder/services/loco_assist_service.dart';

void main() {
  group('Phase 7: LOCO Assist Service & Model Tests', () {
    test('AssistCardType parses server card type strings correctly', () {
      expect(AssistCardType.fromString('ROUTE_CARD'), equals(AssistCardType.routeCard));
      expect(AssistCardType.fromString('STATION_CARD'), equals(AssistCardType.stationCard));
      expect(AssistCardType.fromString('TICKET_CARD'), equals(AssistCardType.ticketCard));
      expect(AssistCardType.fromString('JOURNEY_CARD'), equals(AssistCardType.journeyCard));
      expect(AssistCardType.fromString('ALERT_CARD'), equals(AssistCardType.alertCard));
      expect(AssistCardType.fromString('CONFIRMATION_CARD'), equals(AssistCardType.confirmationCard));
      expect(AssistCardType.fromString('ERROR_CARD'), equals(AssistCardType.errorCard));
      expect(AssistCardType.fromString('UNKNOWN_XYZ'), equals(AssistCardType.text));
    });

    test('AssistActionPayload parses json parameters correctly', () {
      final payload = AssistActionPayload.fromJson(const {
        'action_type': 'PLAN_JOURNEY',
        'label': 'Plan Route Dadar to Andheri',
        'target_id': 'DDR-ADH',
        'parameters': {
          'origin': 'DDR',
          'destination': 'ADH',
          'preference': 'fastest',
        },
      });

      expect(payload.actionType, equals('PLAN_JOURNEY'));
      expect(payload.label, equals('Plan Route Dadar to Andheri'));
      expect(payload.targetId, equals('DDR-ADH'));
      expect(payload.parameters?['origin'], equals('DDR'));
      expect(payload.parameters?['preference'], equals('fastest'));
    });

    test('AssistMessage parses server structured response with card data', () {
      final serverJson = {
        'request_id': 'req-12345',
        'text': 'The fastest verified route is Dadar → Bandra → Andheri (28 mins).',
        'intent': 'ROUTE_SEARCH',
        'tool_name': 'get_route',
        'card_type': 'ROUTE_CARD',
        'card_data': {
          'origin': 'Dadar',
          'destination': 'Andheri',
          'duration_minutes': 28,
          'transfers': 0,
          'fare': 10.0,
          'stations': ['Dadar', 'Matunga', 'Mahim', 'Bandra', 'Khar Road', 'Santa Cruz', 'Vile Parle', 'Andheri'],
        },
        'quick_replies': ['Book Ticket', 'Fare Details', 'Alternative Routes'],
        'status': 'SUCCESS',
      };

      final msg = AssistMessage.fromServerResponse(serverJson);
      expect(msg.id, equals('req-12345'));
      expect(msg.cardType, equals(AssistCardType.routeCard));
      expect(msg.cardData?['duration_minutes'], equals(28));
      expect(msg.quickReplies.length, equals(3));
      expect(msg.isUser, isFalse);
    });

    test('LocoAssistService provides verified initial messages without hallucinations', () {
      final service = LocoAssistService();
      final initial = service.getInitialMessages();

      expect(initial.isNotEmpty, isTrue);
      expect(initial.first.text, contains('LOCO Assist'));
      expect(initial.first.quickReplies.isNotEmpty, isTrue);
    });

    test('LocoAssistService processQuery provides deterministic offline guidance for booking', () async {
      final service = LocoAssistService();
      final response = await service.processQuery('How do I book a ticket on LOCO?');

      expect(response.text, contains('How to Book Tickets on LOCO'));
      expect(response.isUser, isFalse);
      expect(response.actionPayload?.actionType, equals('BOOK_TICKET'));
    });

    test('LocoAssistService rejects crowd prediction as out of scope', () async {
      final service = LocoAssistService();
      final response = await service.processQuery('Show me crowd predictions');

      expect(response.text, contains('Crowd prediction is not part of the LOCO product scope'));
    });

    test('LocoAssistService processQuery falls back safely without fabricating train delays', () async {
      final service = LocoAssistService();
      final response = await service.processQuery('When is the next fast train to Virar?');

      expect(response.actionPayload?.actionType, equals('PLAN_JOURNEY'));
      // Must not fabricate random train minutes
      expect(response.text, contains('Live railway routing engine is currently unreachable offline'));
    });
  });
}
