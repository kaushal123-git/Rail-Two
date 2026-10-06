import 'package:flutter/foundation.dart';

/// Structured card types rendered by the LOCO Assist interface.
enum AssistCardType {
  text,
  routeCard,
  stationCard,
  ticketCard,
  journeyCard,
  alertCard,
  confirmationCard,
  errorCard;

  static AssistCardType fromString(String? type) {
    switch (type?.toUpperCase()) {
      case 'ROUTE_CARD':
        return AssistCardType.routeCard;
      case 'STATION_CARD':
        return AssistCardType.stationCard;
      case 'TICKET_CARD':
        return AssistCardType.ticketCard;
      case 'JOURNEY_CARD':
        return AssistCardType.journeyCard;
      case 'ALERT_CARD':
        return AssistCardType.alertCard;
      case 'CONFIRMATION_CARD':
        return AssistCardType.confirmationCard;
      case 'ERROR_CARD':
        return AssistCardType.errorCard;
      default:
        return AssistCardType.text;
    }
  }

  String toServerString() {
    switch (this) {
      case AssistCardType.routeCard:
        return 'ROUTE_CARD';
      case AssistCardType.stationCard:
        return 'STATION_CARD';
      case AssistCardType.ticketCard:
        return 'TICKET_CARD';
      case AssistCardType.journeyCard:
        return 'JOURNEY_CARD';
      case AssistCardType.alertCard:
        return 'ALERT_CARD';
      case AssistCardType.confirmationCard:
        return 'CONFIRMATION_CARD';
      case AssistCardType.errorCard:
        return 'ERROR_CARD';
      case AssistCardType.text:
        return 'TEXT';
    }
  }
}

/// UI state machine for LOCO Assist conversation sheet
enum AssistUIState {
  idle,
  thinking,
  callingTool,
  showingResult,
  actionConfirmation,
  error,
  authRequired,
}

/// Action payload attached to LOCO Assist tool result (e.g. Plan Route, View Ticket)
@immutable
class AssistActionPayload {
  final String actionType;
  final String label;
  final String? targetId;
  final Map<String, dynamic>? parameters;

  const AssistActionPayload({
    required this.actionType,
    required this.label,
    this.targetId,
    this.parameters,
  });

  factory AssistActionPayload.fromJson(Map<String, dynamic> json) {
    return AssistActionPayload(
      actionType: json['action_type'] as String? ?? 'GENERAL',
      label: json['label'] as String? ?? 'View Details',
      targetId: json['target_id'] as String?,
      parameters: json['parameters'] != null
          ? Map<String, dynamic>.from(json['parameters'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action_type': actionType,
      'label': label,
      if (targetId != null) 'target_id': targetId,
      if (parameters != null) 'parameters': parameters,
    };
  }
}

/// Encapsulates verified backend tool result metadata
@immutable
class AssistToolResult {
  final String? toolName;
  final String? intent;
  final AssistCardType cardType;
  final Map<String, dynamic> cardData;
  final AssistActionPayload? actionPayload;

  const AssistToolResult({
    this.toolName,
    this.intent,
    required this.cardType,
    this.cardData = const {},
    this.actionPayload,
  });

  factory AssistToolResult.fromJson(Map<String, dynamic> json) {
    return AssistToolResult(
      toolName: json['tool_name'] as String?,
      intent: json['intent'] as String?,
      cardType: AssistCardType.fromString(json['card_type'] as String?),
      cardData: json['card_data'] != null
          ? Map<String, dynamic>.from(json['card_data'] as Map)
          : const {},
      actionPayload: json['action_payload'] != null
          ? AssistActionPayload.fromJson(
              Map<String, dynamic>.from(json['action_payload'] as Map))
          : null,
    );
  }
}

/// Unified chat message for LOCO Assist with structured card presentation
class AssistMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? intent;
  final String? toolName;
  final AssistCardType cardType;
  final Map<String, dynamic>? cardData;
  final AssistActionPayload? actionPayload;
  final List<String> quickReplies;
  final String? status;
  final String? errorCode;

  AssistMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.intent,
    this.toolName,
    this.cardType = AssistCardType.text,
    this.cardData,
    this.actionPayload,
    this.quickReplies = const [],
    this.status,
    this.errorCode,
  });

  factory AssistMessage.fromServerResponse(Map<String, dynamic> json) {
    return AssistMessage(
      id: json['request_id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      text: json['text'] as String? ?? '',
      isUser: false,
      timestamp: DateTime.now(),
      intent: json['intent'] as String?,
      toolName: json['tool_name'] as String?,
      cardType: AssistCardType.fromString(json['card_type'] as String?),
      cardData: json['card_data'] != null
          ? Map<String, dynamic>.from(json['card_data'] as Map)
          : null,
      actionPayload: json['action_payload'] != null
          ? AssistActionPayload.fromJson(
              Map<String, dynamic>.from(json['action_payload'] as Map))
          : null,
      quickReplies: json['quick_replies'] != null
          ? List<String>.from(json['quick_replies'] as List)
          : const [],
      status: json['status'] as String?,
      errorCode: json['error_code'] as String?,
    );
  }

  factory AssistMessage.user(String text) {
    return AssistMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  factory AssistMessage.error(String text, {String? code}) {
    return AssistMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      cardType: AssistCardType.errorCard,
      errorCode: code,
      quickReplies: const ['How to Book', 'Ticket Rules', 'Help'],
    );
  }
}

/// Response from confirmation endpoint (/api/v1/assist/actions/confirm)
@immutable
class AssistActionConfirmResult {
  final bool success;
  final String actionType;
  final String status;
  final String message;
  final Map<String, dynamic> details;

  const AssistActionConfirmResult({
    required this.success,
    required this.actionType,
    required this.status,
    required this.message,
    this.details = const {},
  });

  factory AssistActionConfirmResult.fromJson(Map<String, dynamic> json) {
    return AssistActionConfirmResult(
      success: json['success'] as bool? ?? false,
      actionType: json['action_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      message: json['message'] as String? ?? '',
      details: json['details'] != null
          ? Map<String, dynamic>.from(json['details'] as Map)
          : const {},
    );
  }
}
