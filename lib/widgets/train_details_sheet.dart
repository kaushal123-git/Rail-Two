import 'package:flutter/material.dart';
import '../core/theme/loco_theme.dart';
import '../models/train.dart';

class TrainDetailsSheet extends StatelessWidget {
  final LocoTrain train;
  final VoidCallback? onBookTap;

  const TrainDetailsSheet({
    super.key,
    required this.train,
    this.onBookTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: LocoColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        train.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: LocoColors.textPrimary,
                        ),
                      ),
                      if (train.isAc)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            'AC EMU',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Train #${train.number} • ${train.line} Railway',
                    style: const TextStyle(fontSize: 13, color: LocoColors.textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: train.delayMinutes > 0 ? LocoColors.errorLight : LocoColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  train.status,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: train.delayMinutes > 0 ? LocoColors.error : LocoColors.success,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Telemetry Grid
          Row(
            children: [
              _buildTelemetryCard(
                icon: Icons.speed,
                label: 'Current Speed',
                value: '${train.speedKmH.toInt()} km/h',
              ),
              const SizedBox(width: 12),
              _buildTelemetryCard(
                icon: Icons.train_outlined,
                label: 'Service Type',
                value: train.isFast ? 'Fast Local' : 'Slow Local',
                color: train.isFast ? LocoColors.orange : LocoColors.textSecondary,
              ),
              const SizedBox(width: 12),
              _buildTelemetryCard(
                icon: Icons.timer_outlined,
                label: 'Destination ETA',
                value: '${train.etaMinutes} min',
                color: LocoColors.orange,
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Text(
            'Route & Upcoming Halts',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: LocoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          // Halts timeline
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LocoColors.canvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LocoColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.radio_button_checked, size: 16, color: LocoColors.orange),
                const SizedBox(width: 8),
                Text(
                  train.currentStation,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward, size: 14, color: LocoColors.textMuted),
                const Spacer(),
                const Icon(Icons.location_on, size: 16, color: LocoColors.textPrimary),
                const SizedBox(width: 8),
                Text(
                  train.destinationStation,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (onBookTap != null) onBookTap!();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: LocoColors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Plan Journey on this Train',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryCard({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: LocoColors.canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LocoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color ?? LocoColors.textSecondary),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, color: LocoColors.textMuted)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color ?? LocoColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
