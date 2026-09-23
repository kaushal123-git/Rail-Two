import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/station.dart';
import '../services/s2_service.dart';

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
  
  // Set of default station IDs from default_stations.json
  final Set<String> _defaultStationIds = {
    'ndls', 'csmt', 'hwh', 'mas', 'sbc', 'sc', 'pune', 'adi'
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

    // Sort by distance if available, otherwise by name
    if (widget.userPosition != null) {
      processed.sort((a, b) => (a.value ?? double.infinity).compareTo(b.value ?? double.infinity));
    } else {
      processed.sort((a, b) => a.key.name.compareTo(b.key.name));
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      processed = processed.where((entry) => 
        entry.key.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        entry.key.s2CellToken.toLowerCase().contains(_searchQuery.toLowerCase())
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
    final theme = Theme.of(context);
    final sortedStations = _getProcessedStations();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ALL RAILWAY STATIONS'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search stations or S2 tokens...',
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.cardTheme.color,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5), width: 1),
                ),
              ),
            ),
          ),
          
          // Sorted list of stations
          Expanded(
            child: sortedStations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        Text(
                          'No stations found',
                          style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white38),
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

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            color: isNearest 
                                ? theme.colorScheme.primary.withValues(alpha: 0.15) 
                                : theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isNearest
                                  ? theme.colorScheme.secondary.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.05),
                              width: isNearest ? 1.5 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isNearest 
                                      ? theme.colorScheme.secondary.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.train_outlined,
                                  color: isNearest ? theme.colorScheme.secondary : Colors.white70,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      station.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  if (isNearest)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'NEAREST',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.secondary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.grid_3x3, size: 10, color: Colors.tealAccent),
                                            const SizedBox(width: 4),
                                            Text(
                                              station.s2CellToken,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                                color: Colors.tealAccent,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Lat: ${station.latitude.toStringAsFixed(4)}, Lng: ${station.longitude.toStringAsFixed(4)}',
                                        style: const TextStyle(fontSize: 11, color: Colors.white38),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (distance != null)
                                    Text(
                                      _formatDistance(distance),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: isNearest ? theme.colorScheme.secondary : Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  if (isCustom) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      onPressed: () => _confirmDelete(context, station),
                                      tooltip: 'Delete custom station',
                                    ),
                                  ]
                                ],
                              ),
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
        content: Text('Are you sure you want to delete "${station.name}" from storage?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              widget.onDeleteStation(station.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Station "${station.name}" removed from JSON.')),
              );
            },
          ),
        ],
      ),
    );
  }
}
