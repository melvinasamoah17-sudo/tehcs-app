import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/bottom_nav.dart';
import '../services/session_control.dart';
import '../theme/app_theme.dart';

// Customer screens
import 'home_screen.dart';
import 'services_screen.dart';
import 'bookings_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

// Staff screens
import 'staff/staff_home_screen.dart';
import 'staff/staff_rota_screen.dart';
import 'staff/staff_jobs_screen.dart';
import 'staff/staff_chat_screen.dart';
import 'staff/staff_profile_screen.dart';

// Admin
import 'admin_panel.dart';

class MainScreen extends StatefulWidget {
  /// Pass role from login. Defaults to 'customer' for backward compatibility.
  final String role;
  const MainScreen({super.key, this.role = 'customer'});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int      _index         = 0;
  bool     _emailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
  DateTime? _pausedAt;

  // ── Role resolved from Firestore (in case of cold start) ──
  String   _role          = 'customer';
  bool     _roleLoaded    = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _role = widget.role;

    // If admin redirect immediately
    if (_role == 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminPanel()),
        );
      });
    } else {
      _loadRole();
      _refreshVerification();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── Load role from Firestore in case it wasn't passed ──
  Future<void> _loadRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _roleLoaded = true); return; }
    try {
      // Check staff collection first
      final staffSnap = await FirebaseFirestore.instance
          .collection('staff').doc(uid).get();
      if (staffSnap.exists) {
        final r = staffSnap.data()?['role'] ?? 'staff';
        if (mounted) setState(() { _role = r; _roleLoaded = true; });
        return;
      }
      // Otherwise customer
      if (mounted) setState(() { _role = 'customer'; _roleLoaded = true; });
    } catch (_) {
      if (mounted) setState(() { _role = widget.role; _roleLoaded = true; });
    }
  }

  // ── App lifecycle — session timeout + re-check verification ──
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null &&
          DateTime.now().difference(pausedAt) >= kAutoSignOutThreshold) {
        performForceSignOut(context);
        return;
      }
      _refreshVerification();
    }
  }

  Future<void> _refreshVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    final verified  = refreshed?.emailVerified ?? false;
    if (mounted && verified != _emailVerified) {
      setState(() {
        _emailVerified = verified;
        if (!_emailVerified && _index >= _screens.length) {
          _index = 0;
        }
      });
    }
  }

  // ── SCREENS ──
  List<Widget> get _screens {
    if (_role == 'staff') {
      return const [
        StaffHomeScreen(),
        StaffRotaScreen(),
        StaffJobsScreen(),
        StaffChatScreen(),
        StaffProfileScreen(),
      ];
    }
    // Customer — hide chat until email verified (existing behaviour)
    return _emailVerified
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
  }

  @override
  Widget build(BuildContext context) {
    // Admin: show loader while redirecting
    if (_role == 'admin') {
      return const Scaffold(
        backgroundColor: AppTheme.navyDark,
        body: Center(child: CircularProgressIndicator(color: AppTheme.gold)),
      );
    }

    final screens  = _screens;
    final safeIdx  = _index < screens.length ? _index : 0;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) handleGuardedBackPress(context);
      },
      child: Scaffold(
        body: IndexedStack(index: safeIdx, children: screens),
        bottomNavigationBar: BottomNav(
          currentIndex: safeIdx,
          showChat:     _role == 'staff' ? true : _emailVerified,
          role:         _role,
          onTap:        (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}