import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/bottom_nav.dart';
import '../services/session_control.dart';
import 'home_screen.dart';
import 'services_screen.dart';
import 'bookings_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _index = 0;
  bool _emailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshVerification();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null && DateTime.now().difference(pausedAt) >= kAutoSignOutThreshold) {
        performForceSignOut(context);
        return;
      }
      // Re-check verification whenever the app comes back to the
      // foreground, in case the user just verified via the email link.
      _refreshVerification();
    }
  }

  Future<void> _refreshVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    final verified = refreshed?.emailVerified ?? false;
    if (mounted && verified != _emailVerified) {
      setState(() {
        _emailVerified = verified;
        if (!_emailVerified && _index >= _screens.length) {
          _index = 0;
        }
      });
    }
  }

  List<Widget> get _screens => _emailVerified
      ? const [
    HomeScreen(),
    ServicesScreen(),
    BookingsScreen(),
    ChatScreen(),
    ProfileScreen(),
  ]
      : const [
    HomeScreen(),
    ServicesScreen(),
    BookingsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final screens = _screens;
    final safeIndex = _index < screens.length ? _index : 0;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) handleGuardedBackPress(context);
      },
      child: Scaffold(
        body: IndexedStack(index: safeIndex, children: screens),
        bottomNavigationBar: BottomNav(
          currentIndex: safeIndex,
          showChat: _emailVerified,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}