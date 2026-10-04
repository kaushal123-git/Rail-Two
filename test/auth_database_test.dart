import 'package:flutter_test/flutter_test.dart';
import 'package:railway_station_finder/services/auth_database.dart';
import 'package:railway_station_finder/services/otp_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AuthDatabase and OtpService Tests', () {
    final authDb = AuthDatabase();
    final otpService = OtpService();

    test('OTP Generation and Verification works correctly', () {
      const phone = '9820154321';
      final otp = otpService.generateOtp(phone);
      expect(otp.length, 6);

      // Verify wrong code fails
      expect(otpService.verifyOtp(phone, '000000'), isFalse);

      // Verify correct code passes
      expect(otpService.verifyOtp(phone, otp), isTrue);

      // Verify code is consumed and cannot be reused
      expect(otpService.verifyOtp(phone, otp), isFalse);

      // Default demo fallback code 123456 always passes
      expect(otpService.verifyOtp(phone, '123456'), isTrue);
    });

    test('User Registration and Password Authentication in SQLite', () async {
      const testIdentifier = 'test_commuter_99@rail.in';
      const testPassword = 'Password@123';

      final user = await authDb.registerUser(
        name: 'Test Commuter',
        identifier: testIdentifier,
        email: testIdentifier,
        password: testPassword,
        mpin: '4321',
      );

      expect(user.name, 'Test Commuter');
      expect(user.identifier, testIdentifier);

      // Check existence
      final exists = await authDb.userExists(testIdentifier);
      expect(exists, isTrue);

      // Authenticate with right password
      final authResult = await authDb.authenticateWithPassword(testIdentifier, testPassword);
      expect(authResult, isNotNull);
      expect(authResult!.name, 'Test Commuter');

      // Authenticate with wrong password fails
      final wrongAuth = await authDb.authenticateWithPassword(testIdentifier, 'WrongPassword');
      expect(wrongAuth, isNull);

      // Authenticate with MPIN
      final mpinAuth = await authDb.authenticateWithMpin('4321', rawIdentifier: testIdentifier);
      expect(mpinAuth, isNotNull);
    });

    test('Forgot Password Flow: Updates password in SQLite', () async {
      const testIdentifier = 'reset_user@rail.in';
      const oldPassword = 'OldPassword123';
      const newPassword = 'NewSecretPassword456';

      await authDb.registerUser(
        name: 'Reset Commuter',
        identifier: testIdentifier,
        password: oldPassword,
      );

      // Update password
      final updated = await authDb.updatePassword(testIdentifier, newPassword);
      expect(updated, isTrue);

      // Old password should now fail
      final oldAuth = await authDb.authenticateWithPassword(testIdentifier, oldPassword);
      expect(oldAuth, isNull);

      // New password should succeed
      final newAuth = await authDb.authenticateWithPassword(testIdentifier, newPassword);
      expect(newAuth, isNotNull);
      expect(newAuth!.name, 'Reset Commuter');
    });
  });
}
