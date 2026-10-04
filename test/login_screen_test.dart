import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railway_station_finder/core/theme/loco_theme.dart';
import 'package:railway_station_finder/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen tab switching does not dispose controllers and renders single card', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LocoTheme.lightTheme,
        home: const LoginScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // 1. Initial State: MPIN Unlock tab is active
    expect(find.text('Enter 4-Digit MPIN'), findsOneWidget);
    expect(find.text('Demo default PIN: 1234'), findsOneWidget);
    expect(find.text('UNLOCK LOCO'), findsOneWidget);
    expect(find.text('GET OTP CODE'), findsNothing);
    expect(find.text('LOG IN WITH PASSWORD'), findsNothing);

    // 2. Switch to OTP Code tab
    await tester.tap(find.text('OTP Code'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('GET OTP CODE'), findsOneWidget);
    expect(find.text('Enter 4-Digit MPIN'), findsNothing);
    expect(find.text('Demo default PIN: 1234'), findsNothing);
    expect(find.text('LOG IN WITH PASSWORD'), findsNothing);

    // 3. Switch to Password tab
    await tester.tap(find.text('Password'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('LOG IN WITH PASSWORD'), findsOneWidget);
    expect(find.text('GET OTP CODE'), findsNothing);
    expect(find.text('Enter 4-Digit MPIN'), findsNothing);

    // 4. Switch BACK to MPIN Unlock tab (Verifies controller is not used after disposal)
    await tester.tap(find.text('MPIN Unlock'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Enter 4-Digit MPIN'), findsOneWidget);
    expect(find.text('Demo default PIN: 1234'), findsOneWidget);
    expect(find.text('UNLOCK LOCO'), findsOneWidget);
    expect(find.text('GET OTP CODE'), findsNothing);

    // No exceptions thrown, all single instance widgets cleanly mounted
    await tester.pumpWidget(const SizedBox());
  });
}
