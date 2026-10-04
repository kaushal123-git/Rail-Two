import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/loco_branding.dart';
import '../core/theme/loco_theme.dart';
import '../services/auth_database.dart';
import '../services/otp_service.dart';
import 'login_screen.dart';
import 'main_navigation_shell.dart';
import 'otp_verification_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isPhoneMode = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty) {
      _showError('Please enter your full name');
      return;
    }

    if (_isPhoneMode && identifier.length != 10) {
      _showError('Please enter a valid 10-digit mobile number');
      return;
    }

    if (!_isPhoneMode && (!identifier.contains('@') || !identifier.contains('.'))) {
      _showError('Please enter a valid email address');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters long');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final exists = await AuthDatabase().userExists(identifier);
      if (!mounted) return;

      if (exists) {
        setState(() => _isLoading = false);
        _showError('An account with this ${_isPhoneMode ? "mobile number" : "email"} already exists. Please log in.');
        return;
      }

      // Generate 6-digit OTP
      final otp = OtpService().generateOtp(identifier);
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: LocoColors.textPrimary,
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.mark_email_read_outlined, color: LocoColors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'LOCO Verification Code: $otp (Valid for 5 mins)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );

      final payload = {
        'name': name,
        'identifier': identifier,
        'phone': _isPhoneMode ? identifier : null,
        'email': !_isPhoneMode ? identifier : null,
        'password': password,
      };

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            identifier: identifier,
            purpose: OtpPurpose.registration,
            isPhone: _isPhoneMode,
            registrationPayload: payload,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: LocoColors.error,
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  void _guestLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigationShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              LocoBranding.fullLogo(size: 130),
              const SizedBox(height: 4),
              const Text(
                LocoBranding.tagline,
                style: TextStyle(fontSize: 13, color: LocoColors.textMuted, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 28),

              // Sign Up Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: LocoColors.canvas,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: LocoColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create Account',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: LocoColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sign up to verify via OTP, unlock tickets, and save journeys.',
                      style: TextStyle(fontSize: 13, color: LocoColors.textSecondary),
                    ),
                    const SizedBox(height: 20),

                    // Full Name Field
                    const Text('Full Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LocoColors.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline, color: LocoColors.textSecondary),
                        hintText: 'e.g. Aayush Sinha',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.orange, width: 2)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Segmented Toggle: Mobile vs Email
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isPhoneMode ? 'Mobile Number' : 'Email Address',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LocoColors.textPrimary),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isPhoneMode = !_isPhoneMode;
                              _identifierController.clear();
                            });
                          },
                          child: Text(
                            _isPhoneMode ? 'Use Email instead' : 'Use Mobile instead',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: LocoColors.orange),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

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
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.orange, width: 2)),
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
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.orange, width: 2)),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Password Field
                    const Text('Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LocoColors.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline, color: LocoColors.textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: LocoColors.textMuted),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        hintText: 'Min. 6 characters',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.orange, width: 2)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Confirm Password Field
                    const Text('Confirm Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LocoColors.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_reset, color: LocoColors.textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: LocoColors.textMuted),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        hintText: 'Re-enter password',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.orange, width: 2)),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Sign Up / Get OTP Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LocoColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('PROCEED WITH OTP', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Existing user MPIN Login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? ', style: TextStyle(color: LocoColors.textSecondary, fontSize: 13)),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      'Log In',
                      style: TextStyle(color: LocoColors.orange, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Skip / Guest Login
              TextButton(
                onPressed: _guestLogin,
                child: const Text(
                  'Explore as Guest →',
                  style: TextStyle(color: LocoColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
