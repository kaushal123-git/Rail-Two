import 'package:flutter/material.dart';
import '../core/theme/loco_theme.dart';
import '../models/route_option.dart';
import '../models/station.dart';
import '../services/route_recommendation_service.dart';
import 'booking_screen.dart';

class RoutePlannerScreen extends StatefulWidget {
  final RailwayStation fromStation;
  final RailwayStation toStation;

  const RoutePlannerScreen({
    super.key,
    required this.fromStation,
    required this.toStation,
  });

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  List<RouteOption> _options = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final routes = await RouteRecommendationService.getRecommendationsAsync(
        fromStation: widget.fromStation,
        toStation: widget.toStation,
      );
      if (mounted) {
        setState(() {
          _options = routes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not calculate route: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LocoColors.canvas,
      appBar: AppBar(
        title: const Text('AI Journey Options'),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LocoColors.border),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.fromStation.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                      ),
                      Text('Origin • ${widget.fromStation.line} Line', style: const TextStyle(fontSize: 12, color: LocoColors.textMuted)),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward, color: LocoColors.orange, size: 24),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.toStation.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                      ),
                      Text('Destination • ${widget.toStation.line} Line', style: const TextStyle(fontSize: 12, color: LocoColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recommended by LOCO Engine',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: LocoColors.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: LocoColors.orangeLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'MULTI-OBJECTIVE AI',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: LocoColors.orange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Route Options Cards
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: LocoColors.orange),
                ),
              )
            else if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  children: [
                    Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _loadRoutes,
                      style: ElevatedButton.styleFrom(backgroundColor: LocoColors.orange),
                      child: const Text('Retry Route Search', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              )
            else if (_options.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: LocoColors.border),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.route_outlined, size: 40, color: LocoColors.textMuted),
                    SizedBox(height: 12),
                    Text(
                      'No Network Graph Path Found',
                      style: TextStyle(fontWeight: FontWeight.w700, color: LocoColors.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'No operational railway connections found between these stations.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: LocoColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ..._options.map((opt) => _buildOptionCard(opt)),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(RouteOption opt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: opt.title == 'FASTEST' ? LocoColors.orange : LocoColors.border,
          width: opt.title == 'FASTEST' ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookingScreen(
                  fromStation: widget.fromStation,
                  toStation: widget.toStation,
                  stationDifference: opt.intermediateStops.isNotEmpty ? opt.intermediateStops.length : 6,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Badge & Fare
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: opt.title == 'FASTEST' ? LocoColors.orangeLight : LocoColors.canvas,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        opt.badgeText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: opt.title == 'FASTEST' ? LocoColors.orange : LocoColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '₹${opt.fare}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: LocoColors.orange),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Title & Duration
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      opt.trainType,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                    ),
                    Text(
                      '${opt.durationMinutes} mins',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LocoColors.orange),
                    ),
                  ],
                ),

                const SizedBox(height: 4),
                Text(
                  opt.description,
                  style: const TextStyle(fontSize: 13, color: LocoColors.textSecondary),
                ),

                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 10),

                // Footer metrics
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.directions_transit, size: 16, color: LocoColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          opt.transfers > 0
                              ? '${opt.transfers} Transfer • ${opt.intermediateStops.length} stops'
                              : '${opt.intermediateStops.isNotEmpty ? opt.intermediateStops.length : "Direct"} stops',
                          style: const TextStyle(fontSize: 12, color: LocoColors.textSecondary),
                        ),
                      ],
                    ),
                    const Row(
                      children: [
                        Text(
                          'Book Ticket',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LocoColors.orange),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 12, color: LocoColors.orange),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
