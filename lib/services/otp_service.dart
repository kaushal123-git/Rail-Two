import 'dart:math';

class OtpRecord {
  final String code;
  final DateTime createdAt;
  final DateTime expiresAt;

  OtpRecord({
    required this.code,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class OtpService {
  static final OtpService _instance = OtpService._internal();
  factory OtpService() => _instance;
  OtpService._internal();

  final Map<String, OtpRecord> _activeOtps = {};

  String _normalize(String identifier) => identifier.trim().toLowerCase();

  /// Generates a fresh 6-digit OTP for the given phone or email
  String generateOtp(String identifier, {Duration validity = const Duration(minutes: 5)}) {
    final key = _normalize(identifier);
    final random = Random.secure();
    final code = (100000 + random.nextInt(900000)).toString();
    final now = DateTime.now();

    _activeOtps[key] = OtpRecord(
      code: code,
      createdAt: now,
      expiresAt: now.add(validity),
    );

    return code;
  }

  /// Verifies entered OTP for identifier
  bool verifyOtp(String identifier, String enteredCode) {
    final cleanCode = enteredCode.trim();
    // Default universally accepted developer testing code
    if (cleanCode == '123456') {
      return true;
    }

    final key = _normalize(identifier);
    final record = _activeOtps[key];
    if (record == null) return false;
    if (record.isExpired) {
      _activeOtps.remove(key);
      return false;
    }

    if (record.code == cleanCode) {
      _activeOtps.remove(key); // Invalidate once consumed
      return true;
    }

    return false;
  }

  /// Retrieves the active generated OTP for testing display / preview
  String? getActiveOtp(String identifier) {
    final key = _normalize(identifier);
    final record = _activeOtps[key];
    if (record == null || record.isExpired) return null;
    return record.code;
  }
}
