import 'package:flutter/material.dart';
import '../models/ticket.dart';
import '../services/ticket_storage.dart';
import '../widgets/mobile_qr_scanner_modal.dart';
import 'season_booking_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<BookedTicket> _allTickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTickets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    final tickets = await TicketStorage.getTickets();
    setState(() {
      _allTickets = tickets;
      _isLoading = false;
    });
  }

  List<BookedTicket> _filterTickets(TicketStatus? status) {
    if (status == null) return _allTickets;
    return _allTickets.where((t) => t.status == status).toList();
  }

  void _showTicketDetailsDialog(BookedTicket ticket) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'UTS: ${ticket.id}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0066FF)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Route Display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0066FF), Color(0xFF0044B3)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ticket.fromStationName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          '--- ${ticket.distanceKm.toInt()} km --->',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        Text(
                          ticket.toStationName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(ticket.fromStationCode, style: const TextStyle(color: Colors.white70)),
                        Text(ticket.toStationCode, style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Barcode / QR Simulation
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_2, size: 100, color: Color(0xFF1E293B)),
                      const SizedBox(height: 8),
                      Text(
                        'VALID E-TICKET (${ticket.ticketType.name.toUpperCase()})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Details List
              _buildDetailRow('Class', ticket.classType),
              _buildDetailRow('Train Type', ticket.trainType),
              _buildDetailRow('Duration', ticket.duration),
              _buildDetailRow('Fare Paid', '₹ ${ticket.fare}'),
              _buildDetailRow('Passenger', ticket.passengerName),
              _buildDetailRow('ID Details', '${ticket.passengerIdType} (${ticket.passengerIdNumber})'),
              _buildDetailRow('Booking Date', '${ticket.bookingDate.day}/${ticket.bookingDate.month}/${ticket.bookingDate.year}'),
              if (ticket.s2CellToken != null)
                _buildDetailRow('S2 Spatial Token', ticket.s2CellToken!),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcomingList = _filterTickets(TicketStatus.upcoming);
    final completedList = _filterTickets(TicketStatus.completed);
    final cancelledList = _filterTickets(TicketStatus.cancelled);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0066FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Bookings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            tooltip: 'Verify Ticket QR',
            onPressed: () {
              MobileQrScannerModal.show(
                context,
                onStationScanned: (station, distanceKm) {
                  if (_allTickets.isNotEmpty) {
                    _showTicketDetailsDialog(_allTickets.first);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✓ Scanned: ${station.name}')),
                    );
                  }
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadTickets,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'Upcoming (${upcomingList.length})'),
            Tab(text: 'Completed (${completedList.length})'),
            Tab(text: 'Cancelled (${cancelledList.length})'),
            Tab(text: 'All (${_allTickets.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTicketListView(upcomingList),
                _buildTicketListView(completedList),
                _buildTicketListView(cancelledList),
                _buildTicketListView(_allTickets),
              ],
            ),
    );
  }

  Widget _buildTicketListView(List<BookedTicket> tickets) {
    if (tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No Tickets Found.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text('Swipe down to refresh.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTickets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: tickets.length,
        itemBuilder: (context, index) {
          final ticket = tickets[index];
          return _buildTicketCard(ticket);
        },
      ),
    );
  }

  Widget _buildTicketCard(BookedTicket ticket) {
    final dateStr = 'Wed, ${ticket.bookingDate.day} ${_getMonthName(ticket.bookingDate.month)} ${ticket.bookingDate.year.toString().substring(2)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.pink.shade200),
                      ),
                      child: Text(
                        ticket.ticketType == TicketType.season ? 'Season' : 'Unreserved',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.pink.shade700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'UTS: ${ticket.id}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                Text(
                  ticket.status.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: ticket.status == TicketStatus.upcoming
                        ? Colors.green
                        : (ticket.status == TicketStatus.completed ? Colors.blue : Colors.red),
                  ),
                ),
              ],
            ),
          ),

          // Card Body: Route & Date
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ticket Type',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      'Booking Date',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ticket.ticketType == TicketType.season ? 'SEASON' : 'JOURNEY',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Station Route Line
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ticket.fromStationName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                    ),
                    Row(
                      children: [
                        Container(width: 20, height: 1, color: Colors.grey.shade400),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            '${ticket.distanceKm.toInt()} km',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ),
                        Container(width: 20, height: 1, color: Colors.grey.shade400),
                        const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                      ],
                    ),
                    Text(
                      ticket.toStationName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Card Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SeasonBookingScreen(),
                        ),
                      );
                    },
                    child: const Text('Book Again', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0066FF))),
                  ),
                ),
                Container(width: 1, height: 24, color: Colors.grey.shade300),
                Expanded(
                  child: TextButton(
                    onPressed: () => _showTicketDetailsDialog(ticket),
                    child: const Text('View Details', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0066FF))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
