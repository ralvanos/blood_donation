import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

class BloodDonationApp extends StatelessWidget {
  const BloodDonationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'blood_donation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scrollbarTheme: const ScrollbarThemeData(
          thickness: WidgetStatePropertyAll(0),
          thumbVisibility: WidgetStatePropertyAll(false),
          trackVisibility: WidgetStatePropertyAll(false),
          interactive: false,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE53935),
          secondary: Color(0xFFFF6B6B),
          surface: Color(0xFF0D0D0D),
          error: Color(0xFFE53935),
          onPrimary: Colors.white,
          onSurface: Colors.white,
          onSecondary: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}
