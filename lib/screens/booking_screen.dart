import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/loco_theme.dart';
import '../models/station.dart';
import '../models/ticket.dart';
import '../services/journey_guardian_service.dart';
import '../services/payment_service.dart';
import '../services/ticket_storage.dart';
import '../widgets/digital_ticket_inspector.dart';

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
  bool _isProcessing = false;

  int _calculateFare() {
    int baseFare;

    if (_classType == 'SECOND') {
      int diff = widget.stationDifference;
      if (diff <= 3) {
        baseFare = 5;
      } else if (diff <= 6) {
        baseFare = 10;
      } else if (diff <= 9) {
        baseFare = 15;
      } else if (diff <= 12) {
        baseFare = 20;
      } else if (diff <= 15) {
        baseFare = 25;
      } else if (diff <= 18) {
        baseFare = 30;
      } else if (diff <= 24) {
        baseFare = 35;
      } else {
        baseFare = 40;
      }
    } else {
      // First class
      baseFare = 5 + 40;
    }

    if (_trainType == 'AC EMU TRAIN') baseFare += 45;
    if (_ticketType == 'RETURN') baseFare *= 2;

    int total = (baseFare * _adultCount) + ((baseFare ~/ 2) * _childCount);
    return total > 0 ? total : 5;
  }

  Future<void> _handleBookTicket() async {
    setState(() => _isProcessing = true);

    final fare = _calculateFare();
    final payment = await PaymentService.processPayment(
      amount: fare,
      method: PaymentMethod.upi,
    );

    if (!payment.success) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: LocoColors.error, content: Text(payment.message)),
      );
      return;
    }

    final rng = Random();
    final ticketCode = 'LOCO-${widget.fromStation.code}-${rng.nextInt(9000) + 1000}';
    final ticket = BookedTicket(
      id: ticketCode,
      fromStationName: widget.fromStation.name,
      fromStationCode: widget.fromStation.code,
      toStationName: widget.toStation.name,
      toStationCode: widget.toStation.code,
      ticketType: _ticketType == 'RETURN' ? TicketType.returnTicket : TicketType.journey,
      bookingType: BookingType.issue,
      trainType: _trainType,
      duration: 'SINGLE',
      classType: _classType,
      fare: fare,
      bookingDate: DateTime.now(),
      status: TicketStatus.upcoming,
      lifecycle: TicketLifecycle.active,
      distanceKm: widget.stationDifference * 3.5,
      passengerName: 'Aayush Sinha',
      passengerAddress: 'Mumbai Suburban',
      passengerIdType: 'PAN Card',
      passengerIdNumber: 'SENP******',
    );

    await TicketStorage.addTicket(ticket);

    // Auto-start Journey Guardian
    JourneyGuardianService().startJourney(
      ticket: ticket,
      originStation: widget.fromStation,
      destinationStation: widget.toStation,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: LocoColors.success, size: 26),
            SizedBox(width: 10),
            Text('Ticket Confirmed!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.fromStation.name} → ${widget.toStation.name}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: LocoColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Pass ID: $ticketCode  •  Fare: ₹$fare\nJourney Guardian is now active.',
              style: const TextStyle(fontSize: 13, color: LocoColors.textSecondary),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context); // dialog
              showDialog(
                context: context,
                builder: (context) => DigitalTicketInspector(ticket: ticket),
              );
            },
            child: const Text('View Pass QR'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // dialog
              Navigator.pop(context); // booking screen
            },
            child: const Text('Track Journey'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Book Ticket', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildChoiceChip('ORDINARY', _trainType == 'ORDINARY', (v) => setState(() => _trainType = v)),
                        const SizedBox(width: 12),
                        _buildChoiceChip('AC EMU TRAIN', _trainType == 'AC EMU TRAIN', (v) => setState(() => _trainType = v)),
                      ],
                    ),

                    const SizedBox(height: 22),
                    _buildSectionTitle('Ticket Type'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildChoiceChip('JOURNEY', _ticketType == 'JOURNEY', (v) => setState(() => _ticketType = v)),
                        const SizedBox(width: 12),
                        _buildChoiceChip('RETURN', _ticketType == 'RETURN', (v) => setState(() => _ticketType = v)),
                      ],
                    ),

                    const SizedBox(height: 22),
                    _buildSectionTitle('Class Type'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildChoiceChip('SECOND', _classType == 'SECOND', (v) => setState(() => _classType = v)),
                        const SizedBox(width: 12),
                        _buildChoiceChip('FIRST', _classType == 'FIRST', (v) => setState(() => _classType = v)),
                      ],
                    ),

                    const SizedBox(height: 22),
                    _buildSectionTitle('Passengers'),
                    const SizedBox(height: 10),
                    _buildPassengerCounter('Adults', _adultCount, (val) => setState(() => _adultCount = val)),
                    const SizedBox(height: 10),
                    _buildPassengerCounter('Children (Half Fare)', _childCount, (val) => setState(() => _childCount = val)),
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

  Widget _buildRouteHeader() {
    return Container(
      color: LocoColors.canvas,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.fromStation.code, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: LocoColors.textPrimary)),
              Text(widget.fromStation.name, style: const TextStyle(fontSize: 12, color: LocoColors.textSecondary)),
            ],
          ),
          const Icon(Icons.arrow_forward, color: LocoColors.orange, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(widget.toStation.code, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: LocoColors.textPrimary)),
              Text(widget.toStation.name, style: const TextStyle(fontSize: 12, color: LocoColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
    );
  }

  Widget _buildChoiceChip(String label, bool isSelected, Function(String) onSelect) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? LocoColors.orangeLight : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? LocoColors.orange : LocoColors.border, width: isSelected ? 1.5 : 1),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected ? LocoColors.orange : LocoColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPassengerCounter(String label, int count, Function(int) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: LocoColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LocoColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: count > (label.startsWith('Adult') ? 1 : 0) ? () => onChanged(count - 1) : null,
              ),
              Text('$count', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20, color: LocoColors.orange),
                onPressed: count < 4 ? () => onChanged(count + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final fare = _calculateFare();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: LocoColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('TOTAL FARE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: LocoColors.textMuted)),
              Text('₹$fare', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: LocoColors.orange)),
            ],
          ),
          ElevatedButton(
            onPressed: _isProcessing ? null : _handleBookTicket,
            style: ElevatedButton.styleFrom(
              backgroundColor: LocoColors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            child: _isProcessing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Pay & Book Pass', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
