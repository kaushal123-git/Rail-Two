import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/loco_theme.dart';
import '../models/station.dart';
import '../models/train.dart';
import '../services/station_state_service.dart';
import '../simulation/train_simulation_engine.dart';
import '../widgets/rail_ai_sheet.dart';
import 'booking_screen.dart';

class LiveRoutesScreen extends StatefulWidget {
  const LiveRoutesScreen({super.key});

  @override
  State<LiveRoutesScreen> createState() => _LiveRoutesScreenState();
}

class _LiveRoutesScreenState extends State<LiveRoutesScreen> {
  final StationStateService _stationState = StationStateService();
  String _selectedFilter = 'All Routes';
  StreamSubscription<List<LocoTrain>>? _trainSub;
  int _secondsCounter = 0;
  Timer? _timer;

  final Set<String> _expandedRoutes = {};

  @override
  void initState() {
    super.initState();
    _stationState.addListener(_onStationStateChanged);

    // Periodically tick countdown timer for live feel
    _timer = Timer.periodic(const Duration(seconds: 15), (t) {
      if (mounted) setState(() => _secondsCounter++);
    });

    _trainSub = TrainSimulationEngine().trainsStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _onStationStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _stationState.removeListener(_onStationStateChanged);
    _trainSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _showStationPicker({required bool isOrigin}) {
    final stations = _stationState.stations;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = stations.where((s) {
              final q = searchQuery.toLowerCase().trim();
              if (q.isEmpty) return true;
              return s.name.toLowerCase().contains(q) ||
                  s.code.toLowerCase().contains(q) ||
                  s.line.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: LocoColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isOrigin ? 'Select Origin Station' : 'Select Destination Station',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: LocoColors.textMuted),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Search box
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: false,
                      onChanged: (val) => setModalState(() => searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search station name or code (e.g. Dadar, VR)...',
                        prefixIcon: const Icon(Icons.search, color: LocoColors.orange),
                        filled: true,
                        fillColor: LocoColors.canvas,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: LocoColors.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Current GPS button
                  if (isOrigin)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: LocoColors.orangeLight, width: 1.5),
                        ),
                        tileColor: LocoColors.orangeLight,
                        leading: const Icon(Icons.my_location, color: LocoColors.orange),
                        title: const Text(
                          'Detect Current GPS Location',
                          style: TextStyle(fontWeight: FontWeight.w800, color: LocoColors.orange, fontSize: 13.5),
                        ),
                        subtitle: const Text(
                          'Auto-detect nearest suburban station',
                          style: TextStyle(fontSize: 11, color: LocoColors.textSecondary),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          await _stationState.detectCurrentLocation();
                        },
                      ),
                    ),

                  const Divider(),

                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final s = filtered[index];
                        final isSelected = isOrigin
                            ? s.id == _stationState.currentStation.id
                            : s.id == _stationState.destinationStation.id;

                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected ? LocoColors.orange : LocoColors.orangeLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                s.code,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : LocoColors.orange,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            s.name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                              color: isSelected ? LocoColors.orange : LocoColors.textPrimary,
                              fontSize: 14.5,
                            ),
                          ),
                          subtitle: Text(
                            '${s.line} Railway • Platform 1-${s.platformsCount}',
                            style: const TextStyle(fontSize: 12, color: LocoColors.textMuted),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: LocoColors.orange, size: 20)
                              : const Icon(Icons.chevron_right, size: 18, color: LocoColors.textMuted),
                          onTap: () {
                            if (isOrigin) {
                              _stationState.setCurrentStation(s);
                            } else {
                              _stationState.setDestinationStation(s);
                            }
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openLoCoPilotAI() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RailAISheet(),
    );
  }

  void _bookRoute(RailwayStation from, RailwayStation to, {bool isAc = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(
          fromStation: from,
          toStation: to,
          stationDifference: 7,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final from = _stationState.currentStation;
    final to = _stationState.destinationStation;

    return Scaffold(
      backgroundColor: LocoColors.canvas,
      appBar: AppBar(
        title: const Row(
          children: [
            Text('Best Live Routes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            SizedBox(width: 8),
            Text('• Real-Time Intel', style: TextStyle(fontSize: 12.5, color: LocoColors.orange, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt, color: LocoColors.orange),
            tooltip: 'Ask LOCOpilot AI',
            onPressed: _openLoCoPilotAI,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Station Route Selector Card
            _buildRouteSelectorCard(from, to),

            const SizedBox(height: 16),

            // Filter Chips
            _buildFilterChips(),

            const SizedBox(height: 18),

            // Live Routes Feed Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: LocoColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Upcoming Direct & Fast Services',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                    ),
                  ],
                ),
                Text(
                  'Auto-refreshed',
                  style: TextStyle(fontSize: 11, color: LocoColors.textMuted, fontWeight: FontWeight.w500),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Route 1: Fast Local
            if (_selectedFilter == 'All Routes' || _selectedFilter == '⚡ Fast Locals' || _selectedFilter == '🎯 Direct Only')
              _buildRouteCard(
                id: 'route_fast_1',
                title: '${to.name} Fast Local',
                tag: '15-Car High Capacity',
                tagColor: LocoColors.orange,
                departsInMinutes: 4,
                departureTime: '09:45 AM',
                platform: 'PF 2',
                durationMinutes: 34,
                haltsCount: 6,
                distanceKm: 36.5,
                crowdDensity: 'Moderate',
                crowdColor: LocoColors.warning,
                recommendedCoach: 'Board Coach C6-C8 for fast interchange',
                fareSecondClass: 10,
                fareFirstClass: 65,
                isAc: false,
                stops: [from.name, 'Vasai Road', 'Bhayandar', 'Borivali', 'Andheri', 'Bandra', to.name],
                onBook: () => _bookRoute(from, to),
              ),

            // Route 2: AC Local EMU
            if (_selectedFilter == 'All Routes' || _selectedFilter == '❄️ AC Local EMU' || _selectedFilter == '👥 Least Crowded')
              _buildRouteCard(
                id: 'route_ac_1',
                title: '${to.name} AC EMU Express',
                tag: '12-Car Vestibuled AC',
                tagColor: Colors.blueAccent,
                departsInMinutes: 18,
                departureTime: '09:59 AM',
                platform: 'PF 1',
                durationMinutes: 32,
                haltsCount: 5,
                distanceKm: 36.5,
                crowdDensity: 'Low Seating Guarantee',
                crowdColor: LocoColors.success,
                recommendedCoach: 'Any Coach (All Interconnected AC)',
                fareSecondClass: 65,
                fareFirstClass: 65,
                isAc: true,
                stops: [from.name, 'Borivali', 'Andheri', 'Bandra', to.name],
                onBook: () => _bookRoute(from, to, isAc: true),
              ),

            // Route 3: Slow Local
            if (_selectedFilter == 'All Routes' || _selectedFilter == '🎯 Direct Only' || _selectedFilter == '👥 Least Crowded')
              _buildRouteCard(
                id: 'route_slow_1',
                title: '${to.name} Slow Local',
                tag: '12-Car Standard',
                tagColor: LocoColors.textSecondary,
                departsInMinutes: 11,
                departureTime: '09:52 AM',
                platform: 'PF 4',
                durationMinutes: 52,
                haltsCount: 16,
                distanceKm: 36.5,
                crowdDensity: 'Low at Origin Station',
                crowdColor: LocoColors.success,
                recommendedCoach: 'Coach C4 or C9 (Seats available at source)',
                fareSecondClass: 10,
                fareFirstClass: 65,
                isAc: false,
                stops: [
                  from.name,
                  'Nalasopara',
                  'Vasai Road',
                  'Naigaon',
                  'Bhayandar',
                  'Mira Road',
                  'Dahisar',
                  'Borivali',
                  'Kandivali',
                  'Malad',
                  'Goregaon',
                  'Andheri',
                  'Bandra',
                  to.name,
                ],
                onBook: () => _bookRoute(from, to),
              ),

            // Route 4: Next Fast Local
            if (_selectedFilter == 'All Routes' || _selectedFilter == '⚡ Fast Locals')
              _buildRouteCard(
                id: 'route_fast_2',
                title: '${to.name} Fast Local',
                tag: '15-Car High Capacity',
                tagColor: LocoColors.orange,
                departsInMinutes: 24,
                departureTime: '10:05 AM',
                platform: 'PF 3',
                durationMinutes: 35,
                haltsCount: 6,
                distanceKm: 36.5,
                crowdDensity: 'Moderate',
                crowdColor: LocoColors.warning,
                recommendedCoach: 'Coach C1-C3 (South End)',
                fareSecondClass: 10,
                fareFirstClass: 65,
                isAc: false,
                stops: [from.name, 'Vasai Road', 'Bhayandar', 'Borivali', 'Andheri', 'Bandra', to.name],
                onBook: () => _bookRoute(from, to),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSelectorCard(RailwayStation from, RailwayStation to) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LocoColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Origin Tile
          GestureDetector(
            onTap: () => _showStationPicker(isOrigin: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: LocoColors.canvas,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LocoColors.borderLight),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: LocoColors.orange, width: 3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ORIGIN STATION',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: LocoColors.textMuted, letterSpacing: 0.5),
                        ),
                        Text(
                          from.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: LocoColors.orangeLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      from.code,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: LocoColors.orange, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Swap Indicator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40),
                GestureDetector(
                  onTap: () => _stationState.swapStations(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: LocoColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.swap_vert_rounded, size: 20, color: LocoColors.orange),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _stationState.detectCurrentLocation(),
                  icon: const Icon(Icons.my_location, size: 14, color: LocoColors.orange),
                  label: const Text('GPS Nearest', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: LocoColors.orange)),
                ),
              ],
            ),
          ),

          // Destination Tile
          GestureDetector(
            onTap: () => _showStationPicker(isOrigin: false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: LocoColors.canvas,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LocoColors.borderLight),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF381219),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DESTINATION STATION',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: LocoColors.textMuted, letterSpacing: 0.5),
                        ),
                        Text(
                          to.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCE4EC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      to.code,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF880E4F), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All Routes', '⚡ Fast Locals', '❄️ AC Local EMU', '🎯 Direct Only', '👥 Least Crowded'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _selectedFilter = f);
              },
              selectedColor: LocoColors.orange,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : LocoColors.textSecondary,
              ),
              side: BorderSide(
                color: isSelected ? LocoColors.orange : LocoColors.border,
                width: 1,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRouteCard({
    required String id,
    required String title,
    required String tag,
    required Color tagColor,
    required int departsInMinutes,
    required String departureTime,
    required String platform,
    required int durationMinutes,
    required int haltsCount,
    required double distanceKm,
    required String crowdDensity,
    required Color crowdColor,
    required String recommendedCoach,
    required int fareSecondClass,
    required int fareFirstClass,
    required bool isAc,
    required List<String> stops,
    required VoidCallback onBook,
  }) {
    final isExpanded = _expandedRoutes.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAc ? Colors.blue.withOpacity(0.3) : LocoColors.border,
          width: isAc ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: tagColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: tagColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: LocoColors.canvas,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: LocoColors.border),
                      ),
                      child: Text(
                        platform,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: LocoColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),

                // Departure countdown badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: LocoColors.successLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.alarm, size: 13, color: LocoColors.success),
                          const SizedBox(width: 4),
                          Text(
                            '$departsInMinutes mins',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: LocoColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      departureTime,
                      style: const TextStyle(fontSize: 12, color: LocoColors.textMuted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Title & Duration
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: LocoColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '$durationMinutes mins',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: LocoColors.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: LocoColors.textMuted)),
                    const SizedBox(width: 8),
                    Text(
                      '$haltsCount halts',
                      style: const TextStyle(fontSize: 12, color: LocoColors.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: LocoColors.textMuted)),
                    const SizedBox(width: 8),
                    Text(
                      '${distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 12, color: LocoColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Crowd Radar Insight Box
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: LocoColors.canvas,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: LocoColors.borderLight),
            ),
            child: Row(
              children: [
                Icon(Icons.people_outline, size: 16, color: crowdColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$crowdDensity • $recommendedCoach',
                    style: const TextStyle(fontSize: 11.5, color: LocoColors.textSecondary, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Expandable Stops Timeline
          if (isExpanded) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LocoColors.canvas,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LocoColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Station Halts & Live Telemetry',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  ...stops.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final stopName = entry.value;
                    final isFirst = idx == 0;
                    final isLast = idx == stops.length - 1;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (isFirst || isLast) ? LocoColors.orange : LocoColors.textMuted,
                              ),
                            ),
                            if (!isLast)
                              Container(
                                width: 2,
                                height: 22,
                                color: LocoColors.border,
                              ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            stopName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: (isFirst || isLast) ? FontWeight.w800 : FontWeight.w500,
                              color: (isFirst || isLast) ? LocoColors.textPrimary : LocoColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
          ],

          const Divider(height: 20),

          // Bottom Action Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Fare details
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAc ? 'AC FARE' : 'SECOND CLASS',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: LocoColors.textMuted),
                    ),
                    Text(
                      '₹$fareSecondClass',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                    ),
                  ],
                ),

                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedRoutes.remove(id);
                          } else {
                            _expandedRoutes.add(id);
                          }
                        });
                      },
                      child: Row(
                        children: [
                          Text(
                            isExpanded ? 'Hide Stops' : 'View Stops',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LocoColors.textSecondary),
                          ),
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 16,
                            color: LocoColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton(
                      onPressed: onBook,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAc ? Colors.blue.shade700 : LocoColors.orange,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        isAc ? 'Book AC' : 'Book Ticket',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
