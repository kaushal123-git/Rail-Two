import 'package:flutter/material.dart';
import '../core/theme/loco_theme.dart';
import '../models/journey.dart';
import '../services/rail_ai_service.dart';

class PostJourneySheet extends StatelessWidget {
  final ActiveJourney journey;
  final VoidCallback onDismiss;
  final VoidCallback onPlanReturn;

  const PostJourneySheet({
    super.key,
    required this.journey,
    required this.onDismiss,
    required this.onPlanReturn,
  });

  @override
  Widget build(BuildContext context) {
    final destName = journey.destinationStation.name;
    final spots = RailAIService.getRecommendationsForStation(destName);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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

          // Success Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: LocoColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: LocoColors.success, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Journey Completed',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: LocoColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Welcome to $destName Station',
                      style: const TextStyle(fontSize: 13, color: LocoColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Journey Summary Metrics Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: LocoColors.canvas,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LocoColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric('Distance', '${journey.ticket.distanceKm.toStringAsFixed(1)} km'),
                _buildDivider(),
                _buildMetric('Duration', '${journey.etaMinutes > 0 ? 34 : 38} min'),
                _buildDivider(),
                _buildMetric('Fare Paid', '₹${journey.ticket.fare}'),
                _buildDivider(),
                _buildMetric('CO₂ Saved', '1.8 kg', color: LocoColors.success),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Contextual Discovery Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Since you\'re in $destName...',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: LocoColors.textPrimary,
                ),
              ),
              const Text(
                'Curated by LOCO AI',
                style: TextStyle(fontSize: 11, color: LocoColors.orange, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Destination Spots List
          ...spots.map((spot) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LocoColors.border),
            ),
            child: Row(
              children: [
                Text(spot.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            spot.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star, size: 14, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text('${spot.rating}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${spot.category} • ${spot.distanceText}',
                        style: const TextStyle(fontSize: 12, color: LocoColors.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        spot.description,
                        style: const TextStyle(fontSize: 12, color: LocoColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),

          const SizedBox(height: 16),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onPlanReturn,
                  child: const Text('Plan Return Journey'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onDismiss,
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: LocoColors.textMuted)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color ?? LocoColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 28, color: LocoColors.border);
  }
}
