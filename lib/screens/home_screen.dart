import 'package:flutter/material.dart';
import '../models/station.dart';
import '../services/station_storage.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../widgets/mobile_qr_scanner_modal.dart';
import 'package:geolocator/geolocator.dart';
import 'booking_screen.dart';
import 'season_booking_screen.dart';
import 'my_bookings_screen.dart';
import 'research_validation_screen.dart';
import 'signin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserModel? _currentUser;
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
    _loadUserData();
    _loadStations();
  }

  Future<void> _loadUserData() async {
    final user = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
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
      if (top3.isNotEmpty && _stationTypeIndex == 0) {
        if (_fromStation == null || !top3.any((s) => s.id == _fromStation!.id)) {
          _fromStation = top3.first;
          if (_fromController != null) {
            _fromController!.text = top3.first.name;
          }
        }
      }
    });
  }

  void _showOutsideStationLimitDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final currentStationName = _nearestStations.isNotEmpty ? _nearestStations.first.name : 'Unknown';
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Outside Station Range Limit Exceeded',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                  children: [
                    const TextSpan(text: 'Selected station '),
                    TextSpan(
                      text: _fromStation?.name ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                    const TextSpan(text: ' is beyond your 3 nearest stations.\n\nIn '),
                    const TextSpan(text: 'Outside Station Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                    const TextSpan(text: ', UTS rules allow ticket booking ONLY from your '),
                    const TextSpan(text: '3 nearest stations', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0066FF))),
                    TextSpan(text: ' relative to your current location (nearest to $currentStationName):'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Column(
                children: _nearestStations.map((st) {
                  final distStr = _getStationDistanceText(st);
                  final isSelected = _fromStation?.id == st.id;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEBF3FF) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF0066FF) : Colors.grey.shade300,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.train_rounded, color: Color(0xFF0066FF)),
                      title: Text(
                        st.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        distStr.isNotEmpty ? '$distStr away from your current location' : 'Nearest Station',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0066FF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          setState(() {
                            _fromStation = st;
                            if (_fromController != null) {
                              _fromController!.text = st.name;
                            }
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Select Station'),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.my_location_rounded, color: Color(0xFF0066FF)),
                label: const Text('Fix / Change Your Location Preset'),
                onPressed: () {
                  Navigator.pop(context);
                  _showLocationOverrideDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showLocationOverrideDialog() async {
    final customName = await LocationService.getCustomLocationName();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.my_location_rounded, color: Color(0xFF0066FF)),
                      SizedBox(width: 8),
                      Text(
                        'Set / Fix Your Current Location',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              if (customName != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Active Location Override: $customName',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Select your location to calculate the 3 nearest station recommendations:',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 14),

              // Re-detect Device / Browser GPS Option
              InkWell(
                onTap: () async {
                  await LocationService.clearCustomLocation();
                  final pos = await LocationService.forceFetchDeviceGps();
                  if (context.mounted) Navigator.pop(context);
                  setState(() {
                    _fromStation = null;
                  });
                  await _determineNearestStations();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF0066FF),
                        content: Text('Location updated: ${_currentUser?.name ?? "User"} (${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)})'),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBF3FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF0066FF), width: 1.5),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.gps_fixed, color: Color(0xFF0066FF), size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📡 Use Real Device / Browser GPS',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0066FF)),
                            ),
                            Text(
                              'Clears override & uses live device location.',
                              style: TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Color(0xFF0066FF)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              const Text('Popular Station Location Presets:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
              const SizedBox(height: 8),

              // Presets Grid / List
              _buildPresetLocationTile(
                name: 'Vasai Road (BSR)',
                subtitle: 'Suggests Vasai Road, Naigaon & Nalasopara',
                lat: 19.3825255,
                lng: 72.8325893,
              ),
              const SizedBox(height: 6),
              _buildPresetLocationTile(
                name: 'Borivali (BVI)',
                subtitle: 'Suggests Borivali, Kandivali & Dahisar',
                lat: 19.2290222,
                lng: 72.8573248,
              ),
              const SizedBox(height: 6),
              _buildPresetLocationTile(
                name: 'Andheri (ADH)',
                subtitle: 'Suggests Andheri, Malad & Bandra',
                lat: 19.1200133,
                lng: 72.8473045,
              ),
              const SizedBox(height: 6),
              _buildPresetLocationTile(
                name: 'Dadar (DDR)',
                subtitle: 'Suggests Dadar, Bandra & Mumbai Central',
                lat: 19.0192552,
                lng: 72.8438955,
              ),
              const SizedBox(height: 14),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPresetLocationTile({
    required String name,
    required String subtitle,
    required double lat,
    required double lng,
  }) {
    return InkWell(
      onTap: () async {
        await LocationService.setCustomLocation(lat, lng, name: name);
        if (context.mounted) Navigator.pop(context);
        setState(() {
          _fromStation = null;
        });
        await _determineNearestStations();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '✓ Location set to $name! 3 nearest stations updated.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_rounded, color: Color(0xFF0066FF), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
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
    MobileQrScannerModal.show(
      context,
      onStationScanned: (station, distanceKm) {
        _verifyAndSetScannedStation(station);
      },
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
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final userName = _currentUser?.name ?? 'Commuter';
    final userPhone = _currentUser?.phone ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'RO1-RO4 Research Dashboard',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Icon(Icons.analytics_rounded, color: Color(0xFF0066FF), size: 20),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ResearchValidationScreen()),
              );
            },
          ),
          const Text(
            'Unreserved E-Ticket',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2A4E),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account Profile',
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: Container(
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue.shade200, width: 1.5),
                color: Colors.blue.shade50,
              ),
              child: const Icon(Icons.person, color: Color(0xFF0066FF), size: 20),
            ),
            onSelected: (value) async {
              if (value == 'logout') {
                await AuthService.logout();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const SignInScreen()),
                    (route) => false,
                  );
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Row(
                  children: [
                    const Icon(Icons.account_circle, color: Color(0xFF0066FF), size: 28),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
                        if (userPhone.isNotEmpty)
                          Text('+91 $userPhone', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Logout Session', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
            ],
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

          if (_ticketTypeIndex == 1) ...[
            _buildSeasonPassBanner(),
            const SizedBox(height: 16),
          ],

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
                    _showOutsideStationLimitDialog();
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
              child: Text(
                _ticketTypeIndex == 1 ? 'Proceed To Book Season Pass' : 'Proceed To Book Normal Ticket',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
          InkWell(
            onTap: _showLocationOverrideDialog,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF0066FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_location_alt_rounded, color: Colors.white, size: 13),
                  SizedBox(width: 4),
                  Text(
                    'Fix Location',
                    style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
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

  Widget _buildSeasonPassBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.card_membership, color: Colors.indigo.shade800, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Season Pass Mode: Issue or Renew Monthly, Quarterly, Half-Yearly & Yearly Suburban Railway Passes.',
              style: TextStyle(fontSize: 12, color: Colors.indigo.shade900, fontWeight: FontWeight.w600),
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
            InkWell(
              onTap: _showLocationOverrideDialog,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.my_location_rounded, size: 12, color: Colors.blue.shade900),
                    const SizedBox(width: 4),
                    Text(
                      'Fix / Set Location',
                      style: TextStyle(fontSize: 10, color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
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
                        Iterable<RailwayStation> options = textEditingValue.text.isEmpty
                            ? (_nearestStations.isNotEmpty ? _nearestStations : _stations)
                            : _stations.where((station) {
                                return station.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                              });
                        if (_toStation != null) {
                          options = options.where((s) => s.id != _toStation!.id);
                        }
                        return options;
                      },
                      onSelected: (RailwayStation selection) {
                        setState(() {
                          _fromStation = selection;
                        });
                        if (_stationTypeIndex == 0 &&
                            _nearestStations.isNotEmpty &&
                            !_nearestStations.any((s) => s.id == selection.id)) {
                          _showOutsideStationLimitDialog();
                        }
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        if (_fromController != textEditingController) {
                          _fromController = textEditingController;
                        }
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            hintText: 'Select Source Station (Search any station)',
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
