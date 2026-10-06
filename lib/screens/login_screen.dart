import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../core/constants/loco_branding.dart';
import '../core/theme/loco_theme.dart';
import '../models/user_account.dart';
import '../services/api_service.dart';
import '../services/auth_database.dart';
import '../services/biometric_service.dart';
import '../services/otp_service.dart';
import 'forgot_password_screen.dart';
import 'main_navigation_shell.dart';
import 'otp_verification_screen.dart';
import 'signin_screen.dart';

enum LoginMode {
  mpin,
  password,
  otp,
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  TextEditingController _identifierController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  TextEditingController _mpinController = TextEditingController();

  LoginMode _currentMode = LoginMode.mpin;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _biometricsAvailable = false;
  UserAccount? _lastActiveUser;

  static void _noop() {}

  bool _isDisposed(TextEditingController controller) {
    try {
      controller.addListener(_noop);
      controller.removeListener(_noop);
      return false;
    } catch (_) {
      return true;
    }
  }

  void _ensureControllersValid() {
    if (_isDisposed(_identifierController)) {
      _identifierController = TextEditingController();
      if (_lastActiveUser != null) {
        _identifierController.text = _lastActiveUser!.phone ?? _lastActiveUser!.email ?? _lastActiveUser!.identifier;
      }
    }
    if (_isDisposed(_passwordController)) {
      _passwordController = TextEditingController();
    }
    if (_isDisposed(_mpinController)) {
      _mpinController = TextEditingController();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  @override
  void reassemble() {
    super.reassemble();
    _ensureControllersValid();
  }

  Future<void> _loadInitialState() async {
    final user = await AuthDatabase().getLastActiveUser();
    final canBiometric = await BiometricService().isBiometricsAvailable();

    if (mounted) {
      setState(() {
        _lastActiveUser = user;
        _biometricsAvailable = canBiometric;
        if (user != null) {
          _identifierController.text = user.phone ?? user.email ?? user.identifier;
        }
      });

      // If user has biometrics enabled and available, prompt once automatically
      if (canBiometric && (user?.biometricEnabled ?? true) && user != null) {
        _authenticateWithFingerprint(silent: true);
      }
    }
  }

  @override
  void dispose() {
    if (!_isDisposed(_identifierController)) {
      _identifierController.dispose();
    }
    if (!_isDisposed(_passwordController)) {
      _passwordController.dispose();
    }
    if (!_isDisposed(_mpinController)) {
      _mpinController.dispose();
    }
    super.dispose();
  }

  /// Fingerprint / Biometric Hardware Unlock
  Future<void> _authenticateWithFingerprint({bool silent = false}) async {
    if (!_biometricsAvailable) {
      if (!silent) {
        _showError('Biometric sensor not available on this device');
      }
      return;
    }

    try {
      final authenticated = await BiometricService().authenticate(
        reason: 'Scan your fingerprint to unlock LOCO',
      );

      if (authenticated) {
        if (_lastActiveUser != null) {
          await AuthDatabase().setActiveSession(_lastActiveUser!);
        }
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationShell()),
        );
      } else if (!silent) {
        _showError('Biometric authentication cancelled or not recognized');
      }
    } catch (e) {
      if (!silent) {
        _showError('Biometric error: $e');
      }
    }
  }

  /// Login with 4-digit MPIN
  Future<void> _loginWithMpin() async {
    final mpin = _mpinController.text.trim();
    if (mpin.length != 4) {
      _showError('Please enter your 4-digit MPIN');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phone = _identifierController.text.trim().isNotEmpty
          ? _identifierController.text.trim()
          : (_lastActiveUser?.phone ?? _lastActiveUser?.identifier ?? '');

      final isOnline = await ApiService.isServerAvailable();
      if (isOnline && phone.isNotEmpty && !phone.contains('@')) {
        final res = await ApiService.loginMpin(phone: phone, mpin: mpin);
        if (res['success'] == true) {
          final user = await AuthDatabase().authenticateWithMpin(
            mpin,
            rawIdentifier: phone,
          );
          if (user != null) {
            await AuthDatabase().setActiveSession(user);
          }
          if (!mounted) return;
          setState(() => _isLoading = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigationShell()),
          );
          return;
        } else if (res['statusCode'] == 401) {
          setState(() => _isLoading = false);
          _showError(res['message'] ?? 'Invalid MPIN. Please try again.');
          return;
        }
      }

      final user = await AuthDatabase().authenticateWithMpin(
        mpin,
        rawIdentifier: _identifierController.text.trim().isNotEmpty
            ? _identifierController.text.trim()
            : null,
      );

      if (user != null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationShell()),
        );
      } else {
        setState(() => _isLoading = false);
        _showError('Invalid MPIN. Please try again.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Login error: $e');
    }
  }

  /// Login with Password
  Future<void> _loginWithPassword() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty) {
      _showError('Please enter your mobile number or email');
      return;
    }
    if (password.isEmpty) {
      _showError('Please enter your password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await AuthDatabase().authenticateWithPassword(identifier, password);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationShell()),
        );
      } else {
        _showError('Invalid identifier or password. Please verify or reset.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: $e');
    }
  }

  /// Initiate Login with OTP
  Future<void> _loginWithOtp() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      _showError('Please enter your mobile number or email');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isPhone = !identifier.contains('@');
      final res = await OtpService().requestBackendOtp(
        phone: identifier,
        purpose: 'LOGIN',
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
                const Icon(Icons.mark_email_read_outlined, color: LocoColors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'OTP sent to $identifier via SMS gateway',
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
              identifier: identifier,
              purpose: OtpPurpose.directLogin,
              isPhone: isPhone,
            ),
          ),
        );
      } else {
        _showError(res['message'] ?? 'Failed to send OTP via server.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Login error: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
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
    _ensureControllersValid();
    final displayName = _lastActiveUser?.name ?? 'Commuter';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              LocoBranding.fullLogo(size: 130),
              const SizedBox(height: 4),
              Text(
                'Welcome Back, $displayName',
                style: const TextStyle(fontSize: 14, color: LocoColors.textSecondary, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 32),

              // Segmented Tabs: MPIN / Password / OTP
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: LocoColors.canvas,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LocoColors.border),
                ),
                child: Row(
                  children: [
                    _buildTab(LoginMode.mpin, 'MPIN Unlock'),
                    _buildTab(LoginMode.password, 'Password'),
                    _buildTab(LoginMode.otp, 'OTP Code'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Main Auth Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: LocoColors.canvas,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: LocoColors.border),
                ),
                child: Column(
                  children: [
                    if (_currentMode == LoginMode.mpin) ...[
                      KeyedSubtree(
                        key: const ValueKey('auth_mode_mpin'),
                        child: Column(
                          children: [
                            const Text(
                              'Enter 4-Digit MPIN',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: LocoColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Enter your 4-digit security PIN',
                              style: TextStyle(fontSize: 12, color: LocoColors.textMuted),
                            ),
                            const SizedBox(height: 24),

                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: PinCodeTextField(
                                key: const ValueKey('mpin_pin_code_field'),
                                appContext: context,
                                length: 4,
                                obscureText: true,
                                animationType: AnimationType.fade,
                                keyboardType: TextInputType.number,
                                autoDisposeControllers: false,
                                pinTheme: PinTheme(
                                  shape: PinCodeFieldShape.box,
                                  borderRadius: BorderRadius.circular(14),
                                  fieldHeight: 56,
                                  fieldWidth: 50,
                                  activeFillColor: Colors.white,
                                  inactiveFillColor: Colors.white,
                                  selectedFillColor: Colors.white,
                                  activeColor: LocoColors.orange,
                                  inactiveColor: LocoColors.border,
                                  selectedColor: LocoColors.orange,
                                ),
                                animationDuration: const Duration(milliseconds: 200),
                                enableActiveFill: true,
                                controller: _mpinController,
                                onCompleted: (v) => _loginWithMpin(),
                                onChanged: (value) {},
                              ),
                            ),

                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _loginWithMpin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: LocoColors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('UNLOCK LOCO', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_currentMode == LoginMode.password) ...[
                      KeyedSubtree(
                        key: const ValueKey('auth_mode_password'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Mobile Number or Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LocoColors.textPrimary)),
                            const SizedBox(height: 6),
                            TextField(
                              key: const ValueKey('password_identifier_field'),
                              controller: _identifierController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.person_outline, color: LocoColors.textSecondary),
                                hintText: '98201 XXXXX or user@mail.com',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.border)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.orange, width: 2)),
                              ),
                            ),

                            const SizedBox(height: 16),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LocoColors.textPrimary)),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                                    );
                                  },
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: LocoColors.orange),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              key: const ValueKey('password_input_field'),
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.lock_outline, color: LocoColors.textSecondary),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: LocoColors.textMuted),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                hintText: 'Enter account password',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.border)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.orange, width: 2)),
                              ),
                            ),

                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _loginWithPassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: LocoColors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('LOG IN WITH PASSWORD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      KeyedSubtree(
                        key: const ValueKey('auth_mode_otp'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Mobile Number or Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LocoColors.textPrimary)),
                            const SizedBox(height: 6),
                            TextField(
                              key: const ValueKey('otp_identifier_field'),
                              controller: _identifierController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.verified_user_outlined, color: LocoColors.textSecondary),
                                hintText: 'Enter registered phone or email',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.border)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LocoColors.orange, width: 2)),
                              ),
                            ),

                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _loginWithOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: LocoColors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('GET OTP CODE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Hardware Fingerprint Biometric Button
                    if (_biometricsAvailable) ...[
                      const SizedBox(height: 20),
                      const Row(
                        children: [
                          Expanded(child: Divider(color: LocoColors.border)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('OR BIOMETRICS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: LocoColors.textMuted)),
                          ),
                          Expanded(child: Divider(color: LocoColors.border)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => _authenticateWithFingerprint(),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: LocoColors.orange.withValues(alpha: 0.4), width: 1.5),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fingerprint_rounded, color: LocoColors.orange, size: 28),
                              SizedBox(width: 10),
                              Text(
                                'Scan Fingerprint to Unlock',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: LocoColors.orangeDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Forgot Password link (if not in password mode)
              if (_currentMode != LoginMode.password)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                    );
                  },
                  child: const Text(
                    'Forgot Password or MPIN?',
                    style: TextStyle(color: LocoColors.orange, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),

              // Sign Up Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('New commuter to LOCO? ', style: TextStyle(color: LocoColors.textSecondary, fontSize: 13)),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignInScreen()),
                      );
                    },
                    child: const Text(
                      'Create Account',
                      style: TextStyle(color: LocoColors.orange, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

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

  Widget _buildTab(LoginMode mode, String title) {
    final isSelected = _currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _ensureControllersValid();
          setState(() => _currentMode = mode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? LocoColors.textPrimary : LocoColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
