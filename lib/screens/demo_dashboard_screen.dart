import 'package:flutter/material.dart';
import '../core/theme/loco_theme.dart';
import '../models/station.dart';
import '../models/ticket.dart';
import '../services/journey_guardian_service.dart';
import '../services/security_services.dart';

class DemoDashboardScreen extends StatefulWidget {
  const DemoDashboardScreen({super.key});

  @override
  State<DemoDashboardScreen> createState() => _DemoDashboardScreenState();
}

class _DemoDashboardScreenState extends State<DemoDashboardScreen> {
  String _activeScenario = 'Normal Operation';

  void _triggerScenario({
    required String name,
    required String description,
    required VoidCallback action,
  }) {
    action();
    setState(() => _activeScenario = name);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: LocoColors.orange,
        content: Text('⚡ Scenario Activated: $name\n$description'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guardian = JourneyGuardianService();
    final trustService = LocationTrustService();
    final fraudService = FraudDetectionService();

    return Scaffold(
      backgroundColor: LocoColors.canvas,
      appBar: AppBar(
        title: const Text('LOCO Developer / Demo Control'),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Phase 0 Architecture Notice Banner
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Phase 0 Architecture: Prototype simulation engines are disconnected. Real railway telemetry and external providers connect in Phase 4.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            // Current State Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LocoColors.orange, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ACTIVE DEMO SCENARIO',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: LocoColors.orange),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: LocoColors.orangeLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('LIVE IN-MEMORY STATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: LocoColors.orange)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _activeScenario,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: LocoColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Journey: ${guardian.hasActiveJourney ? "${guardian.activeJourney!.originStation.name} → ${guardian.activeJourney!.destinationStation.name} (${guardian.activeJourney!.progressPercent.toInt()}%)" : "No Active Journey"} • Trust: ${trustService.currentLevel.name.toUpperCase()}',
                    style: const TextStyle(fontSize: 13, color: LocoColors.textSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              '12 Interactive Product Scenarios',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap any scenario to manipulate live core services and verify responsive UI behavior.',
              style: TextStyle(fontSize: 13, color: LocoColors.textMuted),
            ),
            const SizedBox(height: 14),

            // 1. Normal Journey
            _buildScenarioTile(
              icon: Icons.directions_railway,
              title: '1. Normal Journey Started',
              subtitle: 'Spawns Borivali → Dadar ticket & activates Journey Guardian.',
              color: LocoColors.orange,
              onTap: () => _triggerScenario(
                name: 'Normal Journey',
                description: 'Ticket created, geofence verified, Journey Guardian started.',
                action: () {
                  final ticket = BookedTicket(
                    id: 'LOCO-BVI-9042',
                    fromStationName: 'BORIVALI',
                    fromStationCode: 'BVI',
                    toStationName: 'DADAR',
                    toStationCode: 'DDR',
                    ticketType: TicketType.journey,
                    bookingType: BookingType.issue,
                    trainType: 'FAST LOCAL',
                    duration: 'SINGLE',
                    classType: 'SECOND',
                    fare: 15,
                    bookingDate: DateTime.now(),
                    status: TicketStatus.upcoming,
                    distanceKm: 24.0,
                    passengerName: 'Commuter',
                    passengerAddress: 'Borivali West, Mumbai',
                    passengerIdType: 'PAN Card',
                    passengerIdNumber: 'SENP******',
                  );
                  final bvi = RailwayStation(id: 'borivali', name: 'BORIVALI', latitude: 19.2290, longitude: 72.8573);
                  final ddr = RailwayStation(id: 'dadar', name: 'DADAR', latitude: 19.0192, longitude: 72.8438);
                  guardian.startJourney(ticket: ticket, originStation: bvi, destinationStation: ddr);
                  trustService.resetTrust();
                },
              ),
            ),

            // 2. Train Approaching
            _buildScenarioTile(
              icon: Icons.near_me,
              title: '2. Train Approaching Platform',
              subtitle: 'Train WR-90142 arriving in 2 minutes at platform 3.',
              color: LocoColors.info,
              onTap: () => _triggerScenario(
                name: 'Train Approaching',
                description: 'Platform 3 signaled. Speed slowing for docking.',
                action: () {},
              ),
            ),

            // 3. Train Delayed + Alternative Route
            _buildScenarioTile(
              icon: Icons.warning_amber_rounded,
              title: '3. Train Delayed (+8 min)',
              subtitle: 'Triggers proactive delay notice and alternative AC Fast local.',
              color: LocoColors.warning,
              onTap: () => _triggerScenario(
                name: 'Train Delayed (+8 min)',
                description: 'LOCO detects signal delay and recommends alternative train.',
                action: () {
                  guardian.injectDelay(delayMinutes: 8);
                },
              ),
            ),

            // 4. High Crowd Alert
            _buildScenarioTile(
              icon: Icons.groups,
              title: '4. High Crowd Alert',
              subtitle: 'Crowd density reaches Very High during peak hour.',
              color: LocoColors.crowdHigh,
              onTap: () => _triggerScenario(
                name: 'High Crowd Alert',
                description: 'Coach occupancy elevated. Suggests alternative car 4 or 8.',
                action: () {},
              ),
            ),

            // 5. Alternative Route Recommended
            _buildScenarioTile(
              icon: Icons.alt_route,
              title: '5. Alternative Route Recommended',
              subtitle: 'Calculates faster connecting train departing 6m earlier.',
              color: LocoColors.info,
              onTap: () => _triggerScenario(
                name: 'Alternative Route',
                description: 'Switching to AC Fast local WR-90215 from platform 4.',
                action: () {
                  guardian.handleRunningLate();
                },
              ),
            ),

            // 6. GPS Spoofing Anomaly
            _buildScenarioTile(
              icon: Icons.gps_off,
              title: '6. GPS Spoofing Anomaly',
              subtitle: 'Simulates mock location / impossible geographic teleportation.',
              color: LocoColors.error,
              onTap: () => _triggerScenario(
                name: 'GPS Spoofing Detected',
                description: 'LocationTrustService flags suspicious signal. Prompts verification.',
                action: () {
                  trustService.injectSpoofAnomaly();
                },
              ),
            ),

            // 7. Suspicious Ticket Reuse
            _buildScenarioTile(
              icon: Icons.copy,
              title: '7. Suspicious Ticket Reuse',
              subtitle: 'Ticket scanned twice at distant stations within 2 minutes.',
              color: LocoColors.error,
              onTap: () => _triggerScenario(
                name: 'Ticket Reuse Alert',
                description: 'FraudDetectionService generates security event and updates risk score.',
                action: () {
                  fraudService.injectTicketReuseEvent('LOCO-BVI-9042');
                },
              ),
            ),

            // 8. Ticketless Intervention
            _buildScenarioTile(
              icon: Icons.door_front_door_outlined,
              title: '8. Ticketless Travel Detected at Station',
              subtitle: 'User enters Andheri geofence with no active ticket.',
              color: LocoColors.orange,
              onTap: () => _triggerScenario(
                name: 'Ticketless Travel Intervention',
                description: 'Gentle prompt offers 1-tap ticket purchase to Dadar/Churchgate.',
                action: () {
                  guardian.clearJourney();
                },
              ),
            ),

            // 9. Journey Started & Moving
            _buildScenarioTile(
              icon: Icons.speed,
              title: '9. Train In-Transit (Moving at 60 km/h)',
              subtitle: 'Progress bar accelerates with speed telemetry.',
              color: LocoColors.westernLine,
              onTap: () => _triggerScenario(
                name: 'In-Transit',
                description: 'Speed 58 km/h. Next stop Kandivali in 3 min.',
                action: () {
                  // Handled by JourneyGuardianService live timer
                },
              ),
            ),

            // 10. Destination Approaching Alert
            _buildScenarioTile(
              icon: Icons.notifications_active,
              title: '10. Destination Approaching Alert',
              subtitle: 'Dadar is 2 stations away. Progress reaches 92%.',
              color: LocoColors.orange,
              onTap: () => _triggerScenario(
                name: 'Destination Approaching',
                description: 'Pre-arrival notification triggered for Dadar Station.',
                action: () {
                  guardian.setDestinationApproaching();
                },
              ),
            ),

            // 11. Journey Completed (Post-Journey)
            _buildScenarioTile(
              icon: Icons.celebration,
              title: '11. Journey Completed',
              subtitle: 'Arrival at Dadar triggers summary and local food/culture discovery.',
              color: LocoColors.success,
              onTap: () => _triggerScenario(
                name: 'Journey Completed',
                description: 'Ticket marked COMPLETED. Post-journey discovery activated.',
                action: () {
                  guardian.completeJourney();
                },
              ),
            ),

            // 12. Reset to Clean State
            _buildScenarioTile(
              icon: Icons.refresh,
              title: '12. Reset All States to Default',
              subtitle: 'Restores baseline simulation, clears security events and journeys.',
              color: LocoColors.textSecondary,
              onTap: () => _triggerScenario(
                name: 'System Reset',
                description: 'All services restored to default clean state.',
                action: () {
                  guardian.clearJourney();
                  trustService.resetTrust();
                  fraudService.clearEvents();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LocoColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: LocoColors.textPrimary),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: LocoColors.textSecondary),
        ),
        trailing: const Icon(Icons.play_circle_fill, color: LocoColors.orange, size: 24),
      ),
    );
  }
}
