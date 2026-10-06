import 'api_service.dart';

/// Production-authoritative OTP Service for LOCO (Section 5, 6).
/// Enforces server-authoritative OTP generation and cryptographic verification.
/// Client-side mock OTP generation, hardcoded codes, and local verification maps removed.
class OtpService {
  static final OtpService _instance = OtpService._internal();
  factory OtpService() => _instance;
  OtpService._internal();

  /// Request a server-generated OTP from the LOCO Backend
  /// Backend enforces rate limits (max 5/hr), 60s cooldown, and SMS gateway dispatch.
  Future<Map<String, dynamic>> requestBackendOtp({
    required String phone,
    String purpose = 'LOGIN',
    String name = 'Commuter',
  }) async {
    return await ApiService.sendOtp(
      phone: phone,
      purpose: purpose,
      name: name,
    );
  }

  /// Verify entered OTP with the LOCO Backend authority
  /// Backend validates hash, enforces max attempts (3), rotates sessions, and registers device.
  Future<Map<String, dynamic>> verifyBackendOtp({
    required String phone,
    required String otp,
    String? deviceIdentifier,
    String? platform,
  }) async {
    return await ApiService.verifyOtp(
      phone: phone,
      otp: otp,
      deviceIdentifier: deviceIdentifier,
      platform: platform,
    );
  }
}
