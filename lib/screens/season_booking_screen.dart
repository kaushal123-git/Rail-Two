import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/loco_theme.dart';
import '../models/station.dart';
import '../models/ticket.dart';
import '../services/ticket_storage.dart';
import 'main_navigation_shell.dart';

class SeasonBookingScreen extends StatefulWidget {
  final RailwayStation? initialFromStation;
  final RailwayStation? initialToStation;
  final String seasonType;
  final String bookingFor;
  final String dateSelection;

  const SeasonBookingScreen({
    super.key,
    this.initialFromStation,
    this.initialToStation,
    this.seasonType = 'ISSUE',
    this.bookingFor = 'Self',
    this.dateSelection = 'Next Date',
  });

  @override
  State<SeasonBookingScreen> createState() => _SeasonBookingScreenState();
}

class _SeasonBookingScreenState extends State<SeasonBookingScreen> {
  late RailwayStation _fromStation;
  late RailwayStation _toStation;
  late String _seasonType;
  late String _bookingFor;
  late String _dateSelection;

  // Selected configurations matching Screenshot 2
  String _trainType = 'ORDINARY'; // ORDINARY, MAIL/EXP, SUPERFAST, AC EMU TRAIN
  String _duration = 'MONTHLY'; // MONTHLY, QUARTERLY, HALF YEARLY, YEARLY
  String _classType = 'SECOND'; // SECOND, FIRST
  bool _availConcession = false;

  // Passenger state
  String _passengerName = 'Rakhi sinha';
  String _passengerAgeGender = '46 yrs, F';
  String _passengerAddress =
      '006-yashwant sneh, YK Nagar NX Virar West, virar west, Thane, India';
  bool _isIdAttached = true;
  String? _attachedPhotoPath;

  @override
  void initState() {
    super.initState();
    _seasonType = widget.seasonType;
    _bookingFor = widget.bookingFor;
    _dateSelection = widget.dateSelection;

    _fromStation = widget.initialFromStation ??
        RailwayStation(
          id: 'virar',
          name: 'VIRAR',
          latitude: 19.4559,
          longitude: 72.8106,
        );

    _toStation = widget.initialToStation ??
        RailwayStation(
          id: 'borivali',
          name: 'BORIVALI',
          latitude: 19.2307,
          longitude: 72.8567,
        );
  }

  int _calculateFare() {
    // Base Monthly Second Class fare matching reference = ₹ 215
    int baseFare = 215;
    if (_classType == 'FIRST') baseFare = 670;
    if (_trainType == 'AC EMU TRAIN') baseFare = 1765;

    int fare = baseFare;
    switch (_duration) {
      case 'QUARTERLY':
        fare = (baseFare * 2.7).round();
        break;
      case 'HALF YEARLY':
        fare = (baseFare * 5.2).round();
        break;
      case 'YEARLY':
        fare = (baseFare * 9.8).round();
        break;
      default:
        // MONTHLY
        fare = baseFare;
        break;
    }

    if (_availConcession) {
      fare = (fare * 0.5).round();
    }

    return fare;
  }

  void _showOthersTrainTypeModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Train Type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('SUPERFAST', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: _trainType == 'SUPERFAST'
                    ? const Icon(Icons.check, color: Color(0xFF0066FF))
                    : null,
                onTap: () {
                  setState(() => _trainType = 'SUPERFAST');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('AC EMU TRAIN', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: _trainType == 'AC EMU TRAIN'
                    ? const Icon(Icons.check, color: Color(0xFF0066FF))
                    : null,
                onTap: () {
                  setState(() => _trainType = 'AC EMU TRAIN');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFareBreakupDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Fare Breakup',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              _buildBreakupRow('Route', '${_fromStation.name} → ${_toStation.name}'),
              _buildBreakupRow('Type', _seasonType),
              _buildBreakupRow('Booking For', _bookingFor),
              _buildBreakupRow('Train Type', _trainType),
              _buildBreakupRow('Duration', _duration),
              _buildBreakupRow('Class', _classType),
              _buildBreakupRow('Date Mode', _dateSelection),
              _buildBreakupRow(
                'Concession Applied',
                _availConcession ? '50% Concession' : 'None',
              ),
              _buildBreakupRow(
                'ID Verified',
                _isIdAttached ? 'Yes' : 'Pending',
              ),
              const Divider(thickness: 1.5),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Payable',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₹ ${_calculateFare()}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: LocoColors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBreakupRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  void _showPassengerEditDialog() {
    final nameCtrl = TextEditingController(text: _passengerName);
    final ageCtrl = TextEditingController(text: _passengerAgeGender);
    final addrCtrl = TextEditingController(text: _passengerAddress);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Update Passenger Details', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Passenger Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ageCtrl,
                decoration: const InputDecoration(labelText: 'Age & Gender (e.g. 46 yrs, F)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addrCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _passengerName = nameCtrl.text;
                _passengerAgeGender = ageCtrl.text;
                _passengerAddress = addrCtrl.text;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPhotoPickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update Passenger Photo / ID',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
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
                        color: LocoColors.orangeSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: LocoColors.orange.withValues(alpha: 0.3)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.camera_alt, color: LocoColors.orange, size: 32),
                          SizedBox(height: 8),
                          Text(
                            'Capture Image',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: LocoColors.orange,
                            ),
                          ),
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
                        color: LocoColors.orangeSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: LocoColors.orange.withValues(alpha: 0.3)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.photo_library, color: LocoColors.orange, size: 32),
                          SizedBox(height: 8),
                          Text(
                            'Select Image File',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: LocoColors.orange,
                            ),
                          ),
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
    final randomDigits = Random().nextInt(900000) + 100000;
    final utsCode = 'XODHE$randomDigits';

    final newTicket = BookedTicket(
      id: utsCode,
      fromStationName: _fromStation.name.toUpperCase(),
      fromStationCode: _fromStation.code,
      toStationName: _toStation.name.toUpperCase(),
      toStationCode: _toStation.code,
      ticketType: TicketType.season,
      bookingType: _seasonType == 'RENEW' ? BookingType.renew : BookingType.issue,
      trainType: _trainType,
      duration: _duration,
      classType: _classType,
      fare: fareAmount.toInt(),
      bookingDate: DateTime.now(),
      status: TicketStatus.upcoming,
      distanceKm: 22.0,
      passengerName: _passengerName,
      passengerAddress: _passengerAddress,
      passengerIdType: 'PAN Card',
      passengerIdNumber: 'SENP******',
      passengerPhotoPath: _attachedPhotoPath,
      s2CellToken: s2Token,
      s2CellId: s2Id,
      latitude: lat,
      longitude: lng,
      locationAccuracyMeters: position?.accuracy ?? 10.0,
      geofenceVerified: true,
    );

    await TicketStorage.addTicket(newTicket);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Season Ticket Booked Successfully! UTS Code: $utsCode'),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigationShell(initialIndex: 2)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Season Ticket Booking',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1E293B)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Header Banner: Route Display (VIRAR VR -> BORIVALI BVI)
                    _buildRouteHeader(),
                    const SizedBox(height: 24),

                    // Train Type Section
                    const Text(
                      'Train Type',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildPillChip(
                          label: 'ORDINARY',
                          isSelected: _trainType == 'ORDINARY',
                          onTap: () => setState(() => _trainType = 'ORDINARY'),
                        ),
                        const SizedBox(width: 10),
                        _buildPillChip(
                          label: 'MAIL/EXP',
                          isSelected: _trainType == 'MAIL/EXP',
                          onTap: () => setState(() => _trainType = 'MAIL/EXP'),
                        ),
                        const SizedBox(width: 10),
                        _buildDropdownPill(
                          label: _trainType != 'ORDINARY' && _trainType != 'MAIL/EXP'
                              ? _trainType
                              : 'Others',
                          isSelected: _trainType != 'ORDINARY' && _trainType != 'MAIL/EXP',
                          onTap: _showOthersTrainTypeModal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Duration Section
                    const Text(
                      'Duration',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPillChip(
                            label: 'MONTHLY',
                            isSelected: _duration == 'MONTHLY',
                            onTap: () => setState(() => _duration = 'MONTHLY'),
                          ),
                          const SizedBox(width: 10),
                          _buildPillChip(
                            label: 'QUARTERLY',
                            isSelected: _duration == 'QUARTERLY',
                            onTap: () => setState(() => _duration = 'QUARTERLY'),
                          ),
                          const SizedBox(width: 10),
                          _buildPillChip(
                            label: 'HALF YEARLY',
                            isSelected: _duration == 'HALF YEARLY',
                            onTap: () => setState(() => _duration = 'HALF YEARLY'),
                          ),
                          const SizedBox(width: 10),
                          _buildPillChip(
                            label: 'YEARLY',
                            isSelected: _duration == 'YEARLY',
                            onTap: () => setState(() => _duration = 'YEARLY'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Passenger Details Card Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Passenger Details',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        InkWell(
                          onTap: _showPassengerEditDialog,
                          child: const Text(
                            '+ Add ID',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: LocoColors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildPassengerDetailsCard(),
                    const SizedBox(height: 24),

                    // Class Section
                    const Text(
                      'Class',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildPillChip(
                          label: 'SECOND',
                          isSelected: _classType == 'SECOND',
                          onTap: () => setState(() => _classType = 'SECOND'),
                        ),
                        const SizedBox(width: 12),
                        _buildPillChip(
                          label: 'FIRST',
                          isSelected: _classType == 'FIRST',
                          onTap: () => setState(() => _classType = 'FIRST'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Avail Concession Section
                    InkWell(
                      onTap: () => setState(() => _availConcession = !_availConcession),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          children: [
                            Icon(
                              _availConcession
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: _availConcession
                                  ? LocoColors.orange
                                  : const Color(0xFF64748B),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Avail Concession',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Sticky Bottom Bar matching Screenshot 2
            _buildStickyBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteHeader() {
    final fromName = _fromStation.name.toUpperCase();
    final fromCode = _fromStation.code;
    final toName = _toStation.name.toUpperCase();
    final toCode = _toStation.code;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: From Station
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fromName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                fromCode,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),

          // Center: Arrow
          const Icon(
            Icons.arrow_forward_rounded,
            color: Color(0xFF64748B),
            size: 22,
          ),

          // Right: To Station
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                toName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                toCode,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: LocoColors.border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, color: LocoColors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_passengerName. $_passengerAgeGender',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: LocoColors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _passengerAddress,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Right Avatar Box with Camera Badge
          GestureDetector(
            onTap: _showPhotoPickerModal,
            child: Container(
              width: 72,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.person,
                    size: 46,
                    color: LocoColors.textPrimary,
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: LocoColors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 13,
                      ),
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

  Widget _buildPillChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? LocoColors.orange : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? LocoColors.orange : const Color(0xFFCBD5E1),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? LocoColors.orange : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? LocoColors.orange : const Color(0xFFCBD5E1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF475569),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isSelected ? Colors.white : LocoColors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBottomBar() {
    final fare = _calculateFare();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.confirmation_number_rounded,
                    color: LocoColors.orange,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Total Fare',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹ $fare',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  InkWell(
                    onTap: _showFareBreakupDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Text(
                        'Fare Breakup',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _processProceedToPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: LocoColors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Proceed to Pay',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
