import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Country-specific settings. The app runs in either Ghana or UK style.
class AppRegion {
  final String code;          // ISO country code: 'GH' | 'GB'
  final String name;
  final String flag;
  final String dial;          // dial code without '+'
  final String currency;      // symbol
  final String phoneHint;
  final String addressHint;
  final String budgetHint;
  final String office;        // primary office line (E.164)
  final LatLng mapCentre;

  const AppRegion({
    required this.code, required this.name, required this.flag,
    required this.dial, required this.currency, required this.phoneHint,
    required this.addressHint, required this.budgetHint,
    required this.office, required this.mapCentre,
  });

  static const ghana = AppRegion(
    code: 'GH', name: 'Ghana', flag: '🇬🇭', dial: '233', currency: 'GH₵',
    phoneHint: '024 123 4567',
    addressHint: 'House No., Street, Town, GhanaPost GPS (e.g. GA-123-4567)',
    budgetHint: 'e.g. GH₵5,000–GH₵10,000',
    office: '+233505108071',
    mapCentre: LatLng(5.6037, -0.1870),   // Accra
  );

  static const uk = AppRegion(
    code: 'GB', name: 'United Kingdom', flag: '🇬🇧', dial: '44', currency: '£',
    phoneHint: '07123 456789',
    addressHint: 'House No., Street, Town, Postcode',
    budgetHint: 'e.g. £500–£1,000',
    office: '+447448468070',
    mapCentre: LatLng(51.5072, -0.1276),  // London
  );

  static const all = [ghana, uk];

  static AppRegion of(String? code) => code == 'GB' ? uk : ghana;

  bool get isUK => code == 'GB';
}

/// Holds the active region. Saved on the device and on the user's profile.
class RegionService {
  static const _prefKey = 'region';
  static final ValueNotifier<AppRegion> notifier = ValueNotifier(AppRegion.ghana);

  static AppRegion get current => notifier.value;

  /// Called on app open: saved choice → device location → device locale.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        notifier.value = AppRegion.of(saved);
        return;
      }
    } catch (_) {}
    notifier.value = await detect();
  }

  /// Best guess of where the person is, without blocking for long.
  static Future<AppRegion> detect() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 6),
            );
        final fromGps = _fromCoords(pos.latitude, pos.longitude);
        if (fromGps != null) return fromGps;
      }
    } catch (_) {}
    final cc = PlatformDispatcher.instance.locale.countryCode;
    return cc == 'GB' ? AppRegion.uk : AppRegion.ghana;
  }

  static AppRegion? _fromCoords(double lat, double lng) {
    if (lat > 49.8 && lat < 61 && lng > -8.7 && lng < 1.8) return AppRegion.uk;
    if (lat > 4.5 && lat < 11.2 && lng > -3.3 && lng < 1.3) return AppRegion.ghana;
    return null;
  }

  /// Switch region and remember it on this device.
  static Future<void> set(AppRegion region) async {
    notifier.value = region;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, region.code);
    } catch (_) {}
  }

  /// Use the country saved on the account. Older accounts without one get it
  /// from their phone number, then it is written back to the profile.
  static Future<void> syncFromProfile(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      final snap = await ref.get();
      final data = snap.data() ?? {};
      final country = data['country'] as String?;
      if (country == 'GH' || country == 'GB') {
        await set(AppRegion.of(country));
        return;
      }
      final phone = (data['phone'] ?? '').toString().replaceAll(' ', '');
      if (phone.startsWith('+44') || phone.startsWith('07')) {
        await set(AppRegion.uk);
      } else if (phone.startsWith('+233')) {
        await set(AppRegion.ghana);
      }
      if (snap.exists) await ref.update({'country': current.code});
    } catch (_) {}
  }
}
