import 'package:flutter/material.dart';
import '../core/theme/loco_theme.dart';
import '../models/ticket.dart';

class DynamicTicketCard extends StatelessWidget {
  final BookedTicket ticket;
  final VoidCallback onTap;
  final VoidCallback? onStartJourney;

  const DynamicTicketCard({
    super.key,
    required this.ticket,
    required this.onTap,
    this.onStartJourney,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = ticket.status == TicketStatus.upcoming;
    final isSuspicious = ticket.status == TicketStatus.suspicious;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSuspicious
              ? LocoColors.error
              : (isActive ? LocoColors.orange.withOpacity(0.4) : LocoColors.border),
          width: isActive || isSuspicious ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive ? LocoColors.orange.withOpacity(0.08) : Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top metadata row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isSuspicious
                                ? LocoColors.error
                                : (isActive ? LocoColors.success : LocoColors.textMuted),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isSuspicious
                              ? 'SUSPICIOUS ACTIVITY'
                              : (isActive ? 'ACTIVE • READY TO TRAVEL' : 'COMPLETED'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: isSuspicious
                                ? LocoColors.error
                                : (isActive ? LocoColors.success : LocoColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      ticket.id,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: LocoColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Station Origin -> Destination Route Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.fromStationCode,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: LocoColors.textPrimary,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            ticket.fromStationName,
                            style: const TextStyle(
                              fontSize: 13,
                              color: LocoColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: LocoColors.orangeLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.train, size: 14, color: LocoColors.orange),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 14, color: LocoColors.orange),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            ticket.toStationCode,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: LocoColors.textPrimary,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            ticket.toStationName,
                            style: const TextStyle(
                              fontSize: 13,
                              color: LocoColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 12),

                // Details & Fare
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildDetailChip('${ticket.classType} CLASS'),
                        const SizedBox(width: 6),
                        _buildDetailChip(ticket.trainType),
                        const SizedBox(width: 6),
                        _buildDetailChip('${ticket.distanceKm.toInt()} KM'),
                      ],
                    ),
                    Text(
                      '₹${ticket.fare}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: LocoColors.orange,
                      ),
                    ),
                  ],
                ),

                // Start Journey Guardian CTA if active
                if (isActive && onStartJourney != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onStartJourney,
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      label: const Text('Start Journey with Guardian'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LocoColors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: LocoColors.canvas,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: LocoColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: LocoColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
