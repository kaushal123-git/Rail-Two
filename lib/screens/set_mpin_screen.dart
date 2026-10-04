import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/loco_theme.dart';
import '../services/auth_database.dart';
import '../services/biometric_service.dart';
import 'main_navigation_shell.dart';

class SetMpinScreen extends StatefulWidget {
  final String? identifier;
  final String? userName;

  const SetMpinScreen({super.key, this.identifier, this.userName});

  @override
  State<SetMpinScreen> createState() => _SetMpinScreenState();
}

class _SetMpinScreenState extends State<SetMpinScreen> {
  final TextEditingController _mpinController = TextEditingController();
  bool _enableBiometrics = true;
  bool _biometricsSupported = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await BiometricService().isBiometricsAvailable();
    if (mounted) {
      setState(() {
        _biometricsSupported = available;
        _enableBiometrics = available;
      });
    }
  }

  @override
  void dispose() {
    _mpinController.dispose();
    super.dispose();
  }

  Future<void> _saveMpinAndFinish() async {
    final mpin = _mpinController.text.trim();
    if (mpin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: LocoColors.error,
          content: Text('Please enter a 4-digit security MPIN'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final identifier = widget.identifier ??
          (await SharedPreferences.getInstance()).getString('loco_active_user_identifier') ??
          '';

      if (identifier.isNotEmpty) {
        await AuthDatabase().updateMpin(identifier, mpin);
        await AuthDatabase().setBiometricEnabled(identifier, _enableBiometrics);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('mpin', mpin);
        await prefs.setBool('isRegistered', true);
        await prefs.setBool('biometric_enabled', _enableBiometrics);
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: LocoColors.success,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Welcome, ${widget.userName ?? "Commuter"}! Your MPIN is set.'),
              ),
            ],
          ),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationShell()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: LocoColors.error, content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Set 4-Digit MPIN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: LocoColors.textPrimary)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: LocoColors.orangeLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline, color: LocoColors.orange, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Create Passcode',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: LocoColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Set a 4-digit MPIN for instant, frictionless unlocking of LOCO.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: LocoColors.textSecondary),
              ),
              const SizedBox(height: 36),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: PinCodeTextField(
                  appContext: context,
                  length: 4,
                  obscureText: true,
                  animationType: AnimationType.fade,
                  keyboardType: TextInputType.number,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(14),
                    fieldHeight: 58,
                    fieldWidth: 54,
                    activeFillColor: Colors.white,
                    inactiveFillColor: LocoColors.canvas,
                    selectedFillColor: Colors.white,
                    activeColor: LocoColors.orange,
                    inactiveColor: LocoColors.border,
                    selectedColor: LocoColors.orange,
                  ),
                  animationDuration: const Duration(milliseconds: 200),
                  enableActiveFill: true,
                  autoDisposeControllers: false,
                  controller: _mpinController,
                  onCompleted: (v) => _saveMpinAndFinish(),
                  onChanged: (value) {},
                ),
              ),

              const SizedBox(height: 32),

              // Biometric Lock Toggle
              if (_biometricsSupported)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: LocoColors.canvas,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: LocoColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: LocoColors.orangeLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.fingerprint, color: LocoColors.orange, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fingerprint / Biometric Lock',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: LocoColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Quickly unlock LOCO with your sensor',
                              style: TextStyle(fontSize: 12, color: LocoColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _enableBiometrics,
                        activeThumbColor: LocoColors.orange,
                        onChanged: (val) => setState(() => _enableBiometrics = val),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveMpinAndFinish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LocoColors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text(
                          'CONFIRM & START COMMUTING',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
