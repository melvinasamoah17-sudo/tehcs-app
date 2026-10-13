import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/main_screen.dart';
import '../screens/admin_panel.dart';
import '../screens/verify/verify_africa_screen.dart';
import 'region_service.dart';

const String kPrimaryAdminEmail = 'twitchempireinfo@gmail.com';

/// Customers must verify their identity before they can use the app.
/// Ghana only for now — UK verification will be added later.
const bool kRequireIdVerification = true;

bool get idVerificationRequired =>
    kRequireIdVerification && !RegionService.current.isUK;

enum UserRole { client, staff, admin }

Future<UserRole> resolveUserRole(User user) async {
  final email = user.email?.toLowerCase();
  if (email == kPrimaryAdminEmail) return UserRole.admin;
  if (email == null) return UserRole.client;
  try {
    final byEmail = await FirebaseFirestore.instance
        .collection('staff_by_email')
        .doc(email)
        .get();
    if (byEmail.exists) return UserRole.staff;
  } catch (_) {}
  return UserRole.client;
}

Future<Widget> resolveHomeScreen(User user) async {
  await user.reload();
  final refreshed = FirebaseAuth.instance.currentUser ?? user;
  final role = await resolveUserRole(refreshed);

  if (role == UserRole.admin) return const AdminPanel(mode: 'admin');
  final db = FirebaseFirestore.instance;
  if (role == UserRole.staff) {
    await RegionService.syncFromProfile(db.collection('staff').doc(refreshed.uid));
    return const AdminPanel(mode: 'staff');
  }

  // For Google/Apple sign-in users — email is auto-verified by provider
  // Auto-create client profile in Firestore if first time
  if (refreshed.emailVerified || _isSocialProvider(refreshed)) {
    await _ensureClientProfile(refreshed);
    final ref = db.collection('clients').doc(refreshed.uid);
    await RegionService.syncFromProfile(ref);
    if (idVerificationRequired && !await _isIdVerified(ref)) {
      return const VerifyAfricaScreen(role: 'customer', onboarding: true);
    }
    return const MainScreen(role: 'customer');
  }

  // Email/password users — need verification
  return const VerifyEmailScreen(role: 'customer');
}

bool _isSocialProvider(User user) {
  return user.providerData
      .any((p) => p.providerId == 'google.com' ||
      p.providerId == 'apple.com' ||
      p.providerId == 'phone');
}

Future<bool> _isIdVerified(DocumentReference<Map<String, dynamic>> ref) async {
  try {
    final d = (await ref.get()).data() ?? {};
    return d['id_verified'] == true || d['liveness_verified'] == true;
  } catch (_) {
    return false;
  }
}

Future<void> _ensureClientProfile(User user) async {
  try {
    final ref = FirebaseFirestore.instance.collection('clients').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'phone': user.phoneNumber ?? '',
        'role': 'customer',
        'country': RegionService.current.code,
        'provider': user.providerData.firstOrNull?.providerId ?? 'email',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  } catch (_) {}
}
