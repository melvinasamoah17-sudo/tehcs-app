import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // UK formatting (dd/MM/yyyy, 24h clock, Monday-first calendars)
  Intl.defaultLocale = 'en_GB';
  await initializeDateFormatting('en_GB');

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  String? firebaseError;
  try {
    debugPrint('Initializing Firebase Core...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase Core initialized successfully');
  } catch (e) {
    debugPrint('Firebase Core initialization error: $e');
    firebaseError = e.toString();
  }

  runApp(TEHCSApp(firebaseError: firebaseError));
}

// ── Global navigator key so we can navigate from outside widget tree ──
final _navigatorKey = GlobalKey<NavigatorState>();

class TEHCSApp extends StatefulWidget {
  final String? firebaseError;
  const TEHCSApp({super.key, this.firebaseError});

  @override
  State<TEHCSApp> createState() => _TEHCSAppState();
}

class _TEHCSAppState extends State<TEHCSApp> with WidgetsBindingObserver {
  // 5 minutes in seconds
  static const _timeoutDuration = Duration(minutes: 5);

  Timer? _sessionTimer;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // App went to background — record the time
        _backgroundedAt = DateTime.now();
        _sessionTimer?.cancel();
        _sessionTimer = Timer(_timeoutDuration, _handleTimeout);
        break;

      case AppLifecycleState.resumed:
        // App came back — check if we already timed out
        _sessionTimer?.cancel();
        _sessionTimer = null;
        if (_backgroundedAt != null) {
          final elapsed = DateTime.now().difference(_backgroundedAt!);
          if (elapsed >= _timeoutDuration) {
            _handleTimeout();
          }
        }
        _backgroundedAt = null;
        break;

      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _handleTimeout() async {
    // Only sign out if someone is actually signed in
    if (FirebaseAuth.instance.currentUser == null) return;
    await FirebaseAuth.instance.signOut();
    // Navigate to login, clearing the entire stack
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TEHCS',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.theme,
      locale: const Locale('en', 'GB'),
      supportedLocales: const [Locale('en', 'GB')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: widget.firebaseError != null
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'Firebase Error: ${widget.firebaseError}\n\nPlease check your configuration.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          : const SplashScreen(),
    );
  }
}
