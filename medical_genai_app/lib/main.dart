import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const MedicalGenAIApp());
}

class MedicalGenAIApp extends StatelessWidget {
  const MedicalGenAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Clinical Theme Colors
    const primaryColor = Color(0xFF0D9488); // Teal 600
    const secondaryColor = Color(0xFF64748B); // Slate 500
    const backgroundColor = Color(0xFFFFFFFF); // Pure White

    return MaterialApp(
      title: 'Medical GenAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: secondaryColor,
          surface: Colors.white,
          background: backgroundColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: backgroundColor,
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 2,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: primaryColor.withOpacity(0.15),
          labelTextStyle: MaterialStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      themeMode: ThemeMode.light, // Force Light Theme
      home: const SplashScreen(),
    );
  }
}
