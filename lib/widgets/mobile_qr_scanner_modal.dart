import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/station.dart';
import '../services/location_service.dart';
import '../services/station_storage.dart';

class MobileQrScannerModal extends StatefulWidget {
  final Function(RailwayStation station, double? distanceKm) onStationScanned;

  const MobileQrScannerModal({
    super.key,
    required this.onStationScanned,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(RailwayStation station, double? distanceKm) onStationScanned,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MobileQrScannerModal(onStationScanned: onStationScanned),
    );
  }

  @override
  State<MobileQrScannerModal> createState() => _MobileQrScannerModalState();
}

class _MobileQrScannerModalState extends State<MobileQrScannerModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  bool _isTorchOn = false;
  bool _isFrontCamera = false;
  bool _isScanning = true;
  String _scanStatusText = 'Align Station QR code inside frame';
  List<RailwayStation> _stations = [];
  Position? _currentPosition;
  final TextEditingController _manualInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );

    _loadStationsAndLocation();
  }

  @override
  void dispose() {
    _laserController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  Future<void> _loadStationsAndLocation() async {
    final list = await StationStorage.loadAllStations();
    final pos = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _stations = list;
        _currentPosition = pos;
      });
    }
  }

  void _processScannedPayload(String rawCode) {
    if (!_isScanning) return;
    final code = rawCode.trim().toUpperCase();

    // Look up station by name, id, or code
    RailwayStation? matchedStation;
    for (final s in _stations) {
      if (code.contains(s.name.toUpperCase()) ||
          code.contains(s.id.toUpperCase()) ||
          s.name.toUpperCase().startsWith(code)) {
        matchedStation = s;
        break;
      }
    }

    if (matchedStation == null) {
      setState(() {
        _scanStatusText = '⚠️ Unrecognized Station QR Code ($rawCode)';
      });
      return;
    }

    setState(() {
      _isScanning = false;
      _scanStatusText = '✓ Scanned: ${matchedStation!.name}';
    });

    double? distKm;
    if (_currentPosition != null) {
      final meters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        matchedStation.latitude,
        matchedStation.longitude,
      );
      distKm = meters / 1000.0;
    }

    widget.onStationScanned(matchedStation, distKm);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Station QR Scanner',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _scanStatusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: _scanStatusText.startsWith('✓')
                            ? Colors.greenAccent
                            : (_scanStatusText.startsWith('⚠️')
                                ? Colors.amberAccent
                                : Colors.grey.shade400),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on : Icons.flash_off,
                        color: _isTorchOn ? Colors.amber : Colors.white70,
                      ),
                      onPressed: () => setState(() => _isTorchOn = !_isTorchOn),
                    ),
                    IconButton(
                      icon: Icon(
                        _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
                        color: Colors.white70,
                      ),
                      onPressed: () => setState(() => _isFrontCamera = !_isFrontCamera),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Main Viewfinder Frame
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF0066FF).withOpacity(0.4), width: 1.5),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Simulated Camera Feed Background with grid effect
                    CustomPaint(
                      size: Size.infinite,
                      painter: CameraViewfinderGridPainter(isTorchOn: _isTorchOn),
                    ),

                    // Laser Scanning Line
                    AnimatedBuilder(
                      animation: _laserAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: MediaQuery.of(context).size.height * 0.45 * _laserAnimation.value,
                          left: 20,
                          right: 20,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF).withOpacity(0.8),
                                  blurRadius: 12,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Target Corner Reticle
                    CustomPaint(
                      size: const Size(220, 220),
                      painter: QrScannerCornersPainter(),
                    ),

                    // Center Guide Icon
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 72,
                          color: const Color(0xFF00E5FF).withOpacity(0.7),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.radar, color: Colors.cyanAccent, size: 14),
                              SizedBox(width: 6),
                              Text(
                                '500m Geofence Active',
                                style: TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
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
            ),
          ),

          const SizedBox(height: 16),

          // Station Quick Selection Bar for direct simulation or physical testing
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Station to Scan:',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _showManualInputDialog,
                  icon: const Icon(Icons.edit, size: 14, color: Color(0xFF00E5FF)),
                  label: const Text('Enter Code', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Horizontal Station Chip Bar
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _stations.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final st = _stations[index];
                return ActionChip(
                  avatar: const Icon(Icons.qr_code, size: 15, color: Color(0xFF00E5FF)),
                  backgroundColor: const Color(0xFF1E293B),
                  side: BorderSide(color: Colors.blue.shade800),
                  label: Text(
                    st.name,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => _processScannedPayload(st.name),
                );
              },
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showManualInputDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Enter QR Code String', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _manualInputController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. VIRAR or CHURCHGATE',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = _manualInputController.text;
              Navigator.pop(ctx);
              if (val.isNotEmpty) {
                _processScannedPayload(val);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
            child: const Text('Scan Code', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for Camera viewfinder background
class CameraViewfinderGridPainter extends CustomPainter {
  final bool isTorchOn;

  CameraViewfinderGridPainter({required this.isTorchOn});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = isTorchOn ? const Color(0xFF263238) : const Color(0xFF0B132B);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0;

    const step = 30.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CameraViewfinderGridPainter oldDelegate) {
    return oldDelegate.isTorchOn != isTorchOn;
  }
}

// Custom Painter for Reticle Corners
class QrScannerCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 24.0;

    // Top-Left
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerLen)
        ..lineTo(0, 0)
        ..lineTo(cornerLen, 0),
      paint,
    );

    // Top-Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLen, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, cornerLen),
      paint,
    );

    // Bottom-Left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerLen)
        ..lineTo(0, size.height)
        ..lineTo(cornerLen, size.height),
      paint,
    );

    // Bottom-Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLen, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - cornerLen),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
