import '../models/assist_models.dart';
import '../services/api_service.dart';

/// Repository for LOCO Assist communications and action confirmations.
class AssistRepository {
  /// Sends a chat message to the LOCO Assist backend API
  Future<AssistMessage> sendChat({
    required String query,
    Map<String, dynamic>? context,
    String? sessionId,
  }) async {
    final responseMap = await ApiService.sendAssistChat(
      query: query,
      context: context,
      sessionId: sessionId,
    );
    return AssistMessage.fromServerResponse(responseMap);
  }

  /// Submits an action confirmation or cancellation to LOCO Assist
  Future<AssistActionConfirmResult> confirmAction({
    required String actionId,
    required String confirmationToken,
    bool confirmed = true,
  }) async {
    final responseMap = await ApiService.confirmAssistAction(
      actionId: actionId,
      confirmationToken: confirmationToken,
      confirmed: confirmed,
    );
    return AssistActionConfirmResult.fromJson(responseMap);
  }

  /// Lists verified tools available in the backend registry
  Future<List<Map<String, dynamic>>> getAvailableTools() async {
    final list = await ApiService.getAssistTools();
    return list.cast<Map<String, dynamic>>();
  }
}
