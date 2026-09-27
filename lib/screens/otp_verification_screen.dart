import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../services/auth_service.dart';
import 'set_mpin_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String fullName;
  final String initialOtp;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.fullName = 'Rail Commuter',
    this.initialOtp = '123456',
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  Timer? _timer;
  int _startSeconds = 60;
  bool _isVerifying = false;
  late String _currentOtp;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.initialOtp;
    _startTimer();
  }

  void _startTimer() {
    _startSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startSeconds == 0) {
        setState(() {
          timer.cancel();
        });
      } else {
        setState(() {
          _startSeconds--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final enteredOtp = _otpController.text.trim();
    if (enteredOtp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          content: const Text('Please enter a 6-digit OTP code'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    final res = await AuthService.verifyOtp(
      phone: widget.phoneNumber,
      otp: enteredOtp,
    );

    setState(() {
      _isVerifying = false;
    });

    if (mounted) {
      if (res['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SetMpinScreen(
              phoneNumber: widget.phoneNumber,
              fullName: widget.fullName,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(res['message'] ?? 'Invalid OTP code'),
          ),
        );
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_startSeconds > 0) return;

    final res = await AuthService.sendOtp(
      phone: widget.phoneNumber,
      name: widget.fullName,
    );

    if (mounted) {
      if (res['success'] == true) {
        setState(() {
          _currentOtp = res['otp'] ?? '123456';
        });
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0066FF),
            behavior: SnackBarBehavior.floating,
            content: Text('New OTP sent to +91 ${widget.phoneNumber}: $_currentOtp'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(res['message'] ?? 'Failed to resend OTP'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5F1F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('OTP Verification', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF0066FF), size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  'Enter OTP Sent To',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                Text(
                  '+91 ${widget.phoneNumber}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                
                // Real Server OTP notification chip
                ActionChip(
                  avatar: const Icon(Icons.check_circle, color: Color(0xFF0066FF), size: 18),
                  label: Text(
                    'Tap to Autofill Server OTP ($_currentOtp)',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0066FF)),
                  ),
                  backgroundColor: Colors.blue.shade50,
                  side: BorderSide(color: Colors.blue.shade200),
                  onPressed: () {
                    setState(() {
                      _otpController.text = _currentOtp;
                    });
                    _verifyOtp();
                  },
                ),
                const SizedBox(height: 26),

                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  obscureText: false,
                  animationType: AnimationType.fade,
                  keyboardType: TextInputType.number,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(12),
                    fieldHeight: 52,
                    fieldWidth: 44,
                    activeFillColor: Colors.white,
                    inactiveFillColor: Colors.white,
                    selectedFillColor: Colors.white,
                    activeColor: const Color(0xFF0066FF),
                    inactiveColor: Colors.grey.shade300,
                    selectedColor: const Color(0xFF0066FF),
                  ),
                  animationDuration: const Duration(milliseconds: 300),
                  enableActiveFill: true,
                  controller: _otpController,
                  onCompleted: (v) {
                    _verifyOtp();
                  },
                  onChanged: (value) {},
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('Verify & Set mPIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),

                // Countdown Timer & Resend OTP
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Didn\'t receive OTP? ', style: TextStyle(color: Colors.grey.shade700)),
                    GestureDetector(
                      onTap: _startSeconds == 0 ? _resendOtp : null,
                      child: Text(
                        _startSeconds > 0 ? 'Resend in ${_startSeconds}s' : 'Resend OTP Now',
                        style: TextStyle(
                          color: _startSeconds == 0 ? const Color(0xFF0066FF) : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
