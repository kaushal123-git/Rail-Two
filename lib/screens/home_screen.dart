import 'package:flutter/material.dart';
import '../models/station.dart';
import '../services/station_storage.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'booking_screen.dart';
import 'season_booking_screen.dart';
import 'my_bookings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _ticketTypeIndex = 0; // 0 for Normal, 1 for Season
  int _stationTypeIndex = 0; // 0 for Outside Station, 1 for At Station

  List<RailwayStation> _stations = [];
  RailwayStation? _fromStation;
  RailwayStation? _toStation;

  TextEditingController? _fromController;
  TextEditingController? _toController;

  List<RailwayStation> _nearestStations = [];
  Position? _currentPosition;
  double? _scannedDistanceKm;
  bool _isQrScannedInAtStation = false;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    final stations = await StationStorage.loadAllStations();
    setState(() {
      _stations = stations;
    });
    _determineNearestStations();
  }

  Future<void> _determineNearestStations() async {
    final position = await LocationService.getCurrentLocation();
    if (position == null) return;

    List<RailwayStation> sorted = List.from(_stations);
    sorted.sort((a, b) {
      double distA = Geolocator.distanceBetween(position.latitude, position.longitude, a.latitude, a.longitude);
      double distB = Geolocator.distanceBetween(position.latitude, position.longitude, b.latitude, b.longitude);
      return distA.compareTo(distB);
    });

    final top3 = sorted.take(3).toList();

    setState(() {
      _currentPosition = position;
      _nearestStations = top3;
      if (_fromStation == null && top3.isNotEmpty && _stationTypeIndex == 0) {
        _fromStation = top3.first;
        if (_fromController != null) {
          _fromController!.text = top3.first.name;
        }
      }
    });
  }

  String _getStationDistanceText(RailwayStation station) {
    if (_currentPosition == null) return '';
    double meters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      station.latitude,
      station.longitude,
    );
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  void _swapStations() {
    // Swapping only allowed in Outside Station mode when both stations are set
    if (_stationTypeIndex == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('In "At Station" mode, source station is fixed by QR scan. Select destination station below.'),
        ),
      );
      return;
    }

    setState(() {
      final tempStation = _fromStation;
      _fromStation = _toStation;
      _toStation = tempStation;

      if (_fromController != null && _toController != null) {
        final tempText = _fromController!.text;
        _fromController!.text = _toController!.text;
        _toController!.text = tempText;
      }
    });
  }

  Future<void> _verifyAndSetScannedStation(RailwayStation station) async {
    final position = await LocationService.getCurrentLocation();

    if (position == null) {
      _showRadiusLimitErrorDialog(
        stationName: station.name,
        distanceKm: null,
        customMessage: "GPS position unavailable. Please ensure location services are enabled to verify the 500 m geofence radius.",
      );
      return;
    }

    double distMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      station.latitude,
      station.longitude,
    );
    double distKm = distMeters / 1000.0;

    if (distKm <= 0.5) {
      setState(() {
        _fromStation = station;
        _scannedDistanceKm = distKm;
        _isQrScannedInAtStation = true;
        if (_fromController != null) {
          _fromController!.text = station.name;
        }
      });

      String distStr = distKm < 1.0
          ? '${distMeters.toStringAsFixed(0)} m'
          : '${distKm.toStringAsFixed(1)} km';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '✓ QR Scanned: ${station.name} ($distStr away - Within 500m radius)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      _showRadiusLimitErrorDialog(
        stationName: station.name,
        distanceKm: distKm,
      );
    }
  }

  void _showRadiusLimitErrorDialog({
    required String stationName,
    required double? distanceKm,
    String? customMessage,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text(
              'Radius Limit Exceeded',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              customMessage ??
                  'You are currently ${distanceKm != null ? (distanceKm < 1.0 ? '${(distanceKm * 1000).toStringAsFixed(0)} m' : '${distanceKm.toStringAsFixed(1)} km') : ''} away from $stationName. "At Station" QR booking is only permitted within a 500 m geofence radius.',
              style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
            ),
            if (distanceKm != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_off_rounded, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Current Distance: ${distanceKm < 1.0 ? '${(distanceKm * 1000).toStringAsFixed(0)} m' : '${distanceKm.toStringAsFixed(2)} km'}\n(Maximum Allowed: 500 m)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _stationTypeIndex = 0; // Switch to Outside Station mode
                _isQrScannedInAtStation = false;
                if (_nearestStations.isNotEmpty) {
                  _fromStation = _nearestStations.first;
                  if (_fromController != null) {
                    _fromController!.text = _nearestStations.first.name;
                  }
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Switch to Outside Station', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showQrScannerDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan Station QR Code',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Align Station QR code inside frame',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Simulated Camera Frame
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF0066FF), width: 2),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner, size: 80, color: Color(0xFF0066FF)),
                          SizedBox(height: 12),
                          Text(
                            'Point Camera at Station QR Code',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.radar, color: Colors.cyanAccent, size: 16),
                              SizedBox(width: 8),
                              Text(
                                '500 m Geofence GPS Active',
                                style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Quick station scan buttons for easy testing
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tap a Station to Simulate QR Scan:',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _stations.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final station = _stations[index];
                  return ActionChip(
                    avatar: const Icon(Icons.qr_code, size: 16, color: Color(0xFF0066FF)),
                    label: Text(
                      station.name,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: const Color(0xFF334155),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onPressed: () {
                      Navigator.pop(context);
                      _verifyAndSetScannedStation(station);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildBookingCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFF0066FF),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyBookingsScreen()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SeasonBookingScreen(
                  initialFromStation: _fromStation,
                  initialToStation: _toStation,
                ),
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number),
            label: 'My Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_membership),
            label: 'Season Booking',
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 32),
          const Text(
            'Unreserved E-Ticket',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2A4E),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue.shade100, width: 1.5),
            ),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.close, color: Color(0xFF0066FF), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTicketTypeToggle(),
          const SizedBox(height: 16),
          _buildStationTypeToggle(),
          const SizedBox(height: 16),
          
          if (_stationTypeIndex == 0) _buildOutsideStationBanner(),
          if (_stationTypeIndex == 1) _buildAtStationBanner(),
          
          const SizedBox(height: 16),
          _buildRouteSelection(),
          const SizedBox(height: 24),

          if (_stationTypeIndex == 0) _buildNearestStationsSuggestions(),
          
          const SizedBox(height: 24),
          
          // Proceed To Book Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () async {
                if (_stationTypeIndex == 1) {
                  // In "At Station" mode, QR scan is strictly required for source station!
                  if (_fromStation == null || !_isQrScannedInAtStation) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.redAccent,
                        content: Text(
                          'Please scan the Station QR Code first to select your source station in "At Station" mode.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                    _showQrScannerDialog();
                    return;
                  }
                } else {
                  // In "Outside Station" mode
                  if (_fromStation == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select your source station.')),
                    );
                    return;
                  }

                  if (_nearestStations.isNotEmpty &&
                      !_nearestStations.any((s) => s.id == _fromStation!.id)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.amber.shade900,
                        content: const Text(
                          'Outside Station mode is limited to the 3 nearest stations. Please choose one of the suggested stations.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                    return;
                  }
                }

                if (_toStation == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select your destination station.')),
                  );
                  return;
                }

                // Strictly validate 500m geofence radius if "At Station" is selected!
                if (_stationTypeIndex == 1) {
                  final position = await LocationService.getCurrentLocation();
                  if (position == null) {
                    _showRadiusLimitErrorDialog(
                      stationName: _fromStation!.name,
                      distanceKm: null,
                      customMessage: "GPS position service is required to verify the 500 m geofence radius for At-Station booking.",
                    );
                    return;
                  }

                  double distMeters = Geolocator.distanceBetween(
                    position.latitude,
                    position.longitude,
                    _fromStation!.latitude,
                    _fromStation!.longitude,
                  );
                  double distKm = distMeters / 1000.0;

                  if (distKm > 0.5) {
                    _showRadiusLimitErrorDialog(
                      stationName: _fromStation!.name,
                      distanceKm: distKm,
                    );
                    return;
                  }
                }

                int fromIndex = _stations.indexWhere((s) => s.id == _fromStation!.id);
                int toIndex = _stations.indexWhere((s) => s.id == _toStation!.id);
                int diff = (fromIndex - toIndex).abs();

                if (mounted) {
                  if (_ticketTypeIndex == 1) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SeasonBookingScreen(
                          initialFromStation: _fromStation,
                          initialToStation: _toStation,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingScreen(
                          fromStation: _fromStation!,
                          toStation: _toStation!,
                          stationDifference: diff,
                        ),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0066FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Proceed To Book',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Check Upcoming Trains Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0066FF),
                side: const BorderSide(color: Color(0xFF0066FF), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: const Text(
                'Check Upcoming Trains',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutsideStationBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.location_searching, color: Colors.blue.shade800, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Outside Station Mode: Select from the 3 nearest station suggestions.',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtStationBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.qr_code_scanner, color: Colors.teal.shade800, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'At Station Mode: Scan Station QR Code (500 m Geofence) to unlock source station & choose destination.',
              style: TextStyle(fontSize: 12, color: Colors.teal.shade900, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearestStationsSuggestions() {
    if (_nearestStations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '3 Nearest Station Suggestions',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Outside Station Only',
                style: TextStyle(fontSize: 10, color: Colors.blue.shade900, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _nearestStations.map((station) {
            final isSelected = _fromStation?.id == station.id;
            final distStr = _getStationDistanceText(station);

            return InkWell(
              onTap: () {
                setState(() {
                  _fromStation = station;
                  if (_fromController != null) {
                    _fromController!.text = station.name;
                  }
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0066FF) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0066FF) : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle : Icons.near_me,
                      size: 16,
                      color: isSelected ? Colors.white : const Color(0xFF0066FF),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      station.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    if (distStr.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        '($distStr)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.normal,
                          color: isSelected ? Colors.white.withOpacity(0.9) : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTicketTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _ticketTypeIndex = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _ticketTypeIndex == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: _ticketTypeIndex == 0 ? Border.all(color: Colors.grey.shade300) : null,
                  boxShadow: _ticketTypeIndex == 0
                      ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Normal',
                  style: TextStyle(
                    color: _ticketTypeIndex == 0 ? const Color(0xFF0066FF) : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _ticketTypeIndex = 1);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SeasonBookingScreen(
                      initialFromStation: _fromStation,
                      initialToStation: _toStation,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _ticketTypeIndex == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: _ticketTypeIndex == 1 ? Border.all(color: Colors.grey.shade300) : null,
                  boxShadow: _ticketTypeIndex == 1
                      ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Season',
                  style: TextStyle(
                    color: _ticketTypeIndex == 1 ? const Color(0xFF0066FF) : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationTypeToggle() {
    return Row(
      children: [
        // Outside Station
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _stationTypeIndex = 0;
                if (_nearestStations.isNotEmpty &&
                    (_fromStation == null || !_nearestStations.any((s) => s.id == _fromStation!.id))) {
                  _fromStation = _nearestStations.first;
                  if (_fromController != null) {
                    _fromController!.text = _nearestStations.first.name;
                  }
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _stationTypeIndex == 0 ? const Color(0xFF0066FF) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _stationTypeIndex == 0 ? const Color(0xFF0066FF) : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Outside Station',
                    style: TextStyle(
                      color: _stationTypeIndex == 0 ? Colors.white : Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: _stationTypeIndex == 0 ? Colors.white : Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        
        // At Station
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _stationTypeIndex = 1;
                // In At Station mode, clear fromStation if it was not scanned via QR code
                if (!_isQrScannedInAtStation) {
                  _fromStation = null;
                  if (_fromController != null) {
                    _fromController!.text = '';
                  }
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _stationTypeIndex == 1 ? const Color(0xFF0066FF) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _stationTypeIndex == 1 ? const Color(0xFF0066FF) : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'At Station',
                    style: TextStyle(
                      color: _stationTypeIndex == 1 ? Colors.white : Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: _stationTypeIndex == 1 ? Colors.white : Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteSelection() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FROM Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'From',
                  style: TextStyle(
                    color: Color(0xFF0066FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  _stationTypeIndex == 0
                      ? '3 Nearest Suggestions Only'
                      : 'Scan QR at Station Only',
                  style: TextStyle(
                    color: _stationTypeIndex == 0 ? Colors.blue.shade800 : Colors.teal.shade800,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // In At Station mode, show dedicated QR scan button / scanned card for From station
            if (_stationTypeIndex == 1) ...[
              InkWell(
                onTap: _showQrScannerDialog,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: _isQrScannedInAtStation && _fromStation != null
                        ? Colors.green.shade50
                        : const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isQrScannedInAtStation && _fromStation != null
                          ? Colors.green.shade300
                          : const Color(0xFF0066FF).withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isQrScannedInAtStation && _fromStation != null
                            ? Icons.check_circle_rounded
                            : Icons.qr_code_scanner,
                        color: _isQrScannedInAtStation && _fromStation != null
                            ? Colors.green.shade700
                            : const Color(0xFF0066FF),
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isQrScannedInAtStation && _fromStation != null
                                  ? _fromStation!.name.toUpperCase()
                                  : 'Scan Station QR Code',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _isQrScannedInAtStation && _fromStation != null
                                    ? Colors.green.shade900
                                    : const Color(0xFF0066FF),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isQrScannedInAtStation && _fromStation != null
                                  ? '✓ Scanned & Verified within 500m radius'
                                  : 'Tap to open scanner & set origin station',
                              style: TextStyle(
                                fontSize: 12,
                                color: _isQrScannedInAtStation && _fromStation != null
                                    ? Colors.green.shade800
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isQrScannedInAtStation && _fromStation != null
                              ? Colors.green.shade700
                              : const Color(0xFF0066FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isQrScannedInAtStation && _fromStation != null ? 'Rescan QR' : 'Scan QR',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Outside Station mode: Autocomplete limited strictly to 3 nearest stations
              Row(
                children: [
                  const Icon(Icons.directions_subway, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Autocomplete<RailwayStation>(
                      displayStringForOption: (station) => station.name,
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        Iterable<RailwayStation> options = _nearestStations.isNotEmpty
                            ? _nearestStations
                            : _stations.take(3);
                        if (textEditingValue.text.isNotEmpty) {
                          options = options.where((station) {
                            return station.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        }
                        if (_toStation != null) {
                          options = options.where((s) => s.id != _toStation!.id);
                        }
                        return options;
                      },
                      onSelected: (RailwayStation selection) {
                        setState(() {
                          _fromStation = selection;
                        });
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        if (_fromController != textEditingController) {
                          _fromController = textEditingController;
                        }
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            hintText: 'Select Source (3 Nearest Stations)',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],

            Divider(color: Colors.grey.shade300, height: 24, thickness: 1),
            const SizedBox(height: 4),

            // TO Title
            const Text(
              'To',
              style: TextStyle(
                color: Color(0xFF0066FF),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.directions_subway_outlined, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Autocomplete<RailwayStation>(
                    displayStringForOption: (station) => station.name,
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      Iterable<RailwayStation> options = textEditingValue.text.isEmpty
                          ? _stations
                          : _stations.where((station) {
                              return station.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                            });
                      if (_fromStation != null) {
                        options = options.where((s) => s.id != _fromStation!.id);
                      }
                      return options;
                    },
                    onSelected: (RailwayStation selection) {
                      setState(() {
                        _toStation = selection;
                      });
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      if (_toController != textEditingController) {
                        _toController = textEditingController;
                      }
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'Select Destination Station',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
        
        // Vertical Swap Icon Button (Only shown in Outside Station mode)
        if (_stationTypeIndex == 0)
          Positioned(
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.swap_vert, color: Color(0xFF0066FF)),
                onPressed: _swapStations,
              ),
            ),
          ),
      ],
    );
  }
}
