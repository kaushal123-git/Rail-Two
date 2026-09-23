import 'package:flutter/material.dart';
import '../models/station.dart';

class BookingScreen extends StatefulWidget {
  final RailwayStation fromStation;
  final RailwayStation toStation;
  final int stationDifference;

  const BookingScreen({
    super.key,
    required this.fromStation,
    required this.toStation,
    required this.stationDifference,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String _trainType = 'ORDINARY';
  String _ticketType = 'JOURNEY';
  int _adultCount = 1;
  int _childCount = 0;
  String _classType = 'SECOND';
  bool _availConcession = false;

  int _calculateFare() {
    int baseFare;
    
    if (_classType == 'SECOND') {
      int diff = widget.stationDifference;
      if (diff <= 3) baseFare = 5;
      else if (diff <= 6) baseFare = 10;
      else if (diff <= 9) baseFare = 15;
      else if (diff <= 12) baseFare = 20;
      else if (diff <= 15) baseFare = 25;
      else if (diff <= 18) baseFare = 30;
      else if (diff <= 24) baseFare = 35;
      else baseFare = 40; // Default for > 24 stations
    } else {
      // First class
      baseFare = 5 + 40;
    }

    if (_trainType == 'AC EMU TRAIN') baseFare += 45;
    if (_ticketType == 'RETURN') baseFare *= 2;
    
    int total = (baseFare * _adultCount) + ((baseFare ~/ 2) * _childCount);
    return total > 0 ? total : 5; // Minimum fare 5
  }

  String _getStationCode(String id) {
    if (id.length > 3) {
      // Create a dummy code from consonants or just use the first 3-4 chars
      String code = id.replaceAll(RegExp(r'[aeiouAEIOU\s-]'), '').toUpperCase();
      return code.length >= 3 ? code.substring(0, 3) : id.toUpperCase().substring(0, 3);
    }
    return id.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildRouteHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Train Type'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildChoiceChip('ORDINARY', _trainType == 'ORDINARY', (v) => setState(() => _trainType = v)),
                        const SizedBox(width: 12),
                        _buildChoiceChip('AC EMU TRAIN', _trainType == 'AC EMU TRAIN', (v) => setState(() => _trainType = v)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Ticket Type'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildChoiceChip('JOURNEY', _ticketType == 'JOURNEY', (v) => setState(() => _ticketType = v)),
                        const SizedBox(width: 12),
                        _buildChoiceChip('RETURN', _ticketType == 'RETURN', (v) => setState(() => _ticketType = v)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildPassengerCounter('Adult', _adultCount, (val) => setState(() => _adultCount = val), min: 1),
                    const SizedBox(height: 12),
                    _buildPassengerCounter('Child', _childCount, (val) => setState(() => _childCount = val), min: 0),
                    const SizedBox(height: 8),
                    Text(
                      'Aged between 5 and 12 years on the day of Travel',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Class'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildChoiceChip('SECOND', _classType == 'SECOND', (v) => setState(() => _classType = v)),
                        const SizedBox(width: 12),
                        _buildChoiceChip('FIRST', _classType == 'FIRST', (v) => setState(() => _classType = v)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _availConcession = !_availConcession),
                          child: Icon(
                            _availConcession ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: _availConcession ? const Color(0xFF0066FF) : Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Avail Concession',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0066FF),
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unreserved Journey',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          Text(
            'E-Ticket',
            style: TextStyle(color: Colors.blue.shade100, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteHeader() {
    String fromCode = _getStationCode(widget.fromStation.id);
    String toCode = _getStationCode(widget.toStation.id);

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.fromStation.name.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  fromCode,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Icon(Icons.arrow_right_alt, color: Color(0xFF94A3B8)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.toStation.name.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  toCode,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xFF475569),
      ),
    );
  }

  Widget _buildChoiceChip(String label, bool isSelected, Function(String) onTap) {
    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0066FF) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF0066FF) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildPassengerCounter(String label, int value, Function(int) onChanged, {required int min}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: value > min ? () => onChanged(value - 1) : null,
                child: Icon(Icons.remove, color: value > min ? const Color(0xFF0066FF) : Colors.grey.shade400, size: 24),
              ),
              const SizedBox(width: 16),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFF0066FF),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  value.toString(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: value < 4 ? () => onChanged(value + 1) : null,
                child: Icon(Icons.add, color: value < 4 ? const Color(0xFF0066FF) : Colors.grey.shade400, size: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: const Color(0xFFF8FAFC),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_activity, color: Color(0xFF0066FF)),
                  const SizedBox(width: 12),
                  const Text(
                    'Fare',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹ ${_calculateFare()}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1E293B)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Fare Breakup',
                      style: TextStyle(fontSize: 10, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16.0),
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ticket Booked Successfully!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Book Now',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
