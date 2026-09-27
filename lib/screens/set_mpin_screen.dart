import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class SetMpinScreen extends StatefulWidget {
  final String phoneNumber;
  final String fullName;
  final bool isResetMode;

  const SetMpinScreen({
    super.key,
    this.phoneNumber = '9876543210',
    this.fullName = 'Rakhi Sinha',
    this.isResetMode = false,
  });

  @override
  State<SetMpinScreen> createState() => _SetMpinScreenState();
}

class _SetMpinScreenState extends State<SetMpinScreen> {
  final TextEditingController _mpinController = TextEditingController();
  final TextEditingController _confirmMpinController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _mpinController.dispose();
    _confirmMpinController.dispose();
    super.dispose();
  }

  Future<void> _setMpin() async {
    final mpin = _mpinController.text.trim();
    final confirmMpin = _confirmMpinController.text.trim();

    if (mpin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          content: const Text('Please enter a 6-digit mPIN'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (confirmMpin.length != 6 || mpin != confirmMpin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          content: const Text('mPIN and Confirm mPIN do not match'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    Map<String, dynamic> result;
    if (widget.isResetMode) {
      result = await AuthService.resetMpin(widget.phoneNumber, mpin);
    } else {
      result = await AuthService.registerUser(
        phone: widget.phoneNumber,
        name: widget.fullName,
        mpin: mpin,
      );
    }

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.isResetMode
                        ? 'mPIN Reset Successfully! Welcome back.'
                        : 'Welcome ${widget.fullName}! Account & mPIN registered successfully.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(result['message'] ?? 'Failed to set mPIN'),
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
        title: Text(
          widget.isResetMode ? 'Reset 6-Digit mPIN' : 'Set 6-Digit mPIN',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
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
                  child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF0066FF), size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.isResetMode ? 'Create New Security mPIN' : 'Set mPIN for Fast Security Login',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create a 6-digit security code for mobile login',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 30),
                
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Enter 6-Digit mPIN:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(height: 8),
                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  obscureText: true,
                  animationType: AnimationType.fade,
                  keyboardType: TextInputType.number,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(12),
                    fieldHeight: 50,
                    fieldWidth: 42,
                    activeFillColor: Colors.white,
                    inactiveFillColor: Colors.white,
                    selectedFillColor: Colors.white,
                    activeColor: const Color(0xFF0066FF),
                    inactiveColor: Colors.grey.shade300,
                    selectedColor: const Color(0xFF0066FF),
                  ),
                  animationDuration: const Duration(milliseconds: 300),
                  enableActiveFill: true,
                  controller: _mpinController,
                  onChanged: (value) {},
                ),

                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Confirm 6-Digit mPIN:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(height: 8),
                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  obscureText: true,
                  animationType: AnimationType.fade,
                  keyboardType: TextInputType.number,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(12),
                    fieldHeight: 50,
                    fieldWidth: 42,
                    activeFillColor: Colors.white,
                    inactiveFillColor: Colors.white,
                    selectedFillColor: Colors.white,
                    activeColor: const Color(0xFF0066FF),
                    inactiveColor: Colors.grey.shade300,
                    selectedColor: const Color(0xFF0066FF),
                  ),
                  animationDuration: const Duration(milliseconds: 300),
                  enableActiveFill: true,
                  controller: _confirmMpinController,
                  onCompleted: (v) {
                    _setMpin();
                  },
                  onChanged: (value) {},
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _setMpin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            widget.isResetMode ? 'Confirm & Reset mPIN' : 'Confirm mPIN & Complete Registration',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
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
