import 'package:flutter_test/flutter_test.dart';
import 'package:railway_station_finder/services/auth_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AuthDatabase Tests', () {
    final authDb = AuthDatabase();

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
