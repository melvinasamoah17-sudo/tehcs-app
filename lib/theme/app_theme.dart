import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── TEHCS Brand Colors ──
  static const Color navy     = Color(0xFF1B2B5E);
  static const Color navyDark = Color(0xFF101D3F);
  static const Color navyMid  = Color(0xFF253470);
  static const Color gold     = Color(0xFFF5A623);
  static const Color goldDark = Color(0xFFD4891A);
  static const Color red      = Color(0xFFE63329);
  static const Color green    = Color(0xFF16A34A);
  static const Color white    = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF4F6FB);
  static const Color light    = Color(0xFFEEF1F8);
  static const Color textMid  = Color(0xFF3D4466);
  static const Color textMute = Color(0xFF7A82A8);
  static const Color border   = Color(0x1A1B2B5E);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: navy,
      primary:   navy,
      secondary: gold,
      error:     red,
      surface:   white,
    ),
    textTheme: GoogleFonts.nunitoTextTheme().copyWith(
      displayLarge:  GoogleFonts.barlowCondensed(fontWeight: FontWeight.w900, letterSpacing: -0.5),
      displayMedium: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w800),
      headlineLarge: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w900),
      headlineMedium:GoogleFonts.barlowCondensed(fontWeight: FontWeight.w800),
      titleLarge:    GoogleFonts.barlowCondensed(fontWeight: FontWeight.w700),
      titleMedium:   GoogleFonts.barlowCondensed(fontWeight: FontWeight.w600),
      labelLarge:    GoogleFonts.barlowCondensed(fontWeight: FontWeight.w700, letterSpacing: 0.8),
    ),
    scaffoldBackgroundColor: offWhite,
    appBarTheme: AppBarTheme(
      backgroundColor: navyDark,
      foregroundColor: white,
      elevation: 0,
      titleTextStyle: GoogleFonts.barlowCondensed(
        fontSize: 20, fontWeight: FontWeight.w800,
        color: white, letterSpacing: 1.0,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: navy,
        foregroundColor: white,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
        textStyle: GoogleFonts.barlowCondensed(
          fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.8,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: offWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: navy, width: 2),
      ),
      labelStyle: GoogleFonts.barlowCondensed(
        fontSize: 12, fontWeight: FontWeight.w700,
        letterSpacing: 1.2, color: textMid,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    cardTheme: CardThemeData(
      color: white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: border),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: white,
      selectedItemColor: navy,
      unselectedItemColor: textMute,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );
}
