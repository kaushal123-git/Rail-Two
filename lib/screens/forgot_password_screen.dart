import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/loco_theme.dart';
import '../services/auth_database.dart';
import '../services/otp_service.dart';
import 'otp_verification_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _identifierController = TextEditingController();
  bool _isPhoneMode = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _sendResetOtp() async {
    final rawInput = _identifierController.text.trim();
    if (rawInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: LocoColors.error,
          content: Text('Please enter your registered mobile number or email'),
        ),
      );
      return;
    }

    if (_isPhoneMode && rawInput.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: LocoColors.error,
          content: Text('Please enter a valid 10-digit mobile number'),
        ),
      );
      return;
    }

    if (!_isPhoneMode && (!rawInput.contains('@') || !rawInput.contains('.'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: LocoColors.error,
          content: Text('Please enter a valid email address'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await OtpService().requestBackendOtp(
        phone: rawInput,
        purpose: 'RESET_PIN',
      );
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: LocoColors.textPrimary,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.lock_reset, color: LocoColors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reset code sent to $rawInput via SMS gateway',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              identifier: rawInput,
              purpose: OtpPurpose.forgotPassword,
              isPhone: _isPhoneMode,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: LocoColors.error,
            content: Text(res['message'] ?? 'Failed to send reset code.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: LocoColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: LocoColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: LocoColors.orangeLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset_rounded, color: LocoColors.orange, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'Forgot Your Password?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: LocoColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your registered details below and we will send a 6-digit OTP verification code to reset your password.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: LocoColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 32),

              // Toggle between Mobile and Email
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: LocoColors.canvas,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LocoColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isPhoneMode = true;
                            _identifierController.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isPhoneMode ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _isPhoneMode
                                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                : null,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.phone_android, size: 16, color: _isPhoneMode ? LocoColors.orange : LocoColors.textMuted),
                                const SizedBox(width: 6),
                                Text(
                                  'Mobile Number',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _isPhoneMode ? FontWeight.w800 : FontWeight.w600,
                                    color: _isPhoneMode ? LocoColors.textPrimary : LocoColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isPhoneMode = false;
                            _identifierController.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isPhoneMode ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !_isPhoneMode
                                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                : null,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.email_outlined, size: 16, color: !_isPhoneMode ? LocoColors.orange : LocoColors.textMuted),
                                const SizedBox(width: 6),
                                Text(
                                  'Email Address',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: !_isPhoneMode ? FontWeight.w800 : FontWeight.w600,
                                    color: !_isPhoneMode ? LocoColors.textPrimary : LocoColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Identifier Input Field
              if (_isPhoneMode)
                TextField(
                  controller: _identifierController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    prefixIcon: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🇮🇳 +91', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          SizedBox(width: 8),
                          VerticalDivider(width: 1, indent: 10, endIndent: 10),
                        ],
                      ),
                    ),
                    hintText: '98201 XXXXX',
                    filled: true,
                    fillColor: LocoColors.canvas,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: LocoColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: LocoColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: LocoColors.orange, width: 2),
                    ),
                  ),
                )
              else
                TextField(
                  controller: _identifierController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email_outlined, color: LocoColors.textSecondary),
                    hintText: 'commuter@example.com',
                    filled: true,
                    fillColor: LocoColors.canvas,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: LocoColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: LocoColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: LocoColors.orange, width: 2),
                    ),
                  ),
                ),

              const SizedBox(height: 28),

              // Send OTP Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendResetOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LocoColors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'SEND VERIFICATION CODE',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
                        ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Remembered your password? ', style: TextStyle(color: LocoColors.textSecondary, fontSize: 13)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Log In',
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
