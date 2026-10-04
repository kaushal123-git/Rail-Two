import 'package:flutter/material.dart';
import '../core/theme/loco_theme.dart';
import '../models/station.dart';
import '../models/train.dart';
import '../simulation/train_simulation_engine.dart';

class LiveRailMap extends StatefulWidget {
  final List<RailwayStation> stations;
  final String? activeFromStation;
  final String? activeToStation;
  final Function(LocoTrain train)? onTrainTap;
  final Function(RailwayStation station)? onStationTap;
  final bool compact;

  const LiveRailMap({
    super.key,
    required this.stations,
    this.activeFromStation,
    this.activeToStation,
    this.onTrainTap,
    this.onStationTap,
    this.compact = false,
  });

  @override
  State<LiveRailMap> createState() => _LiveRailMapState();
}

class _LiveRailMapState extends State<LiveRailMap> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final TransformationController _transformController = TransformationController();
  String _selectedLineFilter = 'All';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _resetTransform() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LocoTrain>>(
      stream: TrainSimulationEngine().trainsStream,
      initialData: TrainSimulationEngine().currentTrains,
      builder: (context, snapshot) {
        final trains = snapshot.data ?? [];

        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(widget.compact ? 16 : 0),
              child: Container(
                color: const Color(0xFFF1F4F8),
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 0.5,
                  maxScale: 3.5,
                  boundaryMargin: const EdgeInsets.all(200),
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(600, 1100),
                        painter: RailNetworkPainter(
                          stations: widget.stations,
                          trains: trains,
                          activeFrom: widget.activeFromStation,
                          activeTo: widget.activeToStation,
                          pulseValue: _pulseController.value,
                          lineFilter: _selectedLineFilter,
                          onTrainTap: widget.onTrainTap,
                          onStationTap: widget.onStationTap,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Top Filter Bar (Lines)
            if (!widget.compact)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    _buildFilterChip('All'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Western', color: LocoColors.westernLine),
                    const SizedBox(width: 8),
                    _buildFilterChip('Central', color: LocoColors.centralLine),
                    const SizedBox(width: 8),
                    _buildFilterChip('Harbour', color: LocoColors.harbourLine),
                  ],
                ),
              ),

            // Legend / Status pill
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: LocoColors.border),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: LocoColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${trains.length} Trains Live',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: LocoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '• Pinch to Zoom',
                      style: TextStyle(fontSize: 11, color: LocoColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),

            // Recenter Button
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'recenter_map',
                onPressed: _resetTransform,
                backgroundColor: Colors.white,
                foregroundColor: LocoColors.textPrimary,
                elevation: 2,
                child: const Icon(Icons.center_focus_strong, size: 20),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label, {Color? color}) {
    final isSelected = _selectedLineFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedLineFilter = label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? (color ?? LocoColors.orange) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.transparent : LocoColors.border,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: (color ?? LocoColors.orange).withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : LocoColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class RailNetworkPainter extends CustomPainter {
  final List<RailwayStation> stations;
  final List<LocoTrain> trains;
  final String? activeFrom;
  final String? activeTo;
  final double pulseValue;
  final String lineFilter;
  final Function(LocoTrain train)? onTrainTap;
  final Function(RailwayStation station)? onStationTap;

  RailNetworkPainter({
    required this.stations,
    required this.trains,
    this.activeFrom,
    this.activeTo,
    required this.pulseValue,
    required this.lineFilter,
    this.onTrainTap,
    this.onStationTap,
  });

  // Geographic bounds of Mumbai railway region
  final double minLat = 18.90;
  final double maxLat = 19.55;
  final double minLng = 72.78;
  final double maxLng = 73.15;

  Offset _geoToCanvas(double lat, double lng, Size size) {
    // Map latitude to Y (inverted: higher latitude is North / top)
    final double normY = 1.0 - ((lat - minLat) / (maxLat - minLat)).clamp(0.0, 1.0);
    final double normX = ((lng - minLng) / (maxLng - minLng)).clamp(0.0, 1.0);

    return Offset(
      40 + normX * (size.width - 120),
      60 + normY * (size.height - 120),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final westernStations = stations.where((s) => s.line == 'Western').toList();
    final centralStations = stations.where((s) => s.line == 'Central').toList();
    final harbourStations = stations.where((s) => s.line == 'Harbour').toList();

    // Sort North to South
    westernStations.sort((a, b) => b.latitude.compareTo(a.latitude));
    centralStations.sort((a, b) => b.latitude.compareTo(a.latitude));
    harbourStations.sort((a, b) => b.latitude.compareTo(a.latitude));

    // 1. Draw Railway Lines
    if (lineFilter == 'All' || lineFilter == 'Western') {
      _drawLineTrack(canvas, size, westernStations, LocoColors.westernLine, 5.0);
    }
    if (lineFilter == 'All' || lineFilter == 'Central') {
      _drawLineTrack(canvas, size, centralStations, LocoColors.centralLine, 5.0);
    }
    if (lineFilter == 'All' || lineFilter == 'Harbour') {
      _drawLineTrack(canvas, size, harbourStations, LocoColors.harbourLine, 5.0);
    }

    // 2. Draw Active Journey Highlight Path if From & To are selected
    if (activeFrom != null && activeTo != null) {
      _drawActiveJourneyHighlight(canvas, size);
    }

    // 3. Draw Station Nodes & Text
    for (final s in stations) {
      if (lineFilter != 'All' && s.line != lineFilter) continue;
      _drawStationNode(canvas, size, s);
    }

    // 4. Draw Live Trains along their tracks
    for (final t in trains) {
      if (lineFilter != 'All' && t.line != lineFilter) continue;
      _drawMovingTrain(canvas, size, t);
    }
  }

  void _drawLineTrack(Canvas canvas, Size size, List<RailwayStation> lineStations, Color color, double width) {
    if (lineStations.length < 2) return;

    final paintLine = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final firstPt = _geoToCanvas(lineStations.first.latitude, lineStations.first.longitude, size);
    path.moveTo(firstPt.dx, firstPt.dy);

    for (int i = 1; i < lineStations.length; i++) {
      final pt = _geoToCanvas(lineStations[i].latitude, lineStations[i].longitude, size);
      path.lineTo(pt.dx, pt.dy);
    }

    canvas.drawPath(path, paintLine);
  }

  void _drawActiveJourneyHighlight(Canvas canvas, Size size) {
    final fromStn = stations.firstWhere((s) => s.name.toUpperCase() == activeFrom!.toUpperCase(), orElse: () => stations.first);
    final toStn = stations.firstWhere((s) => s.name.toUpperCase() == activeTo!.toUpperCase(), orElse: () => stations.last);

    final p1 = _geoToCanvas(fromStn.latitude, fromStn.longitude, size);
    final p2 = _geoToCanvas(toStn.latitude, toStn.longitude, size);

    final glowPaint = Paint()
      ..color = LocoColors.orange.withOpacity(0.35 + pulseValue * 0.25)
      ..strokeWidth = 14.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final corePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(p1, p2, glowPaint);
    canvas.drawLine(p1, p2, corePaint);
  }

  void _drawStationNode(Canvas canvas, Size size, RailwayStation s) {
    final pt = _geoToCanvas(s.latitude, s.longitude, size);
    final isSelected = (activeFrom != null && s.name.toUpperCase() == activeFrom!.toUpperCase()) ||
        (activeTo != null && s.name.toUpperCase() == activeTo!.toUpperCase());

    // Outer Halo
    if (isSelected) {
      final haloPaint = Paint()
        ..color = LocoColors.orange.withOpacity(0.4 - pulseValue * 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, 16 + pulseValue * 6, haloPaint);
    }

    // Node Base
    final borderPaint = Paint()
      ..color = isSelected ? LocoColors.orange : (s.line == 'Western' ? LocoColors.westernLine : (s.line == 'Central' ? LocoColors.centralLine : LocoColors.harbourLine))
      ..strokeWidth = isSelected ? 3.5 : 2.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = isSelected ? LocoColors.orange : Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(pt, isSelected ? 7 : (s.isJunction ? 6 : 4.5), fillPaint);
    canvas.drawCircle(pt, isSelected ? 7 : (s.isJunction ? 6 : 4.5), borderPaint);

    // Station Name Label
    final textSpan = TextSpan(
      text: s.name,
      style: TextStyle(
        color: isSelected ? LocoColors.orangeDark : LocoColors.textPrimary,
        fontSize: isSelected ? 12 : (s.isJunction ? 11 : 9.5),
        fontWeight: isSelected || s.isJunction ? FontWeight.w800 : FontWeight.w500,
        backgroundColor: Colors.white.withOpacity(0.75),
      ),
    );

    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(pt.dx + 8, pt.dy - (tp.height / 2)));
  }

  void _drawMovingTrain(Canvas canvas, Size size, LocoTrain train) {
    final pt = _geoToCanvas(train.lat, train.lng, size);

    // Train Marker Pill
    final bgPaint = Paint()
      ..color = train.isAc ? Colors.blue.shade700 : (train.delayMinutes > 0 ? LocoColors.error : LocoColors.textPrimary)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: pt, width: 72, height: 24),
      const Radius.circular(12),
    );

    canvas.drawRRect(rrect.shift(const Offset(0, 2)), shadowPaint);
    canvas.drawRRect(rrect, bgPaint);

    // Train Name Text inside Pill
    final textSpan = TextSpan(
      text: '🚆 ${train.number.substring(train.number.length - 3)} • ${train.speedKmH.toInt()}k',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
      ),
    );

    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(pt.dx - (tp.width / 2), pt.dy - (tp.height / 2)));
  }

  @override
  bool shouldRepaint(covariant RailNetworkPainter oldDelegate) {
    return true; // repaint on simulation tick or pulse animation
  }
}
