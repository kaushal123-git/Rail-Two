import 'package:flutter/material.dart';
import '../core/theme/loco_theme.dart';
import '../models/journey.dart';
import '../services/journey_guardian_service.dart';

/// Real Backend-Controlled Journey Guardian Card.
/// Displays live station progression, corridor geofence status,
/// multi-signal security integrity level, and server-authorized destination completion.
class JourneyGuardianCard extends StatelessWidget {
  final ActiveJourney journey;
  final VoidCallback? onCompleted;
  final VoidCallback? onAbandoned;

  const JourneyGuardianCard({
    super.key,
    required this.journey,
    this.onCompleted,
    this.onAbandoned,
  });

  Color _getSecurityBadgeColor() {
    switch (journey.securityState) {
      case 'NORMAL':
        return LocoColors.success;
      case 'LOCATION_UNCERTAIN':
        return LocoColors.warning;
      case 'ROUTE_DEVIATION':
        return Colors.amber.shade700;
      case 'SECURITY_WARNING':
      case 'SUSPICIOUS':
        return LocoColors.error;
      default:
        return LocoColors.success;
    }
  }

  String _getSecurityBadgeLabel() {
    switch (journey.securityState) {
      case 'NORMAL':
        return 'TRUSTED JOURNEY';
      case 'LOCATION_UNCERTAIN':
        return 'GPS UNCERTAIN';
      case 'ROUTE_DEVIATION':
        return 'ROUTE DEVIATION';
      case 'SECURITY_WARNING':
        return 'SECURITY WARNING';
      case 'SUSPICIOUS':
        return 'ANOMALY FLAGGED';
      default:
        return 'VERIFIED';
    }
  }

  IconData _getSecurityBadgeIcon() {
    switch (journey.securityState) {
      case 'NORMAL':
        return Icons.verified_user_rounded;
      case 'LOCATION_UNCERTAIN':
        return Icons.gps_not_fixed_rounded;
      case 'ROUTE_DEVIATION':
        return Icons.alt_route_rounded;
      case 'SECURITY_WARNING':
      case 'SUSPICIOUS':
        return Icons.warning_amber_rounded;
      default:
        return Icons.shield_rounded;
    }
  }

  Future<void> _handleComplete(BuildContext context) async {
    final res = await JourneyGuardianService().completeJourney();
    if (context.mounted) {
      if (res['success'] == false && res['error']?['code'] == 'COMPLETION_VALIDATION_FAILED') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: LocoColors.warning,
            content: Text(
              '⚠️ Destination Arrival Unverified: ${res['error']?['message'] ?? 'Must be within destination station geofence to complete.'}',
            ),
          ),
        );
      } else if (res['success'] == true) {
        onCompleted?.call();
      }
    }
  }

  Future<void> _handleAbandon(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Active Journey?'),
        content: const Text(
          'Are you sure you want to exit Journey Guardian protection? Server journey status will transition to ABANDONED.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: LocoColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Journey'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await JourneyGuardianService().abandonJourney(reason: 'Passenger ended active journey');
      onAbandoned?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _getSecurityBadgeColor();
    final badgeLabel = _getSecurityBadgeLabel();
    final badgeIcon = _getSecurityBadgeIcon();

    final isApproaching = journey.state == JourneyState.destinationApproach || journey.progressPercent >= 85.0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF1E1E2F)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isApproaching ? LocoColors.orange : badgeColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Shield Header + Live Integrity Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: LocoColors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: LocoColors.orange, width: 1),
                      ),
                      child: const Icon(Icons.shield_outlined, color: LocoColors.orange, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'JOURNEY GUARDIAN',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Real-Time Geofence \u0026 Route Monitor',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Security Integrity Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: badgeColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, color: badgeColor, size: 12),
                      const SizedBox(width: 5),
                      Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Station Progression Grid
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  // Origin -> Destination Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: LocoColors.success, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'ORIGIN',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              journey.originStation.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded, color: LocoColors.orange, size: 18),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(Icons.place_rounded, color: LocoColors.orange, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'DESTINATION',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              journey.destinationStation.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(color: Colors.white12, height: 1),
                  ),

                  // Current Station Context & Next Station
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CURRENT STATION',
                            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00E5FF),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                journey.currentStation.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF00E5FF),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'NEXT STATION',
                            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            journey.nextStation.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Progress Bar & Percentage
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isApproaching ? 'Approaching Destination' : 'On Route Corridor',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
                ),
                Text(
                  '${journey.progressPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: LocoColors.orange),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (journey.progressPercent / 100.0).clamp(0.0, 1.0),
                backgroundColor: Colors.white12,
                color: isApproaching ? LocoColors.success : LocoColors.orange,
                minHeight: 6,
              ),
            ),

            const SizedBox(height: 14),

            // Telemetry Status Row (Speed | Location Confidence | Server Verified)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Speed: ${journey.speedKmH.toStringAsFixed(0)} km/h',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                Text(
                  'Confidence: ${(journey.locationConfidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                Text(
                  'Risk: ${(journey.riskScore * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action Buttons: Complete Journey (Server-controlled) | Abandon
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleComplete(context),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Complete at Destination'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isApproaching ? LocoColors.success : LocoColors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => _handleAbandon(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Exit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
