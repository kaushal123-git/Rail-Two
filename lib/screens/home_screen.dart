import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/station.dart';
import '../services/location_service.dart';
import '../services/s2_service.dart';
import '../services/station_storage.dart';
import 'stations_list_screen.dart';
import 'add_station_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  Position? _currentPosition;
  String? _currentS2Token;
  String? _currentS2Id;
  
  List<RailwayStation> _stations = [];
  RailwayStation? _nearestStation;
  double? _nearestDistance;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isLiveTracking = false;
  
  late AnimationController _pulseController;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _initApp();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Load stations database
      final stations = await StationStorage.loadAllStations();
      setState(() {
        _stations = stations;
      });

      // 2. Fetch initial GPS location
      await _fetchLocation();
    } catch (e) {
      setState(() {
        _errorMessage = "App initialization failed: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final hasPermission = await LocationService.handleLocationPermission();
    if (!hasPermission) {
      setState(() {
        _errorMessage = "Location permission was denied. Please grant permission in settings.";
        _isLoading = false;
      });
      return;
    }

    final pos = await LocationService.getCurrentLocation();
    if (pos == null) {
      setState(() {
        _errorMessage = "Unable to fetch GPS coordinates. Ensure location is enabled.";
        _isLoading = false;
      });
      return;
    }

    _updateLocation(pos);
  }

  void _updateLocation(Position pos) {
    // Convert current position coordinates to S2 details
    final token = S2Service.getCellToken(pos.latitude, pos.longitude);
    final id = S2Service.getCellIdString(pos.latitude, pos.longitude);

    setState(() {
      _currentPosition = pos;
      _currentS2Token = token;
      _currentS2Id = id;
      _isLoading = false;
    });

    _calculateNearestStation();
  }

  void _calculateNearestStation() {
    if (_currentPosition == null || _stations.isEmpty) return;

    RailwayStation? closest;
    double minDistance = double.infinity;

    for (var station in _stations) {
      final distance = S2Service.calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        station.latitude,
        station.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closest = station;
      }
    }

    setState(() {
      _nearestStation = closest;
      _nearestDistance = minDistance;
    });
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return "${meters.toStringAsFixed(0)} m";
    } else {
      return "${(meters / 1000).toStringAsFixed(2)} km";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RAIL S2 FINDER'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Location',
            onPressed: _isLoading ? null : _fetchLocation,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Pulser Radar & Header S2 Status
              _buildLocationStatusHeader(theme),
              const SizedBox(height: 25),

              // 2. Main Suggestion: Nearest Station
              Text(
                'NEAREST STATION SUGGESTION',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 10),
              _buildNearestStationCard(theme),
              const SizedBox(height: 30),

              // 3. App Actions Grid
              Text(
                'ACTIONS',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 10),
              _buildActionGrid(context, theme),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationStatusHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surface.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Row(
        children: [
          // Pulse Location Indicator
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary.withOpacity(0.15 * (1 - _pulseController.value)),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.secondary.withOpacity(0.2 * (1 - _pulseController.value)),
                    ),
                  );
                },
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isLoading ? Colors.amber : theme.colorScheme.primary,
                ),
                child: Icon(
                  _isLoading ? Icons.hourglass_empty : Icons.my_location,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          // S2 cell info & coordinates
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null) ...[
                  Text(
                    'GPS Connection Error',
                    style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ] else if (_currentPosition == null) ...[
                  const Text(
                    'Locating User...',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  const Text('Initializing satellite connection...'),
                ] else ...[
                  Text(
                    'S2 CELL: $_currentS2Token',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: theme.colorScheme.secondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _currentS2Id ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('S2 Cell ID copied to clipboard!'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Text(
                            'Cell ID: $_currentS2Id',
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.white38),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.copy, size: 12, color: Colors.white38),
                      ],
                    ),
                  ),
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNearestStationCard(ThemeData theme) {
    if (_isLoading && _nearestStation == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            children: [
              CircularProgressIndicator(color: theme.colorScheme.secondary),
              const SizedBox(height: 16),
              const Text('Computing distances to stations...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    if (_nearestStation == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(Icons.location_off_outlined, size: 48, color: theme.colorScheme.error.withOpacity(0.7)),
              const SizedBox(height: 12),
              const Text(
                'No Location Data Available',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Please ensure location services and database are initialized properly.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.gps_fixed),
                label: const Text('Try Again'),
                onPressed: _fetchLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.85),
            const Color(0xFF3F51B5).withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            // Can show detail sheet in future
          },
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.directions_railway, size: 16, color: Colors.tealAccent),
                              SizedBox(width: 6),
                              Text(
                                'RECOMMENDED STATION',
                                style: TextStyle(
                                  color: Colors.tealAccent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _nearestStation!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatDistance(_nearestDistance ?? 0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoIndicator(
                        context,
                        'Station coordinates',
                        '${_nearestStation!.latitude.toStringAsFixed(4)}, ${_nearestStation!.longitude.toStringAsFixed(4)}',
                        Icons.map_outlined,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoIndicator(
                        context,
                        'Station S2 cell token',
                        _nearestStation!.s2CellToken,
                        Icons.grid_3x3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Calculated using high-precision S2 spherical geodesics.',
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoIndicator(BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white60),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(fontSize: 9, color: Colors.white60, letterSpacing: 0.5),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildActionGrid(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        // Action 1: View all
        Expanded(
          child: _buildActionButton(
            theme: theme,
            title: 'All Stations',
            subtitle: '${_stations.length} Registered',
            icon: Icons.list_alt,
            gradient: const LinearGradient(
              colors: [Color(0xFF3F51B5), Color(0xFF1E88E5)],
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StationsListScreen(
                    userPosition: _currentPosition,
                    stations: _stations,
                    onDeleteStation: (id) async {
                      await StationStorage.deleteCustomStation(id);
                      final updated = await StationStorage.loadAllStations();
                      setState(() {
                        _stations = updated;
                        _calculateNearestStation();
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 15),
        // Action 2: Add Station
        Expanded(
          child: _buildActionButton(
            theme: theme,
            title: 'Add Station',
            subtitle: 'New Coordinate',
            icon: Icons.add_location_alt_outlined,
            gradient: const LinearGradient(
              colors: [Color(0xFF00B0FF), Color(0xFF00E5FF)],
            ),
            onTap: () async {
              final newStation = await Navigator.push<RailwayStation>(
                context,
                MaterialPageRoute(
                  builder: (context) => AddStationScreen(
                    currentUserPosition: _currentPosition,
                  ),
                ),
              );

              if (newStation != null) {
                await StationStorage.saveCustomStation(newStation);
                final updated = await StationStorage.loadAllStations();
                setState(() {
                  _stations = updated;
                  _calculateNearestStation();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Station "${newStation.name}" saved to JSON successfully!')),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, size: 28, color: Colors.white),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white70),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
