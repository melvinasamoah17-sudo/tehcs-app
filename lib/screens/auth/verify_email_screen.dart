import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../main_screen.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _checking = false;
  bool _sending = false;
  String? _message;
  Timer? _autoCheck;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Periodically check in the background in case the user verifies
    // and comes back to the app without tapping the button.
    _autoCheck = Timer.periodic(const Duration(seconds: 5), (_) => _silentCheck());
  }

  @override
  void dispose() {
    _autoCheck?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _silentCheck() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed != null && refreshed.emailVerified && mounted) {
      _autoCheck?.cancel();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
            (_) => false,
      );
    }
  }

  Future<void> _checkNow() async {
    setState(() { _checking = true; _message = null; });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _checking = false; _message = 'Session expired. Please log in again.'; });
      return;
    }
    await user.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    if (refreshed != null && refreshed.emailVerified) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
            (_) => false,
      );
    } else {
      setState(() { _checking = false; _message = 'Not verified yet. Please tap the link in your email first.'; });
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0) return;
    setState(() { _sending = true; _message = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();
      if (!mounted) return;
      setState(() { _message = 'Verification email sent. Check your inbox (and spam folder).'; });
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() { _message = 'Could not resend email. Please try again shortly.'; });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCooldown <= 1) {
        t.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: AppTheme.navyDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📧', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 20),
              Text('Confirm Your Email',
                textAlign: TextAlign.center,
                style: GoogleFonts.barlowCondensed(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.white, letterSpacing: 1),
              ),
              const SizedBox(height: 10),
              Text(
                "We've sent a confirmation link to\n$email\n\nOpen it in Gmail and tap the link to verify your account, then come back here.",
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 14, color: Colors.white70, height: 1.6),
              ),
              const SizedBox(height: 28),
              if (_message != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_message!, textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(fontSize: 13, color: Colors.white),
                  ),
                ),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _checking ? null : _checkNow,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: AppTheme.navyDark),
                  child: _checking
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text("I've Verified — Continue", style: GoogleFonts.barlowCondensed(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: (_sending || _resendCooldown > 0) ? null : _resend,
                child: Text(
                  _resendCooldown > 0 ? 'Resend available in ${_resendCooldown}s' : 'Resend Email',
                  style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _signOut,
                child: Text('Sign Out', style: GoogleFonts.nunito(fontSize: 13, color: Colors.white38)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}