import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'otp_verification_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();

    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text(
            'Please enter a valid 10-digit mobile number',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final formattedName = name.isNotEmpty ? name : 'Rail Commuter';
    final result = await AuthService.sendOtp(phone: phone, name: formattedName);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (result['success'] == true) {
        final serverOtp = result['otp'] ?? '123456';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0066FF),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.mark_email_read, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SMS Sent! Your OTP is $serverOtp',
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
              phoneNumber: phone,
              fullName: formattedName,
              initialOtp: serverOtp,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(result['message'] ?? 'Failed to send OTP'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5F1F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                
                // Logo & Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0066FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.train_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Rail',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Text(
                      'One',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0066FF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                
                // Registered user Login Here Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_circle, color: Color(0xFF0066FF), size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Registered user?',
                            style: TextStyle(fontSize: 15, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: const Row(
                            children: [
                              Text(
                                'Login Here',
                                style: TextStyle(fontSize: 14, color: Color(0xFF0066FF), fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, color: Color(0xFF0066FF), size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // New User Registration Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6E6F2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'New User Registration',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter mobile number to get backend OTP',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 20),
                      
                      // Full Name Field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            icon: Icon(Icons.person_outline, color: Color(0xFF0066FF)),
                            hintText: 'Full Name (e.g. Rakhi Sinha)',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Mobile Number Field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Icon(Icons.phone_android, color: Color(0xFF0066FF)),
                            ),
                            Container(
                              height: 24,
                              width: 1,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                decoration: const InputDecoration(
                                  hintText: '10-Digit Mobile Number',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Register Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _onRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0066FF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text('Register & Get OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Text(
                        'Or Register with',
                        style: TextStyle(fontSize: 14, color: Color(0xFF0066FF), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () {
                              _phoneController.text = '9876543210';
                              _nameController.text = 'Rakhi Sinha';
                              _onRegister();
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: const Icon(Icons.train, color: Colors.purple, size: 26),
                                ),
                                const SizedBox(height: 6),
                                const Text('Rail Connect', style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 40),
                          InkWell(
                            onTap: () {
                              _phoneController.text = '9876543210';
                              _nameController.text = 'Rakhi Sinha';
                              _onRegister();
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: const Icon(Icons.subway_rounded, color: Colors.orange, size: 26),
                                ),
                                const SizedBox(height: 6),
                                const Text('UTS App', style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'To use your existing UTS RWallet, please use the same mobile number registered with UTS App',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'By continuing, you agree to our Terms Of Use & Privacy Policy',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                
                // Guest Login
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Login as ', style: TextStyle(fontSize: 15, color: Colors.black87)),
                        Text('Guest', style: TextStyle(fontSize: 15, color: Color(0xFF0066FF), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
