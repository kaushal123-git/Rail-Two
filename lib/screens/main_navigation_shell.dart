import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/loco_theme.dart';
import '../models/journey.dart';
import '../models/security_models.dart';
import '../services/journey_guardian_service.dart';
import '../services/security_services.dart';
import '../widgets/post_journey_sheet.dart';
import '../widgets/rail_ai_sheet.dart';
import 'home_screen.dart';
import 'live_routes_screen.dart';
import 'tickets_screen.dart';
import 'you_screen.dart';

class MainNavigationShell extends StatefulWidget {
  final int initialIndex;

  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;
  StreamSubscription<ActiveJourney?>? _journeySub;
  StreamSubscription<LocationTrustLevel>? _trustSub;
  LocationTrustLevel _trustLevel = LocationTrustLevel.trusted;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    // Listen for journey completion to show PostJourneySheet
    _journeySub = JourneyGuardianService().journeyStream.listen((journey) {
      if (journey != null && journey.state == JourneyState.completed) {
        _showPostJourneySheet(journey);
      }
    });

    // Listen for security trust updates
    _trustSub = LocationTrustService().trustStream.listen((trust) {
      setState(() => _trustLevel = trust);
    });
  }

  @override
  void dispose() {
    _journeySub?.cancel();
    _trustSub?.cancel();
    super.dispose();
  }

  void _showPostJourneySheet(ActiveJourney journey) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostJourneySheet(
        journey: journey,
        onDismiss: () => Navigator.pop(context),
        onPlanReturn: () {
          Navigator.pop(context);
          setState(() => _currentIndex = 0);
        },
      ),
    );
  }

  void _openRailAISheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RailAISheet(
        onViewTicket: () {
          Navigator.pop(context);
          setState(() => _currentIndex = 1);
        },
        onPlanJourney: () {
          Navigator.pop(context);
          setState(() => _currentIndex = 0);
        },
        onActionTriggered: (payload) {
          Navigator.pop(context);
          if (payload.actionType == 'VIEW_TICKET') {
            setState(() => _currentIndex = 1);
          } else if (payload.actionType == 'VIEW_CROWD_RADAR' || payload.actionType == 'VIEW_LIVE_ROUTES') {
            setState(() => _currentIndex = 3);
          } else {
            setState(() => _currentIndex = 0);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onSwitchTab: (idx) => setState(() => _currentIndex = idx)),
      TicketsScreen(onPlanJourneyTap: () => setState(() => _currentIndex = 0)),
      HomeScreen(onSwitchTab: (idx) => setState(() => _currentIndex = idx)), // Index 2 placeholder for center LOCOpilot tap
      const LiveRoutesScreen(),
      const YouScreen(),
    ];

    return Scaffold(
      body: Column(
        children: [
          // Security Alert Banner if Location Trust is degraded
          if (_trustLevel == LocationTrustLevel.suspicious || _trustLevel == LocationTrustLevel.critical)
            SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: LocoColors.errorLight,
                child: Row(
                  children: [
                    const Icon(Icons.security, size: 18, color: LocoColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        LocationTrustService().statusMessage,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LocoColors.error),
                      ),
                    ),
                    TextButton(
                      onPressed: () => LocationTrustService().resetTrust(),
                      child: const Text('Verify', style: TextStyle(fontSize: 12, color: LocoColors.error, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(child: screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: LocoColors.border, width: 1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // 1. Home
                _buildNavItem(
                  index: 0,
                  activeIcon: Icons.home_rounded,
                  inactiveIcon: Icons.home_outlined,
                  label: 'Home',
                ),

                // 2. My Tickets
                _buildNavItem(
                  index: 1,
                  activeIcon: Icons.confirmation_number_rounded,
                  inactiveIcon: Icons.confirmation_number_outlined,
                  label: 'My Tickets',
                  hasBadge: true,
                ),

                // 3. Center LOCOpilot AI Button (The Main Boss Hub)
                GestureDetector(
                  onTap: _openRailAISheet,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFFFF5200), Color(0xFFD63300)],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF5200).withValues(alpha: 0.45),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.bolt_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white,
                                  size: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'LOCOpilot',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF5200),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. Live Routes (Replaces interactive map!)
                _buildNavItem(
                  index: 3,
                  activeIcon: Icons.alt_route_rounded,
                  inactiveIcon: Icons.alt_route_outlined,
                  label: 'Live Routes',
                ),

                // 5. Profile
                _buildNavItem(
                  index: 4,
                  activeIcon: Icons.person_rounded,
                  inactiveIcon: Icons.person_outline_rounded,
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
    bool hasBadge = false,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : inactiveIcon,
                  color: isSelected ? const Color(0xFFFF5200) : LocoColors.textMuted,
                  size: 24,
                ),
                if (hasBadge)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5200),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? const Color(0xFFFF5200) : LocoColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
