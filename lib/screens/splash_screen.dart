import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/auth_routing.dart';
import 'auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _scale = Tween<double>(begin: 0.8, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      final destination = user != null ? await resolveHomeScreen(user) : const LoginScreen();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => destination),
      );
    } catch (e) {
      debugPrint('Splash navigation error: $e');
      // If Firebase fails, go to Login anyway so user can see something
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyDark,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(22),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/tehcs.jpg'),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [BoxShadow(color: AppTheme.gold.withOpacity(.35), blurRadius: 30, offset: const Offset(0, 10))],
                  ),
                ),
                const SizedBox(height: 24),
                Text('TWITCH EMPIRE',
                  style: TextStyle(
                    fontFamily: 'Barlow Condensed',
                    fontSize: 26, fontWeight: FontWeight.w900,
                    color: AppTheme.white, letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Text('HOME CARE SERVICE',
                  style: TextStyle(
                    fontFamily: 'Barlow Condensed',
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppTheme.gold, letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(
                    color: AppTheme.gold, strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}