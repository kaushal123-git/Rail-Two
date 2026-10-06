import 'package:flutter/material.dart';
import '../core/theme/loco_theme.dart';
import '../models/station.dart';

class StationDetailsSheet extends StatelessWidget {
  final RailwayStation station;
  final Function(RailwayStation station)? onSelectAsOrigin;
  final Function(RailwayStation station)? onSelectAsDestination;

  const StationDetailsSheet({
    super.key,
    required this.station,
    this.onSelectAsOrigin,
    this.onSelectAsDestination,
  });

  @override
  Widget build(BuildContext context) {
    final line = station.line;
    final lineColor = line == 'Western'
        ? LocoColors.westernLine
        : (line == 'Central' ? LocoColors.centralLine : LocoColors.harbourLine);

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
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: lineColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        station.code,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: lineColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: LocoColors.textPrimary,
                        ),
                      ),
                      Text(
                        '$line Railway Line • ${station.platformsCount} Platforms',
                        style: const TextStyle(fontSize: 13, color: LocoColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: lineColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: lineColor.withOpacity(0.3)),
                ),
                child: Text(
                  '$line Line',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: lineColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 14),

          // Spatial S2 Geometry Block
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LocoColors.canvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LocoColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.hub_outlined, color: LocoColors.orange, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GOOGLE S2 GEOMETRY CELL INDEX',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: LocoColors.textMuted, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Token: ${station.s2CellToken}  •  ID: ${station.s2CellId}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LocoColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            'Station Amenities',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: LocoColors.textPrimary),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: station.facilities.map((f) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: LocoColors.canvas,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: LocoColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 14, color: LocoColors.success),
                    const SizedBox(width: 4),
                    Text(f, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Action CTAs
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (onSelectAsOrigin != null) onSelectAsOrigin!(station);
                  },
                  child: const Text('Set as Origin'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (onSelectAsDestination != null) onSelectAsDestination!(station);
                  },
                  child: const Text('Set Destination'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
