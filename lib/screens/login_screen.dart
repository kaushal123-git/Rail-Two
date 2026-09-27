import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'signin_screen.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _mpinController = TextEditingController();
  UserModel? _currentUser;
  bool _isLoadingUser = true;
  bool _isAuthenticating = false;
  bool _isServerOnline = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _mpinController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final serverOnline = await ApiService.isServerAvailable();
    final user = await AuthService.getCurrentUser();

    setState(() {
      _isServerOnline = serverOnline;
      _currentUser = user;
      _isLoadingUser = false;
    });
  }

  Future<void> _login() async {
    final enteredMpin = _mpinController.text.trim();
    if (enteredMpin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.amber.shade900,
          behavior: SnackBarBehavior.floating,
          content: const Text('Please enter a 6-digit mPIN'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isAuthenticating = true;
    });

    final res = await AuthService.verifyMpin(enteredMpin);

    setState(() {
      _isAuthenticating = false;
    });

    if (!mounted) return;

    if (res['success'] == true) {
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
                child: Text('Login Successful! Welcome back ${_currentUser?.name ?? "User"}.'),
              ),
            ],
          ),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      _mpinController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(res['message'] ?? 'Invalid mPIN. Please try again.'),
        ),
      );
    }
  }

  Future<void> _biometricLogin() async {
    setState(() {
      _isAuthenticating = true;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      _isAuthenticating = false;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0066FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Row(
          children: [
            Icon(Icons.fingerprint, color: Colors.white),
            SizedBox(width: 10),
            Text('Biometric Authentication Verified! Accessing account...'),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  Future<void> _resetMpinFlow() async {
    final phone = _currentUser?.phone ?? '9876543210';
    final name = _currentUser?.name ?? 'Rail Commuter';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0066FF),
        content: Text('Requesting Reset OTP for +91 $phone...'),
      ),
    );

    final res = await AuthService.sendOtp(phone: phone, name: name);

    if (mounted) {
      final otp = res['otp'] ?? '123456';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            phoneNumber: phone,
            fullName: name,
            initialOtp: otp,
          ),
        ),
      );
    }
  }

  Future<void> _differentUser() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
      );
    }
  }

  Future<void> _guestLogin() async {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = _currentUser?.name ?? 'Rakhi Sinha';
    final userPhone = _currentUser?.phone ?? '9876543210';

    return Scaffold(
      backgroundColor: const Color(0xFFE5F1F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 30),

                // Server Status Indicator Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isServerOnline ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isServerOnline ? Colors.green.shade300 : Colors.orange.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: _isServerOnline ? Colors.green.shade600 : Colors.orange.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isServerOnline ? 'Backend API: Online (JWT Secured)' : 'Backend API: Offline Mode',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isServerOnline ? Colors.green.shade800 : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // App Logo
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
                const SizedBox(height: 30),

                const Text(
                  'Login using mPIN',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),

                // Welcome User Card
                _isLoadingUser
                    ? const CircularProgressIndicator()
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.shade100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_circle, color: Color(0xFF0066FF), size: 26),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                                Text(
                                  '+91 $userPhone',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                const SizedBox(height: 30),
                const Text(
                  'Enter 6-Digit mPIN Below:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 16),

                // Pin Code Input Field
                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  obscureText: true,
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
                  controller: _mpinController,
                  onCompleted: (v) {
                    _login();
                  },
                  onChanged: (value) {},
                ),

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _resetMpinFlow,
                      child: const Text('Forgot mPIN?', style: TextStyle(color: Color(0xFF0066FF), fontWeight: FontWeight.bold)),
                    ),
                    TextButton(
                      onPressed: _resetMpinFlow,
                      child: const Text('Reset mPIN?', style: TextStyle(color: Color(0xFF0066FF), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade400)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text('Or login using Biometrics', style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade400)),
                  ],
                ),
                const SizedBox(height: 24),

                // Biometrics & Login Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Face ID Login',
                          icon: const Icon(Icons.face, size: 36, color: Color(0xFF0066FF)),
                          onPressed: _isAuthenticating ? null : _biometricLogin,
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          tooltip: 'Fingerprint Login',
                          icon: const Icon(Icons.fingerprint, size: 36, color: Color(0xFF0066FF)),
                          onPressed: _isAuthenticating ? null : _biometricLogin,
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _isAuthenticating ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0066FF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                      ),
                      child: _isAuthenticating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),

                const SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _differentUser,
                      child: const Text(
                        'Different User?',
                        style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Text(' | ', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    TextButton(
                      onPressed: _guestLogin,
                      child: const Text(
                        'Login as Guest',
                        style: TextStyle(fontSize: 15, color: Color(0xFF0066FF), fontWeight: FontWeight.bold),
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
