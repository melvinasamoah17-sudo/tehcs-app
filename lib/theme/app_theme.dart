import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand colours ──
  static const Color navy     = Color(0xFF1B2B5E);
  static const Color navyDark = Color(0xFF101D3F);
  static const Color goldDark = Color(0xFFB07D1A);
  static const Color gold     = Color(0xFFF5A623);
  static const Color red      = Color(0xFFE63329);
  static const Color green    = Color(0xFF16a34a);
  static const Color white    = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF8F9FB);
  static const Color light    = Color(0xFFF1F3F6);
  static const Color border   = Color(0xFFE2E8F0);
  static const Color textMid  = Color(0xFF475569);
  static const Color textMute = Color(0xFF94A3B8);

  // ── Typography ──
  // Poppins  — headings, titles, labels, buttons
  // Inter    — body text, descriptions, hints

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: offWhite,

    // Default text theme — Inter for body
    textTheme: GoogleFonts.interTextTheme(
      const TextTheme(
        bodyLarge:   TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium:  TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        bodySmall:   TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
        // Headings use Poppins
        headlineLarge:  TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        headlineSmall:  TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleLarge:  TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        labelLarge:  TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ).copyWith(
      headlineLarge:  GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700),
      headlineSmall:  GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
      titleLarge:     GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium:    GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
      labelLarge:     GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: navyDark,
      foregroundColor: white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 18, fontWeight: FontWeight.w600, color: white, letterSpacing: 0.3),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: navy,
        foregroundColor: white,
        elevation: 0,
        textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: navy,
        textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: offWhite,
      hintStyle: GoogleFonts.inter(fontSize: 14, color: textMute, fontWeight: FontWeight.w300),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: navy, width: 1.5)),
    ),

    tabBarTheme: TabBarThemeData(
      labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedLabelStyle: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w400),
    ),
  );

  /// Night theme for the admin & staff portal (see ThemeController).
  static ThemeData get dark {
    const bg = Color(0xFF0A1326);
    const card = Color(0xFF14213D);
    const field = Color(0xFF1B2A4A);
    const line = Color(0xFF263A63);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        brightness: Brightness.dark,
      ).copyWith(surface: card, primary: const Color(0xFF8FB4FF), secondary: gold),
      scaffoldBackgroundColor: bg,
    );
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
          bodyColor: Colors.white, displayColor: Colors.white),
      cardColor: card,
      dialogTheme: const DialogThemeData(backgroundColor: card),
      bottomSheetTheme:
          const BottomSheetThemeData(backgroundColor: card, modalBackgroundColor: card),
      popupMenuTheme: const PopupMenuThemeData(color: field),
      dividerColor: line,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0F1B33),
        foregroundColor: white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
            fontSize: 18, fontWeight: FontWeight.w600, color: white, letterSpacing: 0.3),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: navyDark,
          elevation: 0,
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        hintStyle: GoogleFonts.inter(
            fontSize: 14, color: const Color(0xFF7D8BA6), fontWeight: FontWeight.w300),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: gold, width: 1.5)),
      ),
    );
  }
}
