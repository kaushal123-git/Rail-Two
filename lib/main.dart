import 'package:flutter/material.dart';
import 'core/theme/loco_theme.dart';
import 'screens/main_navigation_shell.dart';
import 'screens/splash_screen.dart';
import 'services/gemini_rail_service.dart';
import 'services/station_state_service.dart';
import 'simulation/train_simulation_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-warm the deterministic train simulation engine
  TrainSimulationEngine().startSimulation();

  // Initialize unified station state & AI preferences
  await StationStateService().initialize();
  await GeminiRailService().initialize();

  runApp(const LocoApp());
}

class LocoApp extends StatelessWidget {
  final Widget initialScreen;

  const LocoApp({
    super.key,
    this.initialScreen = const MainNavigationShell(),
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LOCO',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: LocoTheme.lightTheme,
      home: initialScreen,
    );
  }
}
