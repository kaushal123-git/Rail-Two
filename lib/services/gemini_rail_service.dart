import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_models.dart';
import '../models/station.dart';
import '../simulation/train_simulation_engine.dart';
import 'ai_intent_engine.dart';
import 'app_guide_engine.dart';
import 'live_rail_telemetry_engine.dart';
import 'station_state_service.dart';

/// Next-Generation AI Engine for LOCO & Mumbai Suburban Rail Mobility.
/// Combines a built-in Context-Aware Railway Intelligence Engine with
/// optional direct Google Gemini Cloud LLM integration.
class GeminiRailService {
  static final GeminiRailService _instance = GeminiRailService._internal();
  factory GeminiRailService() => _instance;
  GeminiRailService._internal();

  static const String _prefKeyApiKey = 'loco_gemini_api_key';
  String? _apiKey;

  String? get apiKey => _apiKey;
  bool get hasCloudGemini => _apiKey != null && _apiKey!.trim().isNotEmpty;

  /// Loads stored API key from local preferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _apiKey = prefs.getString(_prefKeyApiKey);
    } catch (e) {
      debugPrint('Error loading Gemini API Key: $e');
    }
  }

  /// Sets or updates the Google Gemini API Key
  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    if (_apiKey!.isEmpty) {
      await prefs.remove(_prefKeyApiKey);
    } else {
      await prefs.setString(_prefKeyApiKey, _apiKey!);
    }
  }

  /// Returns contextual initial greeting for the AI conversation
  List<RailAIMessage> getInitialMessages() {
    final state = StationStateService();
    final from = state.currentStation.name;
    final to = state.destinationStation.name;
    final isPeak = _isPeakHour();

    final greeting = 'Hello! I am LOCOpilot, your intelligent Mumbai Suburban Railway assistant. '
        'Currently tracking departures from $from towards $to. '
        '${isPeak ? "⚠️ Morning/Evening rush hour patterns are active." : "Tracks are flowing smoothly."}';

    return [
      RailAIMessage(
        id: 'initial-1',
        text: greeting,
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: [
          '⚡ Crowd Radar',
          '⏱ Delay Risk',
          '❄️ AC Local Times',
          '🚉 Dadar Interchange Tips',
        ],
      ),
    ];
  }

  /// Generates the smart insight displayed in the LOCOPILOT AI card on the Home Screen
  String getHomeBannerInsight() {
    final state = StationStateService();
    final from = state.currentStation.name;
    final to = state.destinationStation.name;
    final now = DateTime.now();
    final hour = now.hour;

    // Peak morning Southbound
    if (hour >= 8 && hour <= 11) {
      return '"$from fast local at ${_formatTime(now.add(const Duration(minutes: 6)))} has high coach crowd. '
          'Board middle coaches (C6-C8) for quicker interchange at Dadar."';
    }
    // Peak evening Northbound
    else if (hour >= 17 && hour <= 21) {
      return '"$from slow & fast locals experiencing evening rush towards North. '
          'Board rear coaches (C10-C12) for less density and easier exit."';
    }
    // Afternoon / Regular
    else {
      return '"$from fast local at ${_formatTime(now.add(const Duration(minutes: 8)))} has moderate coach crowd. '
          'Board middle coaches (C6-C8) for quicker interchange at $to."';
    }
  }

  /// Processes user query either via Google Gemini API (if key is set)
  /// or through the built-in Mumbai Suburban Intelligence Engine.
  Future<RailAIMessage> processQuery(String query) async {
    final state = StationStateService();
    final from = state.currentStation;
    final to = state.destinationStation;

    // If Cloud Gemini API Key is configured, attempt cloud LLM completion
    if (hasCloudGemini) {
      try {
        final cloudResponse = await _queryGeminiCloud(query, from, to);
        if (cloudResponse != null && cloudResponse.trim().isNotEmpty) {
          return RailAIMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: cloudResponse.trim(),
            isUser: false,
            timestamp: DateTime.now(),
            quickReplies: _getRelevantQuickReplies(query),
          );
        }
      } catch (e) {
        debugPrint('Gemini Cloud query failed, falling back to local intelligence: $e');
      }
    }

    // High-fidelity local Mumbai Rail Intelligence Engine powered by LOCO AI 2.0
    return _processLocalIntelligence(query, from, to);
  }

  /// High-fidelity rule-based and contextual intelligence
  RailAIMessage _processLocalIntelligence(String query, RailwayStation from, RailwayStation to) {
    final parsed = AIIntentEngine().parseQuery(query);
    final intent = parsed.intentType;
    final orig = parsed.origin ?? from.name;
    final dest = parsed.destination ?? to.name;
    final st = parsed.station ?? orig;

    String responseText;
    List<String> quickReplies;
    String? actionType = parsed.suggestedAction?.actionType;
    RichMediaCardPayload? mediaCard;

    switch (intent) {
      case AIIntentType.crowdRadar:
        responseText = LiveRailTelemetryEngine().getCoachCrowdRadar(st, parsed.line);
        quickReplies = ['Check AC Local', 'Delay Risk', 'Next Fast Train', 'Book Ticket'];
        mediaCard = RichMediaCardPayload(
          title: 'Coach Crowd Heatmap ($st)',
          subtitle: 'Live density per coach (C1-C12)',
          category: 'CROWD',
          data: {
            'coaches': LiveRailTelemetryEngine().getCoachCrowdList(st),
          },
        );
        break;

      case AIIntentType.delayRisk:
        responseText = LiveRailTelemetryEngine().getDelayRiskReport(st);
        quickReplies = ['Crowd Radar', 'Show Live Routes', 'AC Local Times'];
        break;

      case AIIntentType.getPlatform:
      case AIIntentType.trainStatus:
      case AIIntentType.planRoute:
        responseText = LiveRailTelemetryEngine().getLiveScheduleReport(origin: orig, destination: dest, line: parsed.line);
        quickReplies = ['⚡ Book Ticket to $dest', '⏱ Delay Risk', '⚡ Crowd Radar', '❄️ AC Local Times'];
        break;

      case AIIntentType.exitNavigation:
        responseText = LiveRailTelemetryEngine().getInterchangeGuide(st);
        quickReplies = ['Food near $st', 'Next train timing', 'Crowd Radar'];
        break;

      case AIIntentType.nearbyPOI:
        final spots = LiveRailTelemetryEngine().getStationPOISpots(st);
        final spotsText = spots.map((s) => '${s.icon} ${s.name} (${s.category})\n   • ${s.description}\n   • Location: ${s.distanceText}').join('\n\n');
        responseText = '📍 Station Spotlight near $st:\n\n$spotsText';
        quickReplies = ['Next train timing', 'Crowd Radar', 'Book Ticket'];
        break;

      case AIIntentType.bookTicket:
      case AIIntentType.renewPass:
      case AIIntentType.guardianSOS:
      case AIIntentType.utsPolicy:
        responseText = AppGuideEngine().getFeatureGuide(intent, origin: orig, destination: dest);
        quickReplies = ['Book Ticket Now', '1-Tap Platform Pass', 'Season Pass Info'];
        break;

      default:
        responseText = 'I analyzed the live suburban schedule from $orig to $dest. '
            'Fast locals run every 4-6 minutes. Take the upcoming Fast local from Platform 2 for the quickest 34-minute ride. '
            'Need specific advice on crowd density, coach positions, or AC trains?';
        quickReplies = ['⚡ Crowd Radar', '⏱ Delay Risk', '❄️ AC Local Times', 'Show Live Routes'];
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
      mediaCard: mediaCard,
    );
  }

  /// Calls Google Gemini REST API using built-in Dart HttpClient
  Future<String?> _queryGeminiCloud(String userPrompt, RailwayStation from, RailwayStation to) async {
    if (_apiKey == null || _apiKey!.isEmpty) return null;

    final client = HttpClient();
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey',
      );

      final systemContext = 'You are LOCOpilot, the ultra-smart AI assistant for the Mumbai Suburban Railway. '
          'You specialize in Western, Central, and Harbour line trains, platform allocation, FOB exits, coach layouts (C1-C15), '
          'peak rush hour patterns, and ticket rules. Keep answers concise, highly practical, and commuter-friendly. '
          'Live Context: Origin: ${from.name} (${from.line} line), Destination: ${to.name} (${to.line} line), Current Time: ${DateTime.now().toIso8601String()}.';

      final requestBody = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': '$systemContext\n\nUser Question: $userPrompt'}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 350,
        }
      });

      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(requestBody);

      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        final candidates = json['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates.first['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            return parts.first['text'] as String?;
          }
        }
      } else {
        debugPrint('Gemini API returned status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error invoking Gemini API: $e');
    } finally {
      client.close();
    }
    return null;
  }

  bool _isPeakHour() {
    final hour = DateTime.now().hour;
    return (hour >= 8 && hour <= 11) || (hour >= 17 && hour <= 21);
  }

  bool _isSouthbound(RailwayStation from, RailwayStation to) {
    return from.latitude > to.latitude;
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  List<String> _getRelevantQuickReplies(String query) {
    return ['⚡ Crowd Radar', '⏱ Delay Risk', '❄️ AC Local Times', 'Show Live Routes'];
  }
}
