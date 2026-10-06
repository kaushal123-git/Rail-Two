import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../core/theme/loco_theme.dart';
import '../services/api_service.dart';
import '../services/auth_database.dart';
import '../services/otp_service.dart';
import 'main_navigation_shell.dart';
import 'reset_password_screen.dart';
import 'set_mpin_screen.dart';

enum OtpPurpose {
  registration,
  forgotPassword,
  directLogin,
}

class OtpVerificationScreen extends StatefulWidget {
  final String identifier;
  final OtpPurpose purpose;
  final bool isPhone;
  final Map<String, dynamic>? registrationPayload;

  const OtpVerificationScreen({
    super.key,
    required this.identifier,
    this.purpose = OtpPurpose.registration,
    this.isPhone = true,
    this.registrationPayload,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  int _secondsRemaining = 30;
  Timer? _timer;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _secondsRemaining = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: LocoColors.error,
          content: Text('Please enter the full 6-digit OTP code'),
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final res = await OtpService().verifyBackendOtp(
        phone: widget.identifier,
        otp: code,
      );

      if (!mounted) return;
      setState(() => _isVerifying = false);

      if (res['success'] == true) {
        final userData = res['user'] as Map<String, dynamic>?;
        final name = userData?['full_name'] as String? ?? 
            (widget.registrationPayload?['name'] as String? ?? 'Commuter');

        final userAccount = await AuthDatabase().registerUser(
          name: name,
          identifier: widget.identifier,
          phone: widget.identifier,
          password: widget.registrationPayload?['password'] as String? ?? '',
          biometricEnabled: true,
        );
        await AuthDatabase().setActiveSession(userAccount);

        if (widget.purpose == OtpPurpose.registration) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SetMpinScreen(
                identifier: userAccount.identifier,
                userName: userAccount.name,
              ),
            ),
          );
        } else if (widget.purpose == OtpPurpose.forgotPassword) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(identifier: widget.identifier),
            ),
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigationShell()),
            (route) => false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: LocoColors.error,
            content: Text(res['message'] ?? 'Invalid or expired OTP.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: LocoColors.error, content: Text('Error: $e')),
      );
    }
  }

  void _resendCode() async {
    if (_secondsRemaining > 0) return;

    _startCountdown();
    final res = await OtpService().requestBackendOtp(
      phone: widget.identifier,
      purpose: widget.purpose == OtpPurpose.registration ? 'REGISTRATION' : 'LOGIN',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: res['success'] == true ? LocoColors.textPrimary : LocoColors.error,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          content: Text(res['message'] ?? (res['success'] == true ? 'Verification code resent via SMS gateway' : 'Failed to resend OTP')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.purpose == OtpPurpose.forgotPassword
        ? 'Password Reset Verification'
        : widget.purpose == OtpPurpose.directLogin
            ? 'Sign In with OTP'
            : 'Account Verification';

    final destinationText = widget.isPhone
        ? '+91 ${widget.identifier}'
        : widget.identifier;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: LocoColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: LocoColors.textPrimary)),
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
                child: const Icon(Icons.mark_email_read_outlined, color: LocoColors.orange, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Enter 6-Digit Code',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: LocoColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Verification code sent to $destinationText',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: LocoColors.textSecondary),
              ),
              const SizedBox(height: 36),

              PinCodeTextField(
                appContext: context,
                length: 6,
                obscureText: false,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 54,
                  fieldWidth: 46,
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
                controller: _otpController,
                keyboardType: TextInputType.number,
                onCompleted: (v) => _verifyOtp(),
                onChanged: (value) {},
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LocoColors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isVerifying
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('VERIFY & CONTINUE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5)),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Didn\'t receive code? ', style: TextStyle(color: LocoColors.textSecondary, fontSize: 13)),
                  if (_secondsRemaining > 0)
                    Text(
                      'Resend in ${_secondsRemaining}s',
                      style: const TextStyle(color: LocoColors.textMuted, fontWeight: FontWeight.w700, fontSize: 13),
                    )
                  else
                    GestureDetector(
                      onTap: _resendCode,
                      child: const Text(
                        'Resend Code',
                        style: TextStyle(color: LocoColors.orange, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
