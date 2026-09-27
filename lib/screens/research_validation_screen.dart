import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/s2_service.dart';
import '../services/error_recovery_service.dart';
import '../services/fraud_detection_service.dart';
import '../services/analytics_evaluation_service.dart';
import '../services/revenue_recovery_service.dart';

class ResearchValidationScreen extends StatefulWidget {
  const ResearchValidationScreen({super.key});

  @override
  State<ResearchValidationScreen> createState() => _ResearchValidationScreenState();
}

class _ResearchValidationScreenState extends State<ResearchValidationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Position? _currentPosition;
  String _s2CellToken = 'Fetching...';
  String _s2CellId = 'Fetching...';
  bool _isLoadingPosition = false;

  // RO2 ML Simulation Controls
  double _simulatedSpeed = 0.0; // km/h
  double _simulatedIntervalSec = 300.0; // sec
  double _simulatedGpsAccuracy = 12.0; // meters
  bool _isOfflineSimulated = false;
  FraudAnalysisResult? _currentFraudAnalysis;

  // RO3 Survey State
  int _easeOfUse = 5;
  int _accuracySatisfaction = 5;
  int _perceivedSecurity = 5;
  int _privacyConfidence = 4;
  int _errorRecoveryRating = 5;
  final TextEditingController _feedbackController = TextEditingController();
  List<SurveyResponse> _surveyList = [];

  // RO4 Revenue Recovery Parameters
  double _annualPassengers = 280000000.0; // 280 Million
  double _evasionRatePercent = 4.5; // 4.5%
  double _avgFareRs = 15.0; // Rs. 15
  double _systemEfficiencyPercent = 88.5; // 88.5%
  double _falsePositiveRate = 1.2; // 1.2%

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _refreshLocationAndS2();
    _runFraudAnalysis();
    _loadSurveys();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _refreshLocationAndS2() async {
    setState(() => _isLoadingPosition = true);
    final result = await ErrorRecoveryService.getVerifiedPositionWithRecovery();
    if (mounted) {
      setState(() {
        _isLoadingPosition = false;
        if (result.position != null) {
          _currentPosition = result.position;
          _s2CellToken = S2Service.getCellToken(result.position!.latitude, result.position!.longitude);
          _s2CellId = S2Service.getCellIdString(result.position!.latitude, result.position!.longitude);
        } else {
          _s2CellToken = 'Unavailable';
          _s2CellId = 'Unavailable';
        }
      });
      _runFraudAnalysis();
    }
  }

  void _runFraudAnalysis() {
    final distanceMovedKm = (_simulatedSpeed * (_simulatedIntervalSec / 3600.0));
    final features = BookingPatternFeatures(
      userLat: _currentPosition?.latitude ?? 19.0760,
      userLng: _currentPosition?.longitude ?? 72.8777,
      accuracyMeters: _simulatedGpsAccuracy,
      distanceToStationMeters: 120.0,
      timeDifferenceSeconds: _simulatedIntervalSec,
      distanceMovedFromLastBookingKm: distanceMovedKm,
      isQrScanned: true,
      isOffline: _isOfflineSimulated,
      deviceId: 'DEVICE-HASH-882194',
    );

    setState(() {
      _currentFraudAnalysis = FraudDetectionService.analyzeBookingAttempt(features);
    });
  }

  Future<void> _loadSurveys() async {
    final list = await AnalyticsEvaluationService.loadSurveyResponses();
    setState(() {
      _surveyList = list;
    });
  }

  Future<void> _submitSurvey() async {
    final newSurvey = SurveyResponse(
      timestamp: DateTime.now(),
      easeOfUse: _easeOfUse,
      locationAccuracySatisfaction: _accuracySatisfaction,
      perceivedSecurity: _perceivedSecurity,
      privacyConfidence: _privacyConfidence,
      errorRecoveryRating: _errorRecoveryRating,
      feedbackText: _feedbackController.text.trim(),
    );

    await AnalyticsEvaluationService.saveSurveyResponse(newSurvey);
    _feedbackController.clear();
    await _loadSurveys();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2E7D32),
          content: Text('RO3 Survey Submitted! Usability SUS Score: ${newSurvey.calculateSusScore.toStringAsFixed(1)} / 100'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0066FF),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Research & Validation Framework', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            Text('RO1 - RO4 Evaluation & Telemetry', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          isScrollable: true,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'RO1: GPS & Geofence'),
            Tab(text: 'RO2: ML Fraud Detector'),
            Tab(text: 'RO3: Usability & Privacy'),
            Tab(text: 'RO4: Revenue Recovery'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRO1Tab(),
          _buildRO2Tab(),
          _buildRO3Tab(),
          _buildRO4Tab(),
        ],
      ),
    );
  }

  // ==================== RO1 TAB ====================
  Widget _buildRO1Tab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(
            title: 'RO1 — Secure Ticket Generation Framework',
            subtitle: 'Secure digital ticket generation using real-time GPS tracking, S2 spatial cell indexing, and dual geofencing.',
            icon: Icons.verified_user_rounded,
            color: const Color(0xFF0066FF),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Live GPS & Spatial Indexing Telemetry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: _isLoadingPosition
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh, color: Color(0xFF0066FF)),
                        onPressed: _refreshLocationAndS2,
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildDataRow('Latitude', _currentPosition != null ? _currentPosition!.latitude.toStringAsFixed(6) : 'N/A'),
                  _buildDataRow('Longitude', _currentPosition != null ? _currentPosition!.longitude.toStringAsFixed(6) : 'N/A'),
                  _buildDataRow('GPS Accuracy', _currentPosition != null ? '±${_currentPosition!.accuracy.toStringAsFixed(1)} m' : 'N/A'),
                  _buildDataRow('Google S2 Cell Token', _s2CellToken, isHighlighted: true),
                  _buildDataRow('S2 Numeric Cell ID', _s2CellId),
                  _buildDataRow('Geofence Verification', '500 m (At Station QR) / 5 km (Outside Station) Active'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== RO2 TAB ====================
  Widget _buildRO2Tab() {
    final analysis = _currentFraudAnalysis;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(
            title: 'RO2 — Machine Learning Fraud Pattern Detector',
            subtitle: 'Identifies suspicious ticket booking patterns (GPS spoofing, impossible velocity, bot hoarding, boundary jumps).',
            icon: Icons.psychology_rounded,
            color: Colors.amber.shade900,
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Simulate Booking Pattern Features for Classifier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),

                  _buildSlider('Movement Speed: ${_simulatedSpeed.toStringAsFixed(0)} km/h', _simulatedSpeed, 0, 500, (v) {
                    setState(() => _simulatedSpeed = v);
                    _runFraudAnalysis();
                  }),

                  _buildSlider('Booking Interval: ${_simulatedIntervalSec.toStringAsFixed(0)} sec', _simulatedIntervalSec, 2, 600, (v) {
                    setState(() => _simulatedIntervalSec = v);
                    _runFraudAnalysis();
                  }),

                  _buildSlider('GPS Accuracy: ±${_simulatedGpsAccuracy.toStringAsFixed(0)} m', _simulatedGpsAccuracy, 5, 200, (v) {
                    setState(() => _simulatedGpsAccuracy = v);
                    _runFraudAnalysis();
                  }),

                  SwitchListTile(
                    activeColor: const Color(0xFF0066FF),
                    title: const Text('Simulate Offline Booking Mode'),
                    value: _isOfflineSimulated,
                    onChanged: (v) {
                      setState(() => _isOfflineSimulated = v);
                      _runFraudAnalysis();
                    },
                  ),

                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ActionChip(
                        label: const Text('Clean Pattern'),
                        backgroundColor: Colors.green.shade50,
                        avatar: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        onPressed: () {
                          setState(() {
                            _simulatedSpeed = 0.0;
                            _simulatedIntervalSec = 300.0;
                            _simulatedGpsAccuracy = 10.0;
                            _isOfflineSimulated = false;
                          });
                          _runFraudAnalysis();
                        },
                      ),
                      ActionChip(
                        label: const Text('GPS Spoofing (350km/h)'),
                        backgroundColor: Colors.red.shade50,
                        avatar: const Icon(Icons.warning, color: Colors.red, size: 16),
                        onPressed: () {
                          setState(() {
                            _simulatedSpeed = 380.0;
                            _simulatedIntervalSec = 10.0;
                            _simulatedGpsAccuracy = 120.0;
                            _isOfflineSimulated = false;
                          });
                          _runFraudAnalysis();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (analysis != null)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              color: analysis.riskLevel == FraudRiskLevel.fraudulent
                  ? Colors.red.shade50
                  : analysis.riskLevel == FraudRiskLevel.suspicious
                      ? Colors.amber.shade50
                      : Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ML Suspicious Risk Score: ${(analysis.riskScore * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: analysis.riskLevel == FraudRiskLevel.fraudulent
                                ? Colors.red.shade900
                                : analysis.riskLevel == FraudRiskLevel.suspicious
                                    ? Colors.amber.shade900
                                    : Colors.green.shade900,
                          ),
                        ),
                        Chip(
                          label: Text(
                            analysis.riskLevel.name.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          backgroundColor: analysis.riskLevel == FraudRiskLevel.fraudulent
                              ? Colors.red
                              : analysis.riskLevel == FraudRiskLevel.suspicious
                                  ? Colors.amber.shade900
                                  : Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Classification: ${analysis.primaryPatternDetected}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    const Text('Anomalies Detected:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ...analysis.flaggedAnomalies.map((a) => Text('• $a', style: const TextStyle(fontSize: 12, height: 1.4))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== RO3 TAB ====================
  Widget _buildRO3Tab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(
            title: 'RO3 — Passenger Acceptance, Privacy & Usability',
            subtitle: 'Evaluates passenger acceptance, privacy concerns, perceived security, and System Usability Scale (SUS).',
            icon: Icons.fact_check_rounded,
            color: Colors.teal.shade800,
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Submit Participant Evaluation (Likert Scale 1-5)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  _buildLikertSlider('Overall System Ease of Use (Usability)', _easeOfUse, (v) => setState(() => _easeOfUse = v)),
                  _buildLikertSlider('Location & Geofence Accuracy Satisfaction', _accuracySatisfaction, (v) => setState(() => _accuracySatisfaction = v)),
                  _buildLikertSlider('Perceived Security of Digital Ticket', _perceivedSecurity, (v) => setState(() => _perceivedSecurity = v)),
                  _buildLikertSlider('Location Privacy & Transparency Confidence', _privacyConfidence, (v) => setState(() => _privacyConfidence = v)),
                  _buildLikertSlider('Error Recovery & Intelligent Fallback', _errorRecoveryRating, (v) => setState(() => _errorRecoveryRating = v)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _feedbackController,
                    decoration: const InputDecoration(
                      hintText: 'Enter qualitative feedback or comments...',
                      border: OutlineInputBorder(),
                      labelText: 'Participant Comments',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _submitSurvey,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0066FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text('Submit Survey & Calculate SUS Score', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Participant Survey Responses:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ..._surveyList.map((s) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('SUS Usability Score: ${s.calculateSusScore.toStringAsFixed(1)} / 100', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0066FF))),
                  subtitle: Text('Usability: ${s.easeOfUse}/5 | Privacy: ${s.privacyConfidence}/5 | Security: ${s.perceivedSecurity}/5\n"${s.feedbackText.isEmpty ? 'No comment' : s.feedbackText}"'),
                  trailing: Text(s.timestamp.toIso8601String().substring(0, 10), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ),
              )),
        ],
      ),
    );
  }

  // ==================== RO4 TAB ====================
  Widget _buildRO4Tab() {
    final estimate = RevenueRecoveryService.calculateCustomModel(
      annualPassengers: _annualPassengers,
      baselineEvasionRatePercent: _evasionRatePercent,
      avgTicketFareRs: _avgFareRs,
      systemEfficiencyPercent: _systemEfficiencyPercent,
      falsePositiveRatePercent: _falsePositiveRate,
    );

    final recoveredCrores = estimate.estimatedAnnualRevenueRecovered / 10000000.0;
    final totalLossCrores = estimate.totalBaselineEvasionLoss / 10000000.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(
            title: 'RO4 — Revenue Recovery & Financial Impact Model',
            subtitle: 'Estimates potential revenue recovery and ticketless travel reduction through intelligent fraud prevention.',
            icon: Icons.account_balance_wallet_rounded,
            color: Colors.purple.shade800,
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Adjust Network Model Parameters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  _buildSlider('Annual Passengers: ${(_annualPassengers / 1000000).toStringAsFixed(0)} Million', _annualPassengers, 10000000, 3000000000, (v) {
                    setState(() => _annualPassengers = v);
                  }),
                  _buildSlider('Baseline Ticketless Rate: ${_evasionRatePercent.toStringAsFixed(1)}%', _evasionRatePercent, 1.0, 15.0, (v) {
                    setState(() => _evasionRatePercent = v);
                  }),
                  _buildSlider('Avg Ticket Fare: ₹${_avgFareRs.toStringAsFixed(0)}', _avgFareRs, 5.0, 100.0, (v) {
                    setState(() => _avgFareRs = v);
                  }),
                  _buildSlider('Fraud Prevention Efficiency: ${_systemEfficiencyPercent.toStringAsFixed(1)}%', _systemEfficiencyPercent, 50.0, 99.0, (v) {
                    setState(() => _systemEfficiencyPercent = v);
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildMetricCard('Annual Revenue Recovered', '₹ ${recoveredCrores.toStringAsFixed(1)} Cr', 'Recovered by fraud prevention', Icons.monetization_on_rounded, Colors.green),
              _buildMetricCard('Baseline Evasion Loss', '₹ ${totalLossCrores.toStringAsFixed(1)} Cr', 'Estimated baseline leakage', Icons.money_off_rounded, Colors.red),
              _buildMetricCard('Ticketless Reduction', '${estimate.effectiveEvasionReductionPercent.toStringAsFixed(2)}%', 'Overall reduction in evasion rate', Icons.trending_down_rounded, Colors.blue),
              _buildMetricCard('System Detection Rate', '${_systemEfficiencyPercent.toStringAsFixed(1)}%', 'Accuracy in stopping spoofing', Icons.security_rounded, Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard({required String title, required String subtitle, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isHighlighted ? const Color(0xFF0066FF) : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          activeColor: const Color(0xFF0066FF),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildLikertSlider(String label, int value, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text('$value / 5', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0066FF))),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: const Color(0xFF0066FF),
          onChanged: (v) => onChanged(v.toInt()),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String mainValue, String subText, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(mainValue, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(subText, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
