import 'package:flutter/material.dart';
import '../core/theme/loco_theme.dart';
import '../models/station.dart';
import '../models/ticket.dart';
import '../services/journey_guardian_service.dart';
import '../services/ticket_storage.dart';
import '../widgets/digital_ticket_inspector.dart';
import '../widgets/dynamic_ticket_card.dart';

class TicketsScreen extends StatefulWidget {
  final VoidCallback? onPlanJourneyTap;

  const TicketsScreen({super.key, this.onPlanJourneyTap});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> with SingleTickerProviderStateMixin {
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

  List<BookedTicket> _getFilteredTickets(int tabIndex) {
    switch (tabIndex) {
      case 0: // Active / Upcoming
        return _allTickets.where((t) => t.status == TicketStatus.upcoming).toList();
      case 1: // Completed / History
        return _allTickets.where((t) => t.status == TicketStatus.completed).toList();
      case 2: // Season Passes
        return _allTickets.where((t) => t.ticketType == TicketType.season).toList();
      case 3: // Suspicious / Flagged
        return _allTickets.where((t) => t.status == TicketStatus.suspicious).toList();
      default:
        return _allTickets;
    }
  }

  void _showInspector(BookedTicket ticket) {
    showDialog(
      context: context,
      builder: (context) => DigitalTicketInspector(
        ticket: ticket,
        onSimulateScan: () {
          _loadTickets();
        },
      ),
    );
  }

  void _startJourneyWithGuardian(BookedTicket ticket) {
    final bvi = RailwayStation(id: 'borivali', name: ticket.fromStationName, latitude: 19.2290, longitude: 72.8573);
    final ddr = RailwayStation(id: 'dadar', name: ticket.toStationName, latitude: 19.0192, longitude: 72.8438);

    JourneyGuardianService().startJourney(
      ticket: ticket,
      originStation: bvi,
      destinationStation: ddr,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: LocoColors.orange,
        content: Text('🛡️ Journey Guardian Active! Switched to Home tracking.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Ticket Wallet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: LocoColors.orange,
          indicatorWeight: 3,
          labelColor: LocoColors.orange,
          unselectedLabelColor: LocoColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
            Tab(text: 'Season'),
            Tab(text: 'Flagged'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: LocoColors.orange))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTicketsList(0),
                _buildTicketsList(1),
                _buildTicketsList(2),
                _buildTicketsList(3),
              ],
            ),
    );
  }

  Widget _buildTicketsList(int tabIndex) {
    final list = _getFilteredTickets(tabIndex);

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: LocoColors.orangeLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.confirmation_number_outlined, color: LocoColors.orange, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Tickets Here',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'You’re all clear. Booked journeys and active season passes will be safely accessible here offline.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: LocoColors.textMuted),
              ),
              const SizedBox(height: 20),
              if (widget.onPlanJourneyTap != null)
                ElevatedButton(
                  onPressed: widget.onPlanJourneyTap,
                  child: const Text('Plan a Journey'),
                ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final ticket = list[index];
        return DynamicTicketCard(
          ticket: ticket,
          onTap: () => _showInspector(ticket),
          onStartJourney: ticket.status == TicketStatus.upcoming
              ? () => _startJourneyWithGuardian(ticket)
              : null,
        );
      },
    );
  }
}
