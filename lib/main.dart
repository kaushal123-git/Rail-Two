import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RailwayFinderApp());
}

class RailwayFinderApp extends StatelessWidget {
  const RailwayFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rail S2 Finder',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Default to dark mode for premium aesthetics
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF0F111E), // Ultra-deep blue/indigo-black
        colorScheme: const ColorScheme.dark(
          primary: Colors.indigoAccent,
          secondary: Colors.tealAccent,
          surface: Color(0xFF1E2235), // Dark indigo-card color
          background: Color(0xFF0F111E),
          error: Colors.redAccent,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Outfit'),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Outfit'),
          bodyLarge: TextStyle(fontSize: 16, color: Color(0xFFC5C9E0)),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF8F94B5)),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E2235),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F111E),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
