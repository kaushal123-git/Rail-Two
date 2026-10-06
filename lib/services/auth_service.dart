import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class UserModel {
  final String phone;
  final String name;
  final String mpin;
  final bool isRegistered;
  final String? token;
  final String? refreshToken;
  final double rwalletBalance;
  final String? email;
  final String? profileImageUrl;

  UserModel({
    required this.phone,
    required this.name,
    required this.mpin,
    required this.isRegistered,
    this.token,
    this.refreshToken,
    this.rwalletBalance = 0.0,
    this.email,
    this.profileImageUrl,
  });
}

/// Abstract contract for authentication.
abstract class AuthRepository {
  Future<UserModel?> getCurrentUser();
  Future<bool> isLoggedIn();
  Future<void> logout();
}

/// Production-ready Authentication Service for LOCO.
/// Connects to the LOCO FastAPI Backend, PostgreSQL User/Session records, and OTP flow.
class AuthService {
  static const String _keyPhone = 'user_phone';
  static const String _keyName = 'user_name';
  static const String _keyEmail = 'user_email';
  static const String _keyToken = 'jwt_token';
  static const String _keyRefreshToken = 'jwt_refresh_token';
  static const String _keyIsRegistered = 'isRegistered';
  static const String _keyIsLoggedIn = 'isLoggedIn';
  static const String _keyRWalletBalance = 'rwallet_balance';

  /// Register or verify user via Backend API and save local session cache
  static Future<Map<String, dynamic>> registerUser({
    required String phone,
    required String name,
    required String mpin,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final isOnline = await ApiService.isServerAvailable();
    if (isOnline) {
      final res = await ApiService.loginMpin(
        phone: phone,
        mpin: mpin,
      );

      String token = '';
      if (res['success'] == true) {
        token = res['token'] ?? '';
        final userMap = res['user'] as Map<String, dynamic>?;

        await prefs.setString(_keyPhone, phone);
        await prefs.setString(_keyName, (userMap?['full_name'] ?? name).isNotEmpty ? (userMap?['full_name'] ?? name) : 'Commuter');
        if (token.isNotEmpty) {
          await prefs.setString(_keyToken, token);
        }
        if (res['refreshToken'] != null) {
          await prefs.setString(_keyRefreshToken, res['refreshToken']);
        }
        await prefs.setBool(_keyIsRegistered, true);
        await prefs.setBool(_keyIsLoggedIn, true);

        // Register device on backend
        await ApiService.registerDevice(
          deviceIdentifier: 'loco-device-${phone.replaceAll('+', '')}',
          platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
        );
      }

      return res;
    }

    return {
      'success': false,
      'message': 'LOCO backend authentication service is unreachable. Please verify server connectivity.',
    };
  }

  /// Get currently stored user details.
  /// If online and authenticated, synchronizes latest profile from backend.
  static Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    final phone = prefs.getString(_keyPhone);
    final name = prefs.getString(_keyName);
    final email = prefs.getString(_keyEmail);
    final token = await ApiService.getAccessToken() ?? prefs.getString(_keyToken);
    final isRegistered = prefs.getBool(_keyIsRegistered) ?? false;
    final rwalletBalance = prefs.getDouble(_keyRWalletBalance) ?? 0.0;

    if (!isLoggedIn || phone == null || phone.isEmpty) {
      return null;
    }

    return UserModel(
      phone: phone,
      name: (name != null && name.isNotEmpty) ? name : 'Commuter',
      email: email,
      mpin: '', // Plaintext mPIN never stored locally
      isRegistered: isRegistered,
      token: token,
      rwalletBalance: rwalletBalance,
    );
  }

  /// Send OTP code via Backend API
  static Future<Map<String, dynamic>> sendOtp({
    required String phone,
    String name = 'Commuter',
    String purpose = 'LOGIN',
  }) async {
    return await ApiService.sendOtp(phone: phone, name: name, purpose: purpose);
  }

  /// Verify OTP code via Backend API and create/register session
  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final res = await ApiService.verifyOtp(phone: phone, otp: otp);
    if (res['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      final user = res['user'] as Map<String, dynamic>?;

      await prefs.setString(_keyPhone, phone);
      if (user != null) {
        if (user['full_name'] != null) await prefs.setString(_keyName, user['full_name']);
        if (user['email'] != null) await prefs.setString(_keyEmail, user['email']);
        if (user['wallet_balance'] != null) {
          await prefs.setDouble(_keyRWalletBalance, (user['wallet_balance'] as num).toDouble());
        }
      }
      await prefs.setBool(_keyIsRegistered, true);
      await prefs.setBool(_keyIsLoggedIn, true);

      // Register device with backend authority
      await ApiService.registerDevice(
        deviceIdentifier: 'loco-device-${phone.replaceAll('+', '')}',
        platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
      );
    }
    return res;
  }

  /// Verify entered mPIN via Backend API
  static Future<Map<String, dynamic>> verifyMpin(String enteredMpin) async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_keyPhone);

    if (phone == null || phone.isEmpty) {
      return {
        'success': false,
        'message': 'No registered account found. Please sign up or log in with mobile number.',
      };
    }

    final res = await ApiService.loginMpin(phone: phone, mpin: enteredMpin);
    if (res['success'] == true) {
      if (res['token'] != null) {
        await prefs.setString(_keyToken, res['token']);
      }
      await prefs.setBool(_keyIsLoggedIn, true);
      return {'success': true, 'message': 'Login successful'};
    } else {
      return {
        'success': false,
        'message': res['message'] ?? 'Invalid mPIN',
        'statusCode': res['statusCode'],
      };
    }
  }

  /// Reset mPIN with backend validation
  static Future<Map<String, dynamic>> resetMpin(String phone, String newMpin, {String? otpCode}) async {
    final prefs = await SharedPreferences.getInstance();
    final res = await ApiService.resetMpin(phone: phone, newMpin: newMpin, otpCode: otpCode);
    if (res['success'] == true) {
      await prefs.setString(_keyPhone, phone);
      await prefs.setBool(_keyIsRegistered, true);
      await prefs.setBool(_keyIsLoggedIn, true);
    }
    return res;
  }

  /// Clear session data (Logout) and revoke backend session
  static Future<void> logout() async {
    await ApiService.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRefreshToken);
  }

  /// Check registration status
  static Future<bool> isRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsRegistered) ?? false;
  }

  /// Alias for getCurrentUser
  static Future<UserModel?> getSavedUser() => getCurrentUser();

  /// Update saved R-Wallet balance locally
  static Future<void> updateWalletBalance(double newBalance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyRWalletBalance, newBalance);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }
}

/// Local implementation of AuthRepository wrapping AuthService.
class LocalAuthRepository implements AuthRepository {
  @override
  Future<UserModel?> getCurrentUser() => AuthService.getCurrentUser();

  @override
  Future<bool> isLoggedIn() => AuthService.isLoggedIn();

  @override
  Future<void> logout() => AuthService.logout();
}
