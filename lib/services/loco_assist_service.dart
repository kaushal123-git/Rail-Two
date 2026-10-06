import 'dart:async';
import '../models/ai_models.dart';
import '../models/assist_models.dart';
import '../repositories/assist_repository.dart';
import 'ai_intent_engine.dart';
import 'app_guide_engine.dart';
import 'station_state_service.dart';

/// LOCO Assist Service (Phase 7 Application-Aware Intelligent Assistant).
/// Connects the Flutter frontend to LOCO's verified backend tool router,
/// routing engine, ticketing service, and Journey Guardian.
///
/// Principle: UNDERSTAND → TOOL → VERIFY → RESPOND.
/// Hallucinated railway information and fake chatbots are strictly prohibited.
class LocoAssistService {
  static final LocoAssistService _instance = LocoAssistService._internal();
  factory LocoAssistService() => _instance;
  LocoAssistService._internal();

  final AssistRepository _repository = AssistRepository();

  Future<void> initialize() async {
    // Initialized for Phase 7
  }

  /// Initial messages for the LOCO Assist interface
  List<RailAIMessage> getInitialMessages() {
    const greeting = 'Hello! I am LOCO Assist, your intelligent Mumbai Suburban Railway assistant.\n\n'
        'I am directly connected to LOCO routing, live journey verification, tickets, and fare calculators. How can I help you today?';

    return [
      RailAIMessage(
        id: 'loco-assist-init',
        text: greeting,
        isUser: false,
        timestamp: DateTime.now(),
        cardType: 'TEXT',
        quickReplies: const [
          '🚆 Route Dadar to Andheri',
          '🎫 Show my ticket',
          '💵 Fare to Borivali',
          '📋 How to book ticket',
        ],
      ),
    ];
  }

  /// Banner insight for the Home screen card
  String getHomeBannerInsight() {
    return 'LOCO Assist: Ask for verified suburban routes, fares, active tickets, and Journey Guardian safety.';
  }

  /// Processes user query through the backend LOCO Assist tool gateway
  /// with automatic fallback to local deterministic app guide engine if offline.
  Future<RailAIMessage> processQuery(String query, {Map<String, dynamic>? context}) async {
    try {
      final assistMsg = await _repository.sendChat(
        query: query,
        context: context,
      );

      // If backend returned a valid tool result
      if (assistMsg.status != 'NETWORK_ERROR') {
        AIActionPayload? actionPayload;
        String? actionType = assistMsg.actionPayload?.actionType;

        if (assistMsg.actionPayload != null) {
          actionPayload = AIActionPayload(
            actionType: assistMsg.actionPayload!.actionType,
            label: assistMsg.actionPayload!.label,
            parameters: assistMsg.actionPayload!.parameters?.map(
              (k, v) => MapEntry(k, v.toString()),
            ),
          );
        }

        // Map intent string to enum if applicable
        AIIntentType? mappedIntent;
        switch (assistMsg.intent) {
          case 'ROUTE_SEARCH':
          case 'ROUTE_EXPLANATION':
            mappedIntent = AIIntentType.planRoute;
            break;
          case 'BOOKING_GUIDANCE':
            mappedIntent = AIIntentType.bookTicket;
            break;
          case 'APP_HELP':
            mappedIntent = AIIntentType.utsPolicy;
            break;
          case 'SECURITY_HELP':
            mappedIntent = AIIntentType.guardianSOS;
            break;
          default:
            mappedIntent = AIIntentType.generalHelp;
        }

        return RailAIMessage(
          id: assistMsg.id,
          text: assistMsg.text,
          isUser: false,
          timestamp: assistMsg.timestamp,
          quickReplies: assistMsg.quickReplies.isNotEmpty
              ? assistMsg.quickReplies
              : const ['🚆 Route Options', '🎫 View Tickets', '📋 Help'],
          actionType: actionType,
          intent: mappedIntent,
          actionPayload: actionPayload,
          cardType: assistMsg.cardType.toServerString(),
          cardData: assistMsg.cardData,
          toolName: assistMsg.toolName,
          status: assistMsg.status,
          errorCode: assistMsg.errorCode,
        );
      }
    } catch (_) {
      // Network or backend unavailable — fall through to deterministic offline guide
    }

    // Deterministic Offline Fallback (strictly NO hallucinated railway facts)
    return _processOfflineFallback(query);
  }

  /// Confirms or cancels a staged sensitive action (e.g. ticket cancellation)
  Future<AssistActionConfirmResult> confirmAction({
    required String actionId,
    required String confirmationToken,
    bool confirmed = true,
  }) async {
    return _repository.confirmAction(
      actionId: actionId,
      confirmationToken: confirmationToken,
      confirmed: confirmed,
    );
  }

  /// Lists verified tools available in the backend registry
  Future<List<Map<String, dynamic>>> getAvailableTools() async {
    return _repository.getAvailableTools();
  }

  /// Deterministic local fallback when device is offline
  RailAIMessage _processOfflineFallback(String query) {
    final state = StationStateService();
    final from = state.currentStation;
    final to = state.destinationStation;

    final parsed = AIIntentEngine().parseQuery(query);
    final intent = parsed.intentType;
    final orig = parsed.origin ?? from.name;
    final dest = parsed.destination ?? to.name;

    String responseText;
    List<String> quickReplies;
    String? actionType = parsed.suggestedAction?.actionType;
    String cardType = 'TEXT';

    switch (intent) {
      case AIIntentType.bookTicket:
      case AIIntentType.renewPass:
      case AIIntentType.guardianSOS:
      case AIIntentType.utsPolicy:
        responseText = AppGuideEngine().getFeatureGuide(intent, origin: orig, destination: dest);
        quickReplies = const ['Book Ticket Now', 'Season Pass Info', 'UTS Policy'];
        break;

      case AIIntentType.crowdRadar:
        responseText = 'Crowd prediction is not part of the LOCO product scope. You can select routes and book tickets directly.';
        quickReplies = const ['Book Ticket Now', 'UTS Policy'];
        break;

      case AIIntentType.delayRisk:
      case AIIntentType.getPlatform:
      case AIIntentType.trainStatus:
      case AIIntentType.planRoute:
        responseText = 'Live railway routing engine is currently unreachable offline. You can select stations and view cached offline routes.';
        quickReplies = const ['Plan Route', 'UTS Policy'];
        actionType = 'PLAN_JOURNEY';
        break;

      case AIIntentType.exitNavigation:
      case AIIntentType.nearbyPOI:
        responseText = 'Station POI and exit navigation will connect to live station mapping in Phase 4.';
        quickReplies = const ['Plan Route', 'UTS Policy'];
        break;

      default:
        responseText = 'I am LOCO Assist. I can help with verified routes, ticket rules, season passes, and UTS policies.\n\n'
            'Please check your network connection for real-time live routing and ticket verification.';
        quickReplies = const ['🎫 How to Book', '💳 Season Pass Info', '📋 UTS Policy'];
        break;
    }

    return RailAIMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: responseText,
      isUser: false,
      timestamp: DateTime.now(),
      quickReplies: quickReplies,
      actionType: actionType,
      intent: intent,
      actionPayload: parsed.suggestedAction,
      cardType: cardType,
    );
  }
}
