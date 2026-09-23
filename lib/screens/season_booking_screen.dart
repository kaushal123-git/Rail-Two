import 'dart:math';
import 'package:flutter/material.dart';
import '../models/station.dart';
import '../models/ticket.dart';
import '../services/ticket_storage.dart';
import 'my_bookings_screen.dart';

class SeasonBookingScreen extends StatefulWidget {
  final RailwayStation? initialFromStation;
  final RailwayStation? initialToStation;

  const SeasonBookingScreen({
    super.key,
    this.initialFromStation,
    this.initialToStation,
  });

  @override
  State<SeasonBookingScreen> createState() => _SeasonBookingScreenState();
}

class _SeasonBookingScreenState extends State<SeasonBookingScreen> {
  // Mode selection
  bool _isSeasonMode = true; // true = Season, false = Normal
  String _seasonType = 'ISSUE'; // ISSUE, RENEW
  String _bookingFor = 'Self'; // Self, Others
  String _locationOption = 'Outside Station'; // Outside Station, At Station

  // Selected Stations
  RailwayStation _fromStation = RailwayStation(
    id: 'virar',
    name: 'VIRAR',
    latitude: 19.4559,
    longitude: 72.8106,
  );

  RailwayStation _toStation = RailwayStation(
    id: 'borivali',
    name: 'BORIVALI',
    latitude: 19.2307,
    longitude: 72.8567,
  );

  // Station lists for search modal
  final List<Map<String, String>> _availableStations = [
    {'name': 'VIRAR', 'code': 'VR', 'city': 'MUMBAI, MAHARASHTRA'},
    {'name': 'VASAI ROAD', 'code': 'BSR', 'city': 'MUMBAI, MAHARASHTRA'},
    {'name': 'BORIVALI', 'code': 'BVI', 'city': 'MUMBAI, MAHARASHTRA'},
    {'name': 'DAHISAR', 'code': 'DIC', 'city': 'MAHARASHTRA'},
    {'name': 'RAJA-KI-MANDI', 'code': 'RKM', 'city': 'AGRA, UTTAR PRADESH'},
  ];

  // Season Ticket Fields
  String _trainType = 'ORDINARY'; // ORDINARY, MAIL/EXP, SUPERFAST, AC EMU TRAIN
  String _duration = 'MONTHLY'; // MONTHLY, QUARTERLY, HALF YEARLY, YEARLY, FORTNIGHTLY
  String _classType = 'SECOND'; // SECOND, FIRST
  bool _availConcession = false;
  bool _isIdAttached = false;
  String? _attachedPhotoPath;

  // Renew UTS number controller
  final TextEditingController _utsRenewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialFromStation != null) {
      _fromStation = widget.initialFromStation!;
    }
    if (widget.initialToStation != null) {
      _toStation = widget.initialToStation!;
    }
  }

  @override
  void dispose() {
    _utsRenewController.dispose();
    super.dispose();
  }

  int _calculateFare() {
    if (!_isSeasonMode) {
      // Normal journey fare
      int base = 5;
      if (_classType == 'FIRST') base += 45;
      if (_trainType == 'AC EMU TRAIN') base += 45;
      return base;
    }

    // Season ticket fare logic matching reference video
    int fare = 215; // Base Monthly Second Class
    if (_classType == 'FIRST') fare = 670;
    if (_trainType == 'AC EMU TRAIN') fare = 1765;

    // Duration multipliers
    switch (_duration) {
      case 'QUARTERLY':
        fare = (fare * 2.7).round();
        break;
      case 'HALF YEARLY':
        fare = (fare * 5.2).round();
        break;
      case 'YEARLY':
        fare = (fare * 9.8).round();
        break;
      case 'FORTNIGHTLY':
        fare = (fare * 0.6).round();
        break;
      default:
        // MONTHLY
        break;
    }

    if (_availConcession) {
      fare = (fare * 0.5).round();
    }

    return fare;
  }

  String _getStationCode(String name) {
    for (var s in _availableStations) {
      if (s['name']!.toUpperCase() == name.toUpperCase()) {
        return s['code']!;
      }
    }
    return name.length >= 3 ? name.substring(0, 3).toUpperCase() : name.toUpperCase();
  }

  void _showStationPicker({required bool isFrom}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _availableStations.where((s) {
              final query = searchQuery.toLowerCase();
              return s['name']!.toLowerCase().contains(query) || s['code']!.toLowerCase().contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isFrom ? 'Search Source Station' : 'Search Destination Station',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Select Station',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: const Icon(Icons.mic, color: Color(0xFF0066FF)),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Recent Station Searches',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final station = filtered[index];
                        return ListTile(
                          title: Text(
                            '${station['name']} - ${station['code']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(station['city']!),
                          trailing: const Icon(Icons.north_west, size: 16, color: Colors.grey),
                          onTap: () {
                            setState(() {
                              final newStation = RailwayStation(
                                id: station['code']!.toLowerCase(),
                                name: station['name']!,
                                latitude: 19.3,
                                longitude: 72.8,
                              );
                              if (isFrom) {
                                _fromStation = newStation;
                              } else {
                                _toStation = newStation;
                              }
                            });
                            Navigator.pop(context);
                            _validateStationPair();
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

  void _validateStationPair() {
    // Check if invalid pair e.g. Same stations
    if (_fromStation.name.toUpperCase() == _toStation.name.toUpperCase()) {
      _showAlertDialog(
        title: 'Error',
        message: 'Source and Destination stations cannot be the same.',
      );
    }
  }

  void _showAlertDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showPhotoPickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Capture/Select Image',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isIdAttached = true;
                        _attachedPhotoPath = 'camera_photo';
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ID Photo captured successfully!')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: const [
                          Icon(Icons.camera_alt, color: Color(0xFF0066FF), size: 32),
                          SizedBox(height: 8),
                          Text('Capture Image', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0066FF))),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isIdAttached = true;
                        _attachedPhotoPath = 'gallery_photo';
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ID Image selected successfully!')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: const [
                          Icon(Icons.photo_library, color: Color(0xFF0066FF), size: 32),
                          SizedBox(height: 8),
                          Text('Select Image File', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0066FF))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processProceedToPay() async {
    if (_isSeasonMode && !_isIdAttached && _seasonType == 'ISSUE') {
      _showAlertDialog(
        title: 'Identity Required',
        message: 'Kindly enter your identity type and corresponding ID number to continue.',
      );
      return;
    }

    // Generate ticket
    final randomDigits = Random().nextInt(900000) + 100000;
    final utsCode = 'XODHE${randomDigits}';
    final fromCode = _getStationCode(_fromStation.name);
    final toCode = _getStationCode(_toStation.name);

    final newTicket = BookedTicket(
      id: utsCode,
      fromStationName: _fromStation.name,
      fromStationCode: fromCode,
      toStationName: _toStation.name,
      toStationCode: toCode,
      ticketType: _isSeasonMode ? TicketType.season : TicketType.journey,
      bookingType: _seasonType == 'RENEW' ? BookingType.renew : BookingType.issue,
      trainType: _trainType,
      duration: _isSeasonMode ? _duration : 'SINGLE',
      classType: _classType,
      fare: _calculateFare(),
      bookingDate: DateTime.now(),
      status: TicketStatus.upcoming,
      distanceKm: 3.0,
      passengerName: 'Rakhi sinha',
      passengerAddress: '006-yashwant sneh, YK Nagar NX Virar West, Thane, India',
      passengerIdType: 'PAN Card',
      passengerIdNumber: 'SENP******',
      passengerPhotoPath: _attachedPhotoPath,
    );

    await TicketStorage.addTicket(newTicket);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ticket Booked Successfully! UTS Code: $utsCode'),
        backgroundColor: Colors.green,
      ),
    );

    // Navigate to My Bookings Screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MyBookingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0066FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isSeasonMode ? 'Unreserved Season Ticket' : 'Unreserved E-Ticket',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode Segmented Control (Normal | Season)
            Container(
              color: const Color(0xFF0066FF),
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isSeasonMode = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_isSeasonMode ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Normal',
                            style: TextStyle(
                              color: !_isSeasonMode ? const Color(0xFF0066FF) : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isSeasonMode = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _isSeasonMode ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Season',
                            style: TextStyle(
                              color: _isSeasonMode ? const Color(0xFF0066FF) : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location Option (Outside Station | At Station)
                    Row(
                      children: [
                        _buildRadioChip('Outside Station', _locationOption == 'Outside Station', (v) => setState(() => _locationOption = v)),
                        const SizedBox(width: 12),
                        _buildRadioChip('At Station', _locationOption == 'At Station', (v) => setState(() => _locationOption = v)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_isSeasonMode) ...[
                      // Season Type (ISSUE | RENEW)
                      Row(
                        children: [
                          const Text('Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          _buildChoiceChip('ISSUE', _seasonType == 'ISSUE', (v) => setState(() => _seasonType = v)),
                          const SizedBox(width: 8),
                          _buildChoiceChip('RENEW', _seasonType == 'RENEW', (v) => setState(() => _seasonType = v)),
                          const Spacer(),
                          const Text('Booking For: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          _buildChoiceChip('Self', _bookingFor == 'Self', (v) => setState(() => _bookingFor = v)),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_isSeasonMode && _seasonType == 'RENEW') ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Enter Counter Ticket UTS Number', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _utsRenewController,
                              decoration: const InputDecoration(
                                hintText: 'e.g. XODHEGL014',
                                border: OutlineInputBorder(),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Source Station Card
                    _buildStationCard(
                      label: 'From',
                      stationName: '${_getStationCode(_fromStation.name)} - ${_fromStation.name}',
                      onTap: () => _showStationPicker(isFrom: true),
                    ),
                    const SizedBox(height: 12),

                    // Destination Station Card
                    _buildStationCard(
                      label: 'To',
                      stationName: _toStation.name.isEmpty
                          ? 'Select Destination'
                          : '${_getStationCode(_toStation.name)} - ${_toStation.name}',
                      onTap: () => _showStationPicker(isFrom: false),
                    ),
                    const SizedBox(height: 20),

                    // Train Type Selection
                    const Text('Train Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChoiceChip('ORDINARY', _trainType == 'ORDINARY', (v) => setState(() => _trainType = v)),
                        _buildChoiceChip('MAIL/EXP', _trainType == 'MAIL/EXP', (v) => setState(() => _trainType = v)),
                        _buildChoiceChip('AC EMU TRAIN', _trainType == 'AC EMU TRAIN', (v) => setState(() => _trainType = v)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (_isSeasonMode) ...[
                      // Duration Selection
                      const Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildChoiceChip('MONTHLY', _duration == 'MONTHLY', (v) => setState(() => _duration = v)),
                            const SizedBox(width: 8),
                            _buildChoiceChip('QUARTERLY', _duration == 'QUARTERLY', (v) => setState(() => _duration = v)),
                            const SizedBox(width: 8),
                            _buildChoiceChip('HALF YEARLY', _duration == 'HALF YEARLY', (v) => setState(() => _duration = v)),
                            const SizedBox(width: 8),
                            _buildChoiceChip('YEARLY', _duration == 'YEARLY', (v) => setState(() => _duration = v)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Class Selection
                    const Text('Class', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildChoiceChip('SECOND', _classType == 'SECOND', (v) => setState(() => _classType = v)),
                        const SizedBox(width: 12),
                        _buildChoiceChip('FIRST', _classType == 'FIRST', (v) => setState(() => _classType = v)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Passenger Details Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Passenger Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              TextButton.icon(
                                onPressed: _showPhotoPickerModal,
                                icon: Icon(
                                  _isIdAttached ? Icons.check_circle : Icons.camera_alt,
                                  color: _isIdAttached ? Colors.green : const Color(0xFF0066FF),
                                ),
                                label: Text(
                                  _isIdAttached ? 'ID Attached' : '+ Add ID',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _isIdAttached ? Colors.green : const Color(0xFF0066FF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          Row(
                            children: [
                              const Icon(Icons.person, color: Color(0xFF0066FF)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Rakhi sinha, 46 yrs, F', style: TextStyle(fontWeight: FontWeight.bold)),
                                    SizedBox(height: 4),
                                    Text(
                                      '006-yashwant sneh, YK Nagar NX Virar West, Thane, India',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Concession checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _availConcession,
                          onChanged: (v) => setState(() => _availConcession = v ?? false),
                          activeColor: const Color(0xFF0066FF),
                        ),
                        const Text('Avail Concession', style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom Bar with Dynamic Fare and Proceed to Pay button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.receipt_long, color: Color(0xFF0066FF)),
                          SizedBox(width: 8),
                          Text('Total Fare', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text(
                        '₹ ${_calculateFare()}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0066FF)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _processProceedToPay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0066FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                      child: const Text('Proceed to Pay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationCard({required String label, required String stationName, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Row(
          children: [
            Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                stationName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF0066FF)),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioChip(String label, bool isSelected, Function(String) onTap) {
    return GestureDetector(
      onTap: () => onTap(label),
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.info : Icons.info_outline,
            size: 18,
            color: isSelected ? const Color(0xFF0066FF) : Colors.grey,
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? const Color(0xFF0066FF) : Colors.grey.shade300),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0066FF) : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(String label, bool isSelected, Function(String) onTap) {
    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0066FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0066FF) : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade800,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
