import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railway_station_finder/main.dart';
import 'package:railway_station_finder/screens/main_navigation_shell.dart';
import 'package:railway_station_finder/simulation/train_simulation_engine.dart';

void main() {
  tearDown(() {
    TrainSimulationEngine().stopSimulation();
  });

  testWidgets('LocoApp builds and mounts MainNavigationShell with Home, My Tickets, LOCOpilot, Live Routes, and Profile', (WidgetTester tester) async {
    await tester.pumpWidget(const LocoApp(initialScreen: MainNavigationShell()));
    await tester.pump();

    // Verify navigation tabs matching UI/Home.png
    expect(find.text('Home'), findsWidgets);
    expect(find.text('My Tickets'), findsOneWidget);
    expect(find.text('LOCOpilot'), findsOneWidget);
    expect(find.text('Live Routes'), findsWidgets);
    expect(find.text('Profile'), findsOneWidget);

    // Teardown widget tree so periodic simulation timers are cleanly disposed
    TrainSimulationEngine().stopSimulation();
    await tester.pumpWidget(const SizedBox());
  });
}
