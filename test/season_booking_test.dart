import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railway_station_finder/core/constants/loco_branding.dart';
import 'package:railway_station_finder/models/station.dart';
import 'package:railway_station_finder/screens/season_booking_screen.dart';

void main() {
  testWidgets('LocoBranding wordmark renders brand title', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LocoBranding.wordmark(fontSize: 28, showDot: true),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('SeasonBookingScreen renders configuration screen matching Screenshot 2', (WidgetTester tester) async {
    final virar = RailwayStation(
      id: 'virar',
      name: 'VIRAR',
      latitude: 19.4559,
      longitude: 72.8106,
    );
    final borivali = RailwayStation(
      id: 'borivali',
      name: 'BORIVALI',
      latitude: 19.2307,
      longitude: 72.8567,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SeasonBookingScreen(
          initialFromStation: virar,
          initialToStation: borivali,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Header Route Banner
    expect(find.text('VIRAR'), findsOneWidget);
    expect(find.text('VR'), findsOneWidget);
    expect(find.text('BORIVALI'), findsOneWidget);
    expect(find.text('BVI'), findsOneWidget);

    // 2. Train Type
    expect(find.text('Train Type'), findsOneWidget);
    expect(find.text('ORDINARY'), findsOneWidget);
    expect(find.text('MAIL/EXP'), findsOneWidget);
    expect(find.text('Others'), findsOneWidget);

    // 3. Duration
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('MONTHLY'), findsOneWidget);
    expect(find.text('QUARTERLY'), findsOneWidget);
    expect(find.text('HALF YEARLY'), findsOneWidget);
    expect(find.text('YEARLY'), findsOneWidget);

    // 4. Passenger Details Card
    expect(find.text('Passenger Details'), findsOneWidget);
    expect(find.text('+ Add ID'), findsOneWidget);
    expect(find.text('Rakhi sinha. 46 yrs, F'), findsOneWidget);
    expect(find.textContaining('006-yashwant sneh'), findsOneWidget);

    // 5. Class
    expect(find.text('Class'), findsOneWidget);
    expect(find.text('SECOND'), findsOneWidget);
    expect(find.text('FIRST'), findsOneWidget);

    // 6. Concession Toggle
    expect(find.text('Avail Concession'), findsOneWidget);

    // 7. Sticky Bottom Bar with dynamic fare
    expect(find.text('Total Fare'), findsOneWidget);
    expect(find.text('₹ 215'), findsOneWidget);
    expect(find.text('Fare Breakup'), findsOneWidget);
    expect(find.text('Proceed to Pay'), findsOneWidget);

    // Test Concession Fare update
    await tester.ensureVisible(find.text('Avail Concession'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avail Concession'));
    await tester.pumpAndSettle();
    expect(find.text('₹ 108'), findsOneWidget); // 50% concession on 215 = 108

    // Test Class selection update (First Class)
    await tester.ensureVisible(find.text('FIRST'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FIRST'));
    await tester.pumpAndSettle();
    expect(find.text('₹ 335'), findsOneWidget); // 50% concession on 670 = 335
  });
}
