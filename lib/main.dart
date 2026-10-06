import 'package:flutter/material.dart';
import 'core/theme/loco_theme.dart';
import 'screens/main_navigation_shell.dart';
import 'services/loco_assist_service.dart';
import 'services/station_state_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize unified station state & assistant service
  await StationStateService().initialize();
  await LocoAssistService().initialize();

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
