import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tehcs_app/main.dart';
import 'package:tehcs_app/screens/splash_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Splash screen shows TEHCS branding', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.text('TWITCH EMPIRE'), findsOneWidget);
    expect(find.text('HOME CARE SERVICE'), findsOneWidget);

    // Let the 2s splash delay elapse so no timers are left pending.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('App shows a readable error when Firebase fails to start',
      (tester) async {
    await tester.pumpWidget(const TEHCSApp(firebaseError: 'boom'));

    expect(find.textContaining('Firebase Error: boom'), findsOneWidget);
  });
}
