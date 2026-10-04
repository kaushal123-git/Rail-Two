import 'package:flutter/material.dart';
import '../core/theme/loco_theme.dart';
import '../models/station.dart';
import '../models/train.dart';
import '../services/station_storage.dart';
import '../widgets/live_rail_map.dart';
import '../widgets/station_details_sheet.dart';
import '../widgets/train_details_sheet.dart';
import 'booking_screen.dart';

class ExploreScreen extends StatefulWidget {
  final Function(RailwayStation station)? onSelectStationAsOrigin;
  final Function(RailwayStation station)? onSelectStationAsDestination;

  const ExploreScreen({
    super.key,
    this.onSelectStationAsOrigin,
    this.onSelectStationAsDestination,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<RailwayStation> _stations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    final list = await StationStorage.loadAllStations();
    setState(() {
      _stations = list;
      _isLoading = false;
    });
  }

  void _showTrainDetails(LocoTrain train) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TrainDetailsSheet(
        train: train,
        onBookTap: () {
          final from = _stations.firstWhere(
            (s) => s.name.toUpperCase() == train.currentStation.toUpperCase(),
            orElse: () => _stations.first,
          );
          final to = _stations.firstWhere(
            (s) => s.name.toUpperCase() == train.destinationStation.toUpperCase(),
            orElse: () => _stations.last,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookingScreen(
                fromStation: from,
                toStation: to,
                stationDifference: 8,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showStationDetails(RailwayStation station) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StationDetailsSheet(
        station: station,
        onSelectAsOrigin: widget.onSelectStationAsOrigin,
        onSelectAsDestination: widget.onSelectStationAsDestination,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: LocoColors.orange),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('Live Rail Network', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            SizedBox(width: 8),
            Text('• Mumbai', style: TextStyle(fontSize: 14, color: LocoColors.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20, color: LocoColors.textSecondary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Interactive Rail Network: Pinch to zoom. Tap any train or station to inspect live telemetry.'),
                  backgroundColor: LocoColors.textPrimary,
                ),
              );
            },
          ),
        ],
      ),
      body: LiveRailMap(
        stations: _stations,
        onTrainTap: _showTrainDetails,
        onStationTap: _showStationDetails,
      ),
    );
  }
}
