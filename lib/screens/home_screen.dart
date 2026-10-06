import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants/loco_branding.dart';
import '../core/theme/loco_theme.dart';
import '../models/ticket.dart';
import '../services/auth_service.dart';
import '../services/loco_assist_service.dart';
import '../services/station_state_service.dart';
import '../services/ticket_storage.dart';
import '../widgets/digital_ticket_inspector.dart';
import '../widgets/rail_ai_sheet.dart';
import '../models/journey.dart';
import '../services/journey_guardian_service.dart';
import '../services/location_service.dart';
import '../widgets/journey_guardian_card.dart';
import 'booking_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int tabIndex)? onSwitchTab;

  const HomeScreen({super.key, this.onSwitchTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StationStateService _stationState = StationStateService();

  @override
  void initState() {
    super.initState();
    _stationState.addListener(_onStateChange);
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _stationState.removeListener(_onStateChange);
    super.dispose();
  }

  void _showStationPicker({required bool isFrom}) {
    final stations = _stationState.stations;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = stations.where((s) {
              final q = searchQuery.toLowerCase().trim();
              if (q.isEmpty) return true;
              return s.name.toLowerCase().contains(q) ||
                  s.code.toLowerCase().contains(q) ||
                  s.line.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: LocoColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isFrom ? 'Select Origin Station' : 'Select Destination Station',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: LocoColors.textMuted),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Station Search
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      onChanged: (val) => setModalState(() => searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search Mumbai Suburban station (e.g. Virar, Dadar)...',
                        prefixIcon: const Icon(Icons.search, color: LocoColors.orange),
                        filled: true,
                        fillColor: LocoColors.canvas,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: LocoColors.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // GPS Detection Tile
                  if (isFrom)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: LocoColors.orangeLight, width: 1.5),
                        ),
                        tileColor: LocoColors.orangeLight,
                        leading: const Icon(Icons.my_location, color: LocoColors.orange),
                        title: const Text(
                          'Detect Current Location (GPS)',
                          style: TextStyle(fontWeight: FontWeight.w800, color: LocoColors.orange, fontSize: 13.5),
                        ),
                        subtitle: const Text(
                          'Sets default station across the entire app',
                          style: TextStyle(fontSize: 11, color: LocoColors.textSecondary),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          final detected = await _stationState.detectCurrentLocation(forceGps: true);
                          if (mounted && detected != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: LocoColors.textPrimary,
                                content: Text('📍 Location updated: ${detected.name} is now default throughout LOCO'),
                              ),
                            );
                          }
                        },
                      ),
                    ),

                  const Divider(),

                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final s = filtered[index];
                        final isSelected = isFrom
                            ? s.id == _stationState.currentStation.id
                            : s.id == _stationState.destinationStation.id;

                        return ListTile(
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected ? LocoColors.orange : LocoColors.orangeLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                s.code,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : LocoColors.orange,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            s.name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                              color: isSelected ? LocoColors.orange : LocoColors.textPrimary,
                              fontSize: 14.5,
                            ),
                          ),
                          subtitle: Text(
                            '${s.line} Railway • Platform 1-${s.platformsCount}',
                            style: const TextStyle(fontSize: 12, color: LocoColors.textMuted),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: LocoColors.orange, size: 20)
                              : const Icon(Icons.chevron_right, size: 18, color: LocoColors.textMuted),
                          onTap: () async {
                            if (isFrom) {
                              _stationState.setCurrentStation(s);
                              await LocationService.setCustomLocation(s.latitude, s.longitude, name: s.name);
                            } else {
                              _stationState.setDestinationStation(s);
                            }
                            if (mounted) Navigator.pop(context);
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

  void _openLoCoPilotAI([String? presetQuery]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RailAISheet(
        initialQuery: presetQuery,
        onViewTicket: () {
          Navigator.pop(context);
          if (widget.onSwitchTab != null) widget.onSwitchTab!(1);
        },
        onPlanJourney: () {
          Navigator.pop(context);
          _navigateToBooking();
        },
        onActionTriggered: (payload) {
          Navigator.pop(context);
          if (payload.actionType == 'BOOK_TICKET' || payload.actionType == 'PLAN_JOURNEY') {
            _navigateToBooking();
          } else if (payload.actionType == 'VIEW_CROWD_RADAR' || payload.actionType == 'VIEW_LIVE_ROUTES') {
            if (widget.onSwitchTab != null) widget.onSwitchTab!(3);
          } else if (payload.actionType == 'RENEW_SEASON_PASS') {
            _navigateToBooking();
          } else if (payload.actionType == 'EXPLORE_POI') {
            if (widget.onSwitchTab != null) widget.onSwitchTab!(3);
          } else {
            _navigateToBooking();
          }
        },
      ),
    );
  }

  void _navigateToBooking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(
          fromStation: _stationState.currentStation,
          toStation: _stationState.destinationStation,
          stationDifference: 7,
        ),
      ),
    );
  }

  Future<void> _issuePlatformPass() async {
    final station = _stationState.currentStation;
    final now = DateTime.now();
    final passId = 'PLT-${station.code}-${now.millisecondsSinceEpoch % 10000}';

    final currentUser = await AuthService.getCurrentUser();
    final passengerName = (currentUser != null && currentUser.name.isNotEmpty)
        ? currentUser.name
        : 'Commuter';

    final ticket = BookedTicket(
      id: passId,
      fromStationName: station.name,
      fromStationCode: station.code,
      toStationName: station.name,
      toStationCode: station.code,
      ticketType: TicketType.journey,
      bookingType: BookingType.issue,
      trainType: 'PLATFORM PASS',
      duration: '2 HOURS',
      classType: 'PLATFORM PASS',
      fare: 10,
      bookingDate: now,
      validUntil: now.add(const Duration(hours: 2)),
      status: TicketStatus.upcoming,
      distanceKm: 0.0,
      passengerName: passengerName,
      passengerAddress: 'Mumbai Suburban Area',
      passengerIdType: 'Digital Identity',
      passengerIdNumber: 'UTS-PASS',
    );

    await TicketStorage.addTicket(ticket);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => DigitalTicketInspector(
          ticket: ticket,
          onSimulateScan: () {},
        ),
      );
    }
  }

  Widget _buildLoCoPilotAIBossCard() {
    final assistService = LocoAssistService();
    final liveInsight = assistService.getHomeBannerInsight();
    final quickQueries = [
      '🎫 Book Ticket',
      '💳 Season Pass',
      '📋 UTS Rules',
      '🛡️ Journey Guardian',
      '❄️ AC Local Times',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1015), Color(0xFF2E121A), Color(0xFF381219)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF5200).withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5200).withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5200).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFF5200).withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.bolt_rounded, color: Color(0xFFFF5200), size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'LOCO Assist',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.2),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5200).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFF5200),
                            width: 0.8,
                          ),
                        ),
                        child: const Text(
                          'ASSISTANT',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF7A33),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Mumbai Suburban Railway Guidance Engine',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Live Predictive Insight Banner Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.auto_awesome_rounded, color: Color(0xFFFF7A33), size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    liveInsight,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFF1F5F9),
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Ask Bar (Tapping opens LOCOpilot AI with query or focus)
          GestureDetector(
            onTap: () => _openLoCoPilotAI(),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Color(0xFFFF5200), size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Ask LOCOpilot AI (e.g. "Book ticket to Dadar")...',
                      style: TextStyle(fontSize: 12.5, color: LocoColors.textMuted, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, color: Colors.white, size: 14),
                        SizedBox(width: 3),
                        Text(
                          'ASK AI',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Quick Action Query Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: quickQueries.map((query) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _openLoCoPilotAI(query),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        query,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStation = _stationState.currentStation;
    final destinationStation = _stationState.destinationStation;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP HEADER (LOCO Wordmark Logo | Station Pill Selector | Profile Avatar)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // LOCO Logo
                  LocoBranding.wordmark(fontSize: 26),

                  Row(
                    children: [
                      // Station Selector Pill (matching UI/Home.png)
                      GestureDetector(
                        onTap: () => _showStationPicker(isFrom: true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: LocoColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF5722),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                currentStation.name,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: LocoColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: LocoColors.textSecondary),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // User Profile Icon Button
                      GestureDetector(
                        onTap: () {
                          if (widget.onSwitchTab != null) widget.onSwitchTab!(4);
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: LocoColors.border),
                          ),
                          child: const Icon(Icons.person_outline_rounded, size: 20, color: LocoColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ACTIVE JOURNEY GUARDIAN CARD (Phase 4 Real Backend Geofence & Progress Monitor)
              StreamBuilder<ActiveJourney?>(
                stream: JourneyGuardianService().journeyStream,
                initialData: JourneyGuardianService().activeJourney,
                builder: (context, snapshot) {
                  final active = snapshot.data;
                  if (active != null &&
                      active.state != JourneyState.completed &&
                      active.state != JourneyState.abandoned) {
                    return JourneyGuardianCard(
                      journey: active,
                      onCompleted: () => setState(() {}),
                      onAbandoned: () => setState(() {}),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // 1.5. LOCOPILOT AI BOSS HERO COMMAND CARD
              _buildLoCoPilotAIBossCard(),

              const SizedBox(height: 18),

              // 2. TWO MAIN CARDS ROW (Unreserved Ticket | Platform Ticket)
              Row(
                children: [
                  // Card 1: Unreserved Ticket (Orange Gradient Card)
                  Expanded(
                    child: Container(
                      height: 175,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFF5200), Color(0xFFE64A00)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5200).withOpacity(0.32),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Background subtle watermark train icon
                          Positioned(
                            right: -10,
                            bottom: 10,
                            child: Icon(
                              Icons.directions_subway_rounded,
                              size: 74,
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Tag & Arrow
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.22),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'DAILY TRAVEL',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.22),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Text(
                                'Unreserved Ticket',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Single & Return\nsuburban locals',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white.withOpacity(0.88),
                                  height: 1.25,
                                ),
                              ),
                              const Spacer(),
                              // Bottom Row: Fare & Book Now
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'From ₹5',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  GestureDetector(
                                    onTap: _navigateToBooking,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        'Book Now',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFE64A00),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Card 2: Platform Ticket (White Card with 1-Tap)
                  Expanded(
                    child: Container(
                      height: 175,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: LocoColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Tag & Plus
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF0E6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'STATION PASS',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFF5500),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF3F4F6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add, size: 14, color: LocoColors.textSecondary),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Text(
                            'Platform Ticket',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: LocoColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Quick access at ${currentStation.name}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: LocoColors.textSecondary,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          const Divider(height: 12, color: LocoColors.borderLight),
                          // Bottom Row: Fixed Fare & 1-Tap
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FIXED FARE',
                                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: LocoColors.textMuted),
                                  ),
                                  Text(
                                    '₹10',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: _issuePlatformPass,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4A101D),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Text(
                                    '1-Tap',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 3. SELECT ROUTE CARD
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: LocoColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF5500),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Select Route',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Origin & Destination Box with Floating Swap Button
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: LocoColors.borderLight),
                      ),
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          Column(
                            children: [
                              // Origin Line
                              GestureDetector(
                                onTap: () => _showStationPicker(isFrom: true),
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFFFF5500), width: 3),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'ORIGIN',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: LocoColors.textMuted,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            currentStation.name,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(right: 38),
                                      child: Text(
                                        currentStation.code,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFFF5500)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const Divider(height: 20, color: LocoColors.borderLight),

                              // Destination Line
                              GestureDetector(
                                onTap: () => _showStationPicker(isFrom: false),
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF4A101D),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'DESTINATION',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: LocoColors.textMuted,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            destinationStation.name,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(right: 38),
                                      child: Text(
                                        destinationStation.code,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF880E4F)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Floating Swap Button
                          GestureDetector(
                            onTap: () => _stationState.swapStations(),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: LocoColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.swap_vert_rounded, color: Color(0xFFFF5500), size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Frequent Destinations Chips
                    Row(
                      children: [
                        const Text(
                          'Frequent:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LocoColors.textMuted),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFrequentChip('To Churchgate', 'churchgate'),
                                _buildFrequentChip('To Borivali', 'borivali'),
                                _buildFrequentChip('To Andheri', 'andheri'),
                                _buildFrequentChip('To Dadar', 'dadar'),
                                _buildFrequentChip('To CSMT', 'csmt'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Book Ticket Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _navigateToBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5500),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Book Ticket',
                              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. LOCOPILOT AI (Dark Theme Mumbai Intel Card)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2C0F16), Color(0xFF1B070C)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2C0F16).withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF5500),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'LOCOPILOT AI',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6B222E),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'BETA',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const Row(
                          children: [
                            Icon(Icons.bolt, size: 14, color: Color(0xFFFF9800)),
                            SizedBox(width: 4),
                            Text(
                              'Live Mumbai Intel',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFFFB74D)),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Speech Bubble / Intel text
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5500),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bolt, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  height: 1.35,
                                ),
                                children: [
                                  TextSpan(text: '"${currentStation.name} fast local at 09:45 AM has '),
                                  const TextSpan(
                                    text: 'moderate coach crowd',
                                    style: TextStyle(color: Color(0xFFFFB74D), fontWeight: FontWeight.w800),
                                  ),
                                  const TextSpan(
                                    text: '. Board middle coaches (C6-C8) for quicker interchange at Dadar."',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Action Chips & Arrow Button
                    Row(
                      children: [
                        _buildAiActionChip('⚡ Crowd Radar', () => _openLoCoPilotAI('Crowd radar')),
                        const SizedBox(width: 6),
                        _buildAiActionChip('⏱ Delay Risk', () => _openLoCoPilotAI('Delay risk')),
                        const SizedBox(width: 6),
                        _buildAiActionChip('🔄 AC Local S...', () => _openLoCoPilotAI('AC local schedules')),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _openLoCoPilotAI(),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5500),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 5. NEXT TRAINS FROM STATION (Matching UI/Home.png)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: LocoColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFF0E6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.access_time_filled, color: Color(0xFFFF5500), size: 15),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Next Trains from ${currentStation.name}',
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            if (widget.onSwitchTab != null) widget.onSwitchTab!(3); // Switch to Live Routes
                          },
                          child: const Text(
                            'Live Routes',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF5500),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Train 1: Churchgate Fast Local
                    _buildNextTrainItem(
                      platform: 'PF 2',
                      platformColor: const Color(0xFFFF5500),
                      title: 'Churchgate Fast Local',
                      carTag: '15-Car',
                      subtext: 'Stops: Borivali, Andheri, Bandra, Dadar',
                      minsRemaining: '4 mins',
                      scheduledTime: '09:45 AM',
                      isGreenTime: true,
                    ),

                    const SizedBox(height: 10),

                    // Train 2: Andheri Slow Local
                    _buildNextTrainItem(
                      platform: 'PF 4',
                      platformColor: const Color(0xFF381219),
                      title: 'Andheri Slow Local',
                      carTag: '12-Car',
                      subtext: 'All stations to Andheri',
                      minsRemaining: '11 mins',
                      scheduledTime: '09:52 AM',
                      isGreenTime: false,
                    ),

                    const SizedBox(height: 10),

                    // Train 3: Borivali AC EMU
                    _buildNextTrainItem(
                      platform: 'PF 1',
                      platformColor: Colors.blue.shade800,
                      title: 'Churchgate AC EMU',
                      carTag: 'AC EMU',
                      subtext: 'Fast Local: Borivali, Bandra, Dadar, Churchgate',
                      minsRemaining: '18 mins',
                      scheduledTime: '09:59 AM',
                      isGreenTime: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrequentChip(String label, String stationId) {
    final isSelected = _stationState.destinationStation.id.toLowerCase() == stationId.toLowerCase() ||
        _stationState.destinationStation.name.toLowerCase().contains(stationId.toLowerCase());

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          final found = _stationState.stations.firstWhere(
            (s) => s.id.toLowerCase() == stationId || s.name.toLowerCase().contains(stationId),
            orElse: () => _stationState.destinationStation,
          );
          _stationState.setDestinationStation(found);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF0E6) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFFFF5500) : LocoColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? const Color(0xFFFF5500) : LocoColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiActionChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildNextTrainItem({
    required String platform,
    required Color platformColor,
    required String title,
    required String carTag,
    required String subtext,
    required String minsRemaining,
    required String scheduledTime,
    required bool isGreenTime,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LocoColors.canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LocoColors.borderLight),
      ),
      child: Row(
        children: [
          // Platform Circle Badge
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: platformColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                platform,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Title & stops
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: LocoColors.border),
                      ),
                      child: Text(
                        carTag,
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: LocoColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtext,
                  style: const TextStyle(fontSize: 11, color: LocoColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Time remaining
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                minsRemaining,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isGreenTime ? const Color(0xFF10B981) : LocoColors.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                scheduledTime,
                style: const TextStyle(fontSize: 10.5, color: LocoColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
