import 'dart:async';
import '../models/ai_models.dart';
import 'loco_assist_service.dart';

/// Legacy alias for [LocoAssistService] maintained during Phase 0 migration.
/// Gemini Cloud API calls and simulated telemetry have been removed.
class GeminiRailService {
  static final GeminiRailService _instance = GeminiRailService._internal();
  factory GeminiRailService() => _instance;
  GeminiRailService._internal();

  final LocoAssistService _assistService = LocoAssistService();

  String? get apiKey => null;
  bool get hasCloudGemini => false;

  Future<void> initialize() async {
    await _assistService.initialize();
  }

  Future<void> setApiKey(String key) async {
    // No-op in Phase 0: Gemini Cloud integration removed in favor of LOCO Assist
  }

  List<RailAIMessage> getInitialMessages() {
    return _assistService.getInitialMessages();
  }

  String getHomeBannerInsight() {
    return _assistService.getHomeBannerInsight();
  }

  Future<RailAIMessage> processQuery(String query) async {
    return _assistService.processQuery(query);
  }
}
