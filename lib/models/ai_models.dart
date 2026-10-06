enum AIIntentType {
  trainStatus,
  planRoute,
  getPlatform,
  delayRisk,
  crowdRadar,
  exitNavigation,
  bookTicket,
  renewPass,
  guardianSOS,
  nearbyPOI,
  utsPolicy,
  generalHelp,
}

class AIActionPayload {
  final String actionType; // e.g. "BOOK_TICKET", "ACTIVATE_GUARDIAN", "VIEW_TICKET", "PLAN_JOURNEY"
  final String label;
  final String? targetScreen;
  final Map<String, String>? parameters;

  AIActionPayload({
    required this.actionType,
    required this.label,
    this.targetScreen,
    this.parameters,
  });
}

class RichMediaCardPayload {
  final String title;
  final String subtitle;
  final String category; // "SCHEDULE", "CROWD", "INTERCHANGE", "FOOD", "SECURITY"
  final Map<String, dynamic> data;

  RichMediaCardPayload({
    required this.title,
    required this.subtitle,
    required this.category,
    this.data = const {},
  });
}

class CoachCrowdData {
  final String coachId; // e.g. "C1", "C2", ... "C12"
  final String position; // "South End", "Middle", "North End"
  final int densityPercent; // 0 to 200
  final String crowdLevel; // "Low", "Moderate", "Heavy", "Packed"

  CoachCrowdData({
    required this.coachId,
    required this.position,
    required this.densityPercent,
    required this.crowdLevel,
  });
}

class RailAIMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> quickReplies;
  final String? actionType; // e.g. "VIEW_TICKET", "CHANGE_ROUTE", "EXPLORE_MAP", "PLAN_JOURNEY", "BOOK_TICKET"
  final AIIntentType? intent;
  final AIActionPayload? actionPayload;
  final RichMediaCardPayload? mediaCard;
  final String? cardType; // e.g. "ROUTE_CARD", "STATION_CARD", "TICKET_CARD", "JOURNEY_CARD", "CONFIRMATION_CARD", "ALERT_CARD", "ERROR_CARD"
  final Map<String, dynamic>? cardData;
  final String? toolName;
  final String? status;
  final String? errorCode;

  RailAIMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.quickReplies = const [],
    this.actionType,
    this.intent,
    this.actionPayload,
    this.mediaCard,
    this.cardType,
    this.cardData,
    this.toolName,
    this.status,
    this.errorCode,
  });
}

class DestinationSpot {
  final String id;
  final String name;
  final String category; // Food, Cafe, Culture, Shopping, Attraction
  final String distanceText; // e.g. "350 m away"
  final double rating;
  final String description;
  final String icon;
  final String? stationName;
  final String? exitGate;

  DestinationSpot({
    required this.id,
    required this.name,
    required this.category,
    required this.distanceText,
    required this.rating,
    required this.description,
    required this.icon,
    this.stationName,
    this.exitGate,
  });
}

