import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme/loco_theme.dart';
import '../models/station.dart';
import '../services/s2_service.dart';
import '../widgets/station_details_sheet.dart';

class StationsListScreen extends StatefulWidget {
  final Position? userPosition;
  final List<RailwayStation> stations;
  final Function(String) onDeleteStation;

  const StationsListScreen({
    super.key,
    required this.userPosition,
    required this.stations,
    required this.onDeleteStation,
  });

  @override
  State<StationsListScreen> createState() => _StationsListScreenState();
}

class _StationsListScreenState extends State<StationsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Default station IDs
  final Set<String> _defaultStationIds = {
    'csmt', 'churchgate', 'dadar', 'andheri', 'bandra', 'borivali', 'thane', 'kalyan', 'kurla', 'panvel'
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MapEntry<RailwayStation, double?>> _getProcessedStations() {
    List<MapEntry<RailwayStation, double?>> processed = [];

    for (var station in widget.stations) {
      double? distance;
      if (widget.userPosition != null) {
        distance = S2Service.calculateDistance(
          widget.userPosition!.latitude,
          widget.userPosition!.longitude,
          station.latitude,
          station.longitude,
        );
      }
      processed.add(MapEntry(station, distance));
    }

    if (widget.userPosition != null) {
      processed.sort((a, b) => (a.value ?? double.infinity).compareTo(b.value ?? double.infinity));
    } else {
      processed.sort((a, b) => a.key.name.compareTo(b.key.name));
    }

    if (_searchQuery.isNotEmpty) {
      processed = processed.where((entry) =>
        entry.key.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        entry.key.s2CellToken.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        entry.key.line.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    return processed;
  }

  String _formatDistance(double? meters) {
    if (meters == null) return "Unknown";
    if (meters < 1000) {
      return "${meters.toStringAsFixed(0)} m";
    } else {
      return "${(meters / 1000).toStringAsFixed(1)} km";
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedStations = _getProcessedStations();

    return Scaffold(
      backgroundColor: LocoColors.canvas,
      appBar: AppBar(
        title: const Text(
          'STATIONS & S2 NODES',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: LocoColors.orangeSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${sortedStations.length} Stations',
              style: const TextStyle(
                color: LocoColors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search Mumbai stations or S2 tokens...',
                hintStyle: const TextStyle(color: LocoColors.textMuted, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: LocoColors.orange),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: LocoColors.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: LocoColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: LocoColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: LocoColors.orange, width: 1.5),
                ),
              ),
            ),
          ),

          // List
          Expanded(
            child: sortedStations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 64, color: LocoColors.textMuted),
                        const SizedBox(height: 16),
                        const Text(
                          'No stations match your search',
                          style: TextStyle(color: LocoColors.textSecondary, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: sortedStations.length,
                    itemBuilder: (context, index) {
                      final entry = sortedStations[index];
                      final station = entry.key;
                      final distance = entry.value;
                      final isNearest = index == 0 && widget.userPosition != null && _searchQuery.isEmpty;
                      final isCustom = !_defaultStationIds.contains(station.id);

                      final lineColor = station.line == 'Western'
                          ? LocoColors.westernLine
                          : (station.line == 'Central' ? LocoColors.centralLine : LocoColors.harbourLine);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => StationDetailsSheet(station: station),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              color: isNearest ? LocoColors.orangeSurface : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isNearest ? LocoColors.orange : LocoColors.border,
                                width: isNearest ? 1.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isNearest
                                        ? LocoColors.orange
                                        : lineColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.train_rounded,
                                    color: isNearest ? Colors.white : lineColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              station.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                                color: LocoColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          if (isNearest)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: LocoColors.orange,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'NEAREST',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: lineColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              station.line.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: lineColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: LocoColors.canvas,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: LocoColors.border),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.grid_3x3, size: 9, color: LocoColors.orange),
                                                const SizedBox(width: 2),
                                                Text(
                                                  station.s2CellToken,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontFamily: 'monospace',
                                                    color: LocoColors.textSecondary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (distance != null)
                                      Text(
                                        _formatDistance(distance),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: isNearest ? LocoColors.orange : LocoColors.textPrimary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    if (isCustom)
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.delete_outline, color: LocoColors.error, size: 20),
                                        onPressed: () => _confirmDelete(context, station),
                                        tooltip: 'Delete custom station',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, RailwayStation station) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Station?'),
        content: Text('Are you sure you want to delete "${station.name}" from local storage?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: LocoColors.error)),
            onPressed: () {
              widget.onDeleteStation(station.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Station "${station.name}" removed.')),
              );
            },
          ),
        ],
      ),
    );
  }
}
