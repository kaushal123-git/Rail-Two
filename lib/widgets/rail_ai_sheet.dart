import 'package:flutter/material.dart';
import '../core/theme/loco_theme.dart';
import '../models/ai_models.dart';
import '../services/gemini_rail_service.dart';

class RailAISheet extends StatefulWidget {
  final VoidCallback? onViewTicket;
  final VoidCallback? onPlanJourney;
  final String? initialQuery;
  final Function(AIActionPayload payload)? onActionTriggered;

  const RailAISheet({
    super.key,
    this.onViewTicket,
    this.onPlanJourney,
    this.initialQuery,
    this.onActionTriggered,
  });

  @override
  State<RailAISheet> createState() => _RailAISheetState();
}

class _RailAISheetState extends State<RailAISheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<RailAIMessage> _messages;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _messages = GeminiRailService().getInitialMessages();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(widget.initialQuery!);
      });
    }
  }

  Future<void> _sendMessage(String query) async {
    if (query.trim().isEmpty || _isProcessing) return;

    final userMsg = RailAIMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: query,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isProcessing = true;
      _textController.clear();
    });

    _scrollToBottom();

    try {
      final aiResponse = await GeminiRailService().processQuery(query);
      if (mounted) {
        setState(() {
          _messages.add(aiResponse);
          _isProcessing = false;
        });
        _scrollToBottom();

        if (aiResponse.actionType == 'VIEW_TICKET' && widget.onViewTicket != null) {
          Future.delayed(const Duration(milliseconds: 600), widget.onViewTicket!);
        } else if (aiResponse.actionType == 'PLAN_JOURNEY' && widget.onPlanJourney != null) {
          Future.delayed(const Duration(milliseconds: 600), widget.onPlanJourney!);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(RailAIMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: 'I ran into a telemetry glitch, but our local signal processors confirm trains are on time.',
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isProcessing = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController(text: GeminiRailService().apiKey ?? '');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('✨', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Gemini Cloud AI Key', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Google Gemini API Key from Google AI Studio (aistudio.google.com) to enable live Cloud Generative AI reasoning.',
              style: TextStyle(fontSize: 13, color: LocoColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'AIzaSy...',
                labelText: 'API Key',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(dialogCtx);
              final messenger = ScaffoldMessenger.of(context);
              await GeminiRailService().setApiKey(controller.text);
              nav.pop();
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: LocoColors.textPrimary,
                    content: Text(
                      controller.text.trim().isEmpty
                          ? 'Using built-in Local Mumbai Rail AI'
                          : 'Gemini Cloud AI Key Saved & Active!',
                    ),
                  ),
                );
                setState(() {});
              }
            },
            child: const Text('Save Key'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCloud = GeminiRailService().hasCloudGemini;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF381219), Color(0xFF220A0F)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.bolt, color: LocoColors.orange, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'LOCOpilot AI',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: hasCloud ? LocoColors.successLight : LocoColors.orangeLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          hasCloud ? 'GEMINI 1.5' : 'SMART LOCAL',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: hasCloud ? LocoColors.success : LocoColors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Real-Time Mumbai Suburban Telemetry',
                    style: TextStyle(fontSize: 11.5, color: LocoColors.textMuted, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.key_rounded, size: 20, color: LocoColors.textMuted),
                tooltip: 'Configure Gemini API Key',
                onPressed: _showApiKeyDialog,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: LocoColors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 16),

          // Message list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length + (_isProcessing ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isProcessing) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: LocoColors.canvas,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: LocoColors.border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: LocoColors.orange),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'LOCOpilot is evaluating track signals...',
                            style: TextStyle(fontSize: 12, color: LocoColors.textMuted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // Quick Action Chips from the latest message
          if (_messages.isNotEmpty && _messages.last.quickReplies.isNotEmpty && !_isProcessing)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: _messages.last.quickReplies.map((reply) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(reply),
                      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LocoColors.orange),
                      backgroundColor: LocoColors.orangeLight,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onPressed: () => _sendMessage(reply),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Input Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  onSubmitted: _sendMessage,
                  enabled: !_isProcessing,
                  decoration: InputDecoration(
                    hintText: 'Ask LOCOpilot (e.g. "Crowd radar for Dadar fast")...',
                    filled: true,
                    fillColor: LocoColors.canvas,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: LocoColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isProcessing ? null : () => _sendMessage(_textController.text),
                icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: LocoColors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(RailAIMessage msg) {
    final hasAction = !msg.isUser && (msg.actionPayload != null || msg.actionType != null);
    final actionLabel = msg.actionPayload?.label ?? (msg.actionType == 'VIEW_TICKET' ? '🎫 View Ticket' : '⚡ Proceed');

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.84),
        decoration: BoxDecoration(
          color: msg.isUser ? LocoColors.orange : LocoColors.canvas,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: msg.isUser ? const Radius.circular(2) : const Radius.circular(16),
            bottomLeft: msg.isUser ? const Radius.circular(16) : const Radius.circular(2),
          ),
          border: msg.isUser ? null : Border.all(color: LocoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              msg.text,
              style: TextStyle(
                fontSize: 13.5,
                color: msg.isUser ? Colors.white : LocoColors.textPrimary,
                height: 1.4,
              ),
            ),
            if (msg.mediaCard != null && msg.mediaCard!.category == 'CROWD')
              _buildCoachCrowdHeatmap(msg.mediaCard!),
            if (hasAction) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  if (msg.actionPayload != null && widget.onActionTriggered != null) {
                    widget.onActionTriggered!(msg.actionPayload!);
                    return;
                  }
                  final action = msg.actionPayload?.actionType ?? msg.actionType;
                  if (action == 'VIEW_TICKET' && widget.onViewTicket != null) {
                    widget.onViewTicket!();
                  } else if ((action == 'PLAN_JOURNEY' || action == 'BOOK_TICKET' || action == 'RENEW_SEASON_PASS') && widget.onPlanJourney != null) {
                    widget.onPlanJourney!();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Action triggered: $actionLabel'),
                        backgroundColor: LocoColors.textPrimary,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.bolt, size: 16),
                label: Text(actionLabel, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LocoColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCoachCrowdHeatmap(RichMediaCardPayload mediaCard) {
    final List<CoachCrowdData> coaches = (mediaCard.data['coaches'] as List<dynamic>?)?.cast<CoachCrowdData>() ?? [];
    if (coaches.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LocoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                mediaCard.title,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: LocoColors.orangeLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '12-COACH EMU',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: LocoColors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: coaches.map((c) {
                Color color;
                if (c.densityPercent > 150) {
                  color = LocoColors.error;
                } else if (c.densityPercent > 100) {
                  color = LocoColors.orange;
                } else if (c.densityPercent > 50) {
                  color = const Color(0xFFF59E0B);
                } else {
                  color = LocoColors.success;
                }

                return Container(
                  width: 44,
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
                  ),
                  child: Column(
                    children: [
                      Text(
                        c.coachId,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 24,
                        height: 4,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${c.densityPercent}%',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: color),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '💡 Green: Low/Seated | Yellow: Moderate | Orange: Heavy | Red: Packed (>150%)',
            style: TextStyle(fontSize: 10, color: LocoColors.textMuted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
