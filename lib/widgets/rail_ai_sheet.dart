import 'package:flutter/material.dart';
import '../core/theme/loco_theme.dart';
import '../models/ai_models.dart';
import '../services/loco_assist_service.dart';

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
    _messages = LocoAssistService().getInitialMessages();
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
      final aiResponse = await LocoAssistService().processQuery(query);
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
            text: "I can't verify that information right now. Please check your network or try again.",
            isUser: false,
            timestamp: DateTime.now(),
            cardType: 'ERROR_CARD',
          ));
          _isProcessing = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _handleActionConfirmation({
    required String actionId,
    required String confirmationToken,
    required bool confirmed,
  }) async {
    setState(() => _isProcessing = true);
    try {
      final res = await LocoAssistService().confirmAction(
        actionId: actionId,
        confirmationToken: confirmationToken,
        confirmed: confirmed,
      );
      if (mounted) {
        setState(() {
          _messages.add(RailAIMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: res.message,
            isUser: false,
            timestamp: DateTime.now(),
            cardType: res.success ? 'TEXT' : 'ERROR_CARD',
            quickReplies: const ['🎫 View My Tickets', '🚆 Plan Route', '📋 Help'],
          ));
          _isProcessing = false;
        });
        _scrollToBottom();

        if (confirmed && res.success && widget.onViewTicket != null) {
          Future.delayed(const Duration(milliseconds: 1000), widget.onViewTicket!);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add(RailAIMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: 'Action could not be executed at this time. Please check your ticket status under My Tickets.',
            isUser: false,
            timestamp: DateTime.now(),
            cardType: 'ERROR_CARD',
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

  @override
  Widget build(BuildContext context) {
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'LOCO Assist',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                      ),
                      SizedBox(width: 6),
                      Text('• Railway Assistant', style: TextStyle(fontSize: 12, color: LocoColors.orange, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  Text(
                    'Verified Railway & Journey Control',
                    style: TextStyle(fontSize: 11.5, color: LocoColors.textMuted, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const Spacer(),
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
                            'LOCO Assist is calling verified railway tools...',
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

          // Quick Action Chips from latest message
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
                    hintText: 'Ask LOCO Assist (e.g. "Route Dadar to Borivali")...',
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
    final cardType = msg.cardType?.toUpperCase() ?? 'TEXT';
    final cardData = msg.cardData;
    final hasAction = !msg.isUser && (msg.actionPayload != null || msg.actionType != null);
    final actionLabel = msg.actionPayload?.label ?? (msg.actionType == 'VIEW_TICKET' ? '🎫 View Ticket' : '⚡ Proceed');

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
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

            // Rich Card Embeddings
            if (!msg.isUser && cardData != null) ...[
              const SizedBox(height: 8),
              if (cardType == 'ROUTE_CARD') _buildRouteCard(cardData),
              if (cardType == 'TICKET_CARD') _buildTicketCard(cardData),
              if (cardType == 'JOURNEY_CARD') _buildJourneyCard(cardData),
              if (cardType == 'STATION_CARD') _buildStationCard(cardData),
              if (cardType == 'CONFIRMATION_CARD') _buildConfirmationCard(cardData),
              if (cardType == 'ALERT_CARD') _buildAlertCard(cardData),
            ],

            // Action Button (if not already handled inside cards)
            if (hasAction && cardType != 'CONFIRMATION_CARD') ...[
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
                        content: Text('Action: $actionLabel'),
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

  // ================= RICH CARD RENDERERS =================

  Widget _buildRouteCard(Map<String, dynamic> data) {
    final origin = data['origin'] ?? 'Origin';
    final dest = data['destination'] ?? 'Destination';
    final duration = data['duration_minutes'] ?? 0;
    final transfers = data['transfers'] ?? 0;
    final fare = data['fare'] ?? 0.0;
    final stations = (data['stations'] as List<dynamic>?)?.cast<String>() ?? [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LocoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.train_rounded, color: LocoColors.orange, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$origin → $dest',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: LocoColors.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: LocoColors.orangeLight, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  '₹${fare.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: LocoColors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('⏱️ ${duration}m', style: const TextStyle(fontSize: 11.5, color: LocoColors.textMuted)),
              const SizedBox(width: 10),
              Text(transfers == 0 ? '🟢 Direct' : '🔄 $transfers transfer(s)', style: const TextStyle(fontSize: 11.5, color: LocoColors.textMuted)),
              const Spacer(),
              const Text('Verified Route', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green)),
            ],
          ),
          if (stations.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              stations.take(4).join(' → ') + (stations.length > 4 ? ' ...' : ''),
              style: const TextStyle(fontSize: 11, color: LocoColors.textMuted, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> data) {
    final ticketId = (data['ticket_id'] ?? '').toString();
    final origin = data['origin'] ?? 'Origin';
    final dest = data['destination'] ?? 'Destination';
    final status = data['status'] ?? 'ISSUED';
    final fare = data['fare'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LocoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded, color: LocoColors.orange, size: 20),
              const SizedBox(width: 6),
              Text(
                'Ticket #${ticketId.length > 8 ? ticketId.substring(0, 8).toUpperCase() : ticketId}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: LocoColors.textPrimary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: status == 'ACTIVE' || status == 'ISSUED' ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: status == 'ACTIVE' || status == 'ISSUED' ? Colors.green.shade700 : LocoColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('$origin → $dest', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Fare: ₹${(fare as num).toStringAsFixed(0)} • Authorized Server Ticket', style: const TextStyle(fontSize: 11, color: LocoColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildJourneyCard(Map<String, dynamic> data) {
    final current = data['current_station'] ?? 'In Transit';
    final dest = data['destination'] ?? 'Destination';
    final remaining = data['stations_remaining'] ?? 0;
    final secStatus = data['security_status'] ?? 'NORMAL';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LocoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, color: Colors.green, size: 18),
              const SizedBox(width: 6),
              const Text('Journey Guardian Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Text('Security: $secStatus', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Near: $current  →  Destination: $dest', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text('Remaining Stations: $remaining', style: const TextStyle(fontSize: 11.5, color: LocoColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildStationCard(Map<String, dynamic> data) {
    final name = data['name'] ?? 'Station';
    final code = data['code'] ?? '';
    final lines = (data['lines'] as List<dynamic>?)?.cast<String>() ?? [];
    final facilities = (data['facilities'] as List<dynamic>?)?.cast<String>() ?? [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LocoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.apartment_rounded, color: LocoColors.orange, size: 18),
              const SizedBox(width: 6),
              Text('$name ($code)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Serving Lines: ${lines.join(', ')}', style: const TextStyle(fontSize: 11.5, color: LocoColors.textMuted)),
          ],
          if (facilities.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Facilities: ${facilities.join(' • ')}', style: const TextStyle(fontSize: 11, color: LocoColors.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmationCard(Map<String, dynamic> data) {
    final actionId = data['action_id'] as String? ?? '';
    final token = data['confirmation_token'] as String? ?? '';
    final origin = data['origin'] ?? 'Origin';
    final dest = data['destination'] ?? 'Destination';
    final fare = data['fare'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20),
              const SizedBox(width: 6),
              Text(
                'Action Confirmation Required',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Confirm cancellation of ticket $origin → $dest (Refund: ₹${(fare as num).toStringAsFixed(0)})?',
            style: const TextStyle(fontSize: 12, color: LocoColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _handleActionConfirmation(
                            actionId: actionId,
                            confirmationToken: token,
                            confirmed: false,
                          ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: const BorderSide(color: LocoColors.border),
                  ),
                  child: const Text('Keep Ticket', style: TextStyle(fontSize: 12, color: LocoColors.textPrimary)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _handleActionConfirmation(
                            actionId: actionId,
                            confirmationToken: token,
                            confirmed: true,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Cancel Ticket', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> data) {
    final line = data['line'] ?? 'Network';
    final status = data['status'] ?? 'NORMAL';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.blue.shade800, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$line: $status. All suburban services operational.',
              style: TextStyle(fontSize: 11.5, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
