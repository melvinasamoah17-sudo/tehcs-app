import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/auth/login_screen.dart';

/// How long the app can sit in the background before we sign the user
/// out automatically for security. Applies on both Android and iOS —
/// didChangeAppLifecycleState fires the same way on both platforms.
const Duration kAutoSignOutThreshold = Duration(minutes: 4);

/// Signs the current user out and sends them back to the login screen,
/// clearing the navigation stack.
Future<void> performForceSignOut(BuildContext context) async {
  await FirebaseAuth.instance.signOut();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
  );
}

/// Shows a confirmation dialog when the Android back button is pressed
/// at the root of the app, offering to sign out, exit, or stay.
/// Harmless no-op-feeling on iOS since there's no system back button
/// to intercept there.
Future<void> handleGuardedBackPress(BuildContext context) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Leaving so soon?'),
      content: const Text('Would you like to sign out, or just exit the app?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, 'exit'), child: const Text('Exit App')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'signout'),
          child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  if (choice == 'signout') {
    await performForceSignOut(context);
  } else if (choice == 'exit') {
    SystemNavigator.pop();
  }
  // 'cancel' or dismissed (null) => do nothing, stay in the app.
}