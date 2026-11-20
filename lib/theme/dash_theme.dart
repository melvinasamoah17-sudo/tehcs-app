import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// Day / night mode for the admin & staff side of the app.
///
/// The choice is saved on the device. It only applies while an admin or
/// staff member is in the portal ([staffSession]); customer screens always
/// use the day theme.
class ThemeController {
  static const _prefKey = 'dash_dark_mode';

  /// What the admin/staff picked (persisted).
  static final darkPreferred = ValueNotifier<bool>(false);

  /// True while the admin/staff portal is open.
  static final staffSession = ValueNotifier<bool>(false);

  /// Night mode is actually on right now.
  static bool get isDark => darkPreferred.value && staffSession.value;

  /// Rebuilds when either value changes.
  static final Listenable changes =
      Listenable.merge([darkPreferred, staffSession]);

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      darkPreferred.value = p.getBool(_prefKey) ?? false;
    } catch (_) {}
  }

  static Future<void> toggle() async {
    darkPreferred.value = !darkPreferred.value;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_prefKey, darkPreferred.value);
    } catch (_) {}
  }
}

/// Colours that follow day/night. Use these instead of AppTheme.white /
/// offWhite / border / navyDark-as-text on admin & staff screens.
class Dash {
  static bool get _d => ThemeController.isDark;

  // Night palette (deep navy, in the TEHCS brand family)
  static const _nightBg = Color(0xFF0A1326);
  static const _nightCard = Color(0xFF14213D);
  static const _nightField = Color(0xFF1B2A4A);
  static const _nightBorder = Color(0xFF263A63);
  static const _nightAccent = Color(0xFF8FB4FF);

  /// Page background.
  static Color get bg => _d ? _nightBg : const Color(0xFFF3F5F9);

  /// Cards, sheets, list rows.
  static Color get card => _d ? _nightCard : AppTheme.white;

  /// Inputs, chips, subtle fills.
  static Color get field => _d ? _nightField : AppTheme.offWhite;

  static Color get border => _d ? _nightBorder : AppTheme.border;

  /// Main text.
  static Color get text => _d ? Colors.white : AppTheme.navyDark;

  /// Secondary text.
  static Color get textMid => _d ? const Color(0xFFB6C2D9) : AppTheme.textMid;

  /// Hints, captions.
  static Color get textMute => _d ? const Color(0xFF7D8BA6) : AppTheme.textMute;

  /// Brand navy used for icons/labels/links; brightened at night so it
  /// stays readable on dark cards.
  static Color get accent => _d ? _nightAccent : AppTheme.navy;

  /// Bottom bar / header surfaces.
  static Color get bar => _d ? const Color(0xFF0F1B33) : AppTheme.white;

  static Color get shadow => _d
      ? Colors.black.withValues(alpha: .35)
      : Colors.black.withValues(alpha: .05);
}
