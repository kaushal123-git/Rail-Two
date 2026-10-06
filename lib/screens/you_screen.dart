import 'package:flutter/material.dart';
import '../core/constants/loco_branding.dart';
import '../core/theme/loco_theme.dart';
import '../models/user_account.dart';
import '../services/api_service.dart';
import '../services/auth_database.dart';
import '../services/security_services.dart';
import '../services/station_state_service.dart';
import '../widgets/rail_ai_sheet.dart';
import 'demo_dashboard_screen.dart';
import 'login_screen.dart';

class YouScreen extends StatefulWidget {
  const YouScreen({super.key});

  @override
  State<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends State<YouScreen> {
  UserAccount? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthDatabase().getActiveSession();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'LC';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: const Text('Are you sure you want to log out of your LOCO account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: LocoColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: LocoColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.logout();
      await AuthDatabase().logout();
      if (!mounted) return;
      setState(() => _currentUser = null);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final trustService = LocationTrustService();
    final isLoggedIn = _currentUser != null;
    final displayName = _currentUser?.name ?? 'Unauthenticated Commuter';
    final displayIdentifier = _currentUser?.phone != null
        ? '+91 ${_currentUser!.phone}'
        : (_currentUser?.email ?? 'No active session');
    final initials = isLoggedIn ? _getInitials(displayName) : '?';

    return Scaffold(
      backgroundColor: LocoColors.canvas,
      appBar: AppBar(
        title: const Text('You', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: LocoColors.textSecondary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DemoDashboardScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: LocoColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: LocoColors.orangeLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: LocoColors.orange),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isLoggedIn ? '$displayIdentifier • Mumbai Suburban' : 'Sign in to access tickets & passes',
                          style: const TextStyle(fontSize: 13, color: LocoColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (isLoggedIn)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: LocoColors.successLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('VERIFIED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: LocoColors.success)),
                    )
                  else
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LocoColors.orange,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Sign In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Commuter Impact Metrics
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LocoColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('142 km', 'Distance Travelled'),
                  _buildStatDivider(),
                  _buildStat('18', 'Journeys Taken'),
                  _buildStatDivider(),
                  _buildStat('8.4 kg', 'CO₂ Saved', color: LocoColors.success),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // LOCO ASSIST & DEFAULT APP STATION STATUS
            ListenableBuilder(
              listenable: StationStateService(),
              builder: (context, _) {
                final state = StationStateService();

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LocoColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2C0F16),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.bolt, color: LocoColors.orange, size: 18),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'LOCO Assist Companion',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: LocoColors.orangeLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'READY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: LocoColors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Default App Station', style: TextStyle(fontSize: 11, color: LocoColors.textMuted, fontWeight: FontWeight.w600)),
                              Text('${state.currentStation.name} (${state.currentStation.code})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: LocoColors.textPrimary)),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () => state.detectCurrentLocation(),
                            icon: const Icon(Icons.my_location, size: 14, color: LocoColors.orange),
                            label: const Text('Detect GPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LocoColors.orange)),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Guidance Engine', style: TextStyle(fontSize: 11, color: LocoColors.textMuted, fontWeight: FontWeight.w600)),
                                Text(
                                  'Suburban Ticketing & Rules Guidance',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: LocoColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const RailAISheet(),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              side: const BorderSide(color: LocoColors.orange),
                            ),
                            child: const Text('Ask Assist', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LocoColors.orange)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // DEMO / DEVELOPER DASHBOARD CTA (Highlight!)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LocoColors.orangeLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LocoColors.orange.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: LocoColors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.science_outlined, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Developer / Demo Control',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Trigger 12 live scenarios (Delays, Spoofing, Crowd, Guardian)',
                          style: TextStyle(fontSize: 12, color: LocoColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DemoDashboardScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LocoColors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Open'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text('Saved Stations', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: LocoColors.textPrimary)),
            const SizedBox(height: 10),

            _buildSavedLocationTile(icon: Icons.home_outlined, title: 'Home Station', subtitle: 'Borivali (Western Line)'),
            _buildSavedLocationTile(icon: Icons.work_outline, title: 'Work / College', subtitle: 'Churchgate (Platform 3)'),
            _buildSavedLocationTile(icon: Icons.star_border, title: 'Frequent Junction', subtitle: 'Dadar (Western & Central Hub)'),

            const SizedBox(height: 20),
            const Text('Security & Hardware Telemetry', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: LocoColors.textPrimary)),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LocoColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('GPS Location Trust', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        trustService.currentLevel.name.toUpperCase(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: LocoColors.success),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Anti-Spoof Geofence', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('ACTIVE (500m radius)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LocoColors.orange)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Biometric Fingerprint Lock', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        (_currentUser?.biometricEnabled ?? true) ? 'ENROLLED' : 'DISABLED',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: (_currentUser?.biometricEnabled ?? true) ? LocoColors.success : LocoColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Credentials Database', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('SQLite (Offline Secure)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LocoColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Log Out Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout_rounded, color: LocoColors.error, size: 18),
                label: const Text(
                  'LOG OUT OF ACCOUNT',
                  style: TextStyle(color: LocoColors.error, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: LocoColors.error, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  LocoBranding.wordmark(fontSize: 20),
                  const SizedBox(height: 4),
                  const Text(
                    '${LocoBranding.tagline} • ${LocoBranding.version}',
                    style: TextStyle(fontSize: 11, color: LocoColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String val, String label, {Color? color}) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color ?? LocoColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: LocoColors.textMuted)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 30, color: LocoColors.border);
  }

  Widget _buildSavedLocationTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LocoColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: LocoColors.orange),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LocoColors.textPrimary)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: LocoColors.textMuted)),
            ],
          ),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios, size: 12, color: LocoColors.textMuted),
        ],
      ),
    );
  }
}
