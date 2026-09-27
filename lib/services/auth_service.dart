import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class UserModel {
  final String phone;
  final String name;
  final String mpin;
  final bool isRegistered;
  final String? token;
  final double rwalletBalance;

  UserModel({
    required this.phone,
    required this.name,
    required this.mpin,
    required this.isRegistered,
    this.token,
    this.rwalletBalance = 100.0,
  });
}

class AuthService {
  static const String _keyPhone = 'user_phone';
  static const String _keyName = 'user_name';
  static const String _keyMpin = 'mpin';
  static const String _keyToken = 'jwt_token';
  static const String _keyIsRegistered = 'isRegistered';
  static const String _keyIsLoggedIn = 'isLoggedIn';
  static const String _keyRWalletBalance = 'rwallet_balance';

  /// Save newly registered user details locally & call backend API
  static Future<Map<String, dynamic>> registerUser({
    required String phone,
    required String name,
    required String mpin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Attempt backend registration
    final res = await ApiService.registerUser(
      phone: phone,
      name: name,
      mpin: mpin,
    );

    String token = '';
    if (res['success'] == true) {
      token = res['token'] ?? '';
    }

    // Save locally
    await prefs.setString(_keyPhone, phone);
    await prefs.setString(_keyName, name.isNotEmpty ? name : 'Rail Commuter');
    await prefs.setString(_keyMpin, mpin);
    if (token.isNotEmpty) {
      await prefs.setString(_keyToken, token);
    }
    await prefs.setBool(_keyIsRegistered, true);
    await prefs.setBool(_keyIsLoggedIn, true);

    return res;
  }

  /// Get currently stored user details
  static Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_keyPhone) ?? '';
    final name = prefs.getString(_keyName) ?? 'Rakhi Sinha';
    final mpin = prefs.getString(_keyMpin) ?? '';
    final token = prefs.getString(_keyToken);
    final isRegistered = prefs.getBool(_keyIsRegistered) ?? false;
    final rwalletBalance = prefs.getDouble(_keyRWalletBalance) ?? 100.0;

    if (!isRegistered && mpin.isEmpty && phone.isEmpty) return null;

    return UserModel(
      phone: phone.isNotEmpty ? phone : '9876543210',
      name: name.isNotEmpty ? name : 'Rakhi Sinha',
      mpin: mpin,
      isRegistered: isRegistered,
      token: token,
      rwalletBalance: rwalletBalance,
    );
  }

  /// Send OTP code via Backend API (or simulation)
  static Future<Map<String, dynamic>> sendOtp({
    required String phone,
    String name = 'Rail Commuter',
  }) async {
    final isOnline = await ApiService.isServerAvailable();
    if (isOnline) {
      return await ApiService.sendOtp(phone: phone, name: name);
    }
    
    // Offline simulated response
    return {
      'success': true,
      'otp': '123456',
      'message': 'Simulated OTP (123456) sent to +91 $phone',
    };
  }

  /// Verify OTP code via Backend API
  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final isOnline = await ApiService.isServerAvailable();
    if (isOnline) {
      return await ApiService.verifyOtp(phone: phone, otp: otp);
    }

    if (otp == '123456') {
      return {'success': true, 'message': 'OTP verified successfully.'};
    }
    return {'success': false, 'message': 'Invalid OTP entered.'};
  }

  /// Verify entered mPIN via Backend API or local storage check
  static Future<Map<String, dynamic>> verifyMpin(String enteredMpin) async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_keyPhone) ?? '9876543210';
    
    final isOnline = await ApiService.isServerAvailable();
    if (isOnline) {
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

    // Local fallback check
    final savedMpin = prefs.getString(_keyMpin);
    if (savedMpin == null || savedMpin.isEmpty) {
      final isValid = enteredMpin == '123456';
      if (isValid) await prefs.setBool(_keyIsLoggedIn, true);
      return {
        'success': isValid,
        'message': isValid ? 'Login successful' : 'Invalid mPIN',
      };
    }

    final isValid = enteredMpin == savedMpin;
    if (isValid) {
      await prefs.setBool(_keyIsLoggedIn, true);
      return {'success': true, 'message': 'Login successful'};
    }
    return {'success': false, 'message': 'Invalid mPIN. Please try again.'};
  }

  /// Reset mPIN locally & on backend API
  static Future<Map<String, dynamic>> resetMpin(String phone, String newMpin) async {
    final prefs = await SharedPreferences.getInstance();
    
    final isOnline = await ApiService.isServerAvailable();
    Map<String, dynamic> res = {'success': true};
    if (isOnline) {
      res = await ApiService.resetMpin(phone: phone, newMpin: newMpin);
    }

    await prefs.setString(_keyPhone, phone);
    await prefs.setString(_keyMpin, newMpin);
    await prefs.setBool(_keyIsRegistered, true);
    await prefs.setBool(_keyIsLoggedIn, true);

    return res;
  }

  /// Clear session data (Logout)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Check registration status
  static Future<bool> isRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    final registered = prefs.getBool(_keyIsRegistered) ?? false;
    final mpin = prefs.getString(_keyMpin);
    return registered || (mpin != null && mpin.isNotEmpty);
  }

  /// Alias for getCurrentUser
  static Future<UserModel?> getSavedUser() => getCurrentUser();

  /// Update saved R-Wallet balance locally
  static Future<void> updateWalletBalance(double newBalance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyRWalletBalance, newBalance);
  }
}
