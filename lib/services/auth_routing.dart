import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/main_screen.dart';
import '../screens/admin_panel.dart';

const String kPrimaryAdminEmail = 'twitchempireinfo@gmail.com';

enum UserRole { client, staff, admin }

/// Determines the signed-in user's role. Mirrors the isStaff() check in
/// firestore.rules so the app's routing and the security rules never
/// disagree about who counts as staff.
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
  } catch (_) {
    // If the check fails (e.g. offline), fall back to client rather
    // than blocking the person from using the app entirely.
  }
  return UserRole.client;
}

/// Decides which screen a signed-in user should land on, handling both
/// email verification and role-based routing in one place so splash,
/// login, and register all stay in sync with each other.
Future<Widget> resolveHomeScreen(User user) async {
  await user.reload();
  final refreshed = FirebaseAuth.instance.currentUser ?? user;

  final role = await resolveUserRole(refreshed);

  // Staff/admin accounts are added manually by a trusted admin, so we
  // don't gate them behind email verification the way client
  // self-signups are gated.
  if (role == UserRole.admin) return const AdminPanel(mode: 'admin');
  if (role == UserRole.staff) return const AdminPanel(mode: 'staff');

  if (!refreshed.emailVerified) return const VerifyEmailScreen();
  return const MainScreen();
}