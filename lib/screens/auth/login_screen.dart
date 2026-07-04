import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'register_screen.dart';
import '../main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl   = TextEditingController();
  bool _loading    = false;
  bool _obscure    = true;
  String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check if Firebase is actually ready
    if (Firebase.apps.isEmpty) {
      setState(() => _error = 'Firebase not initialized. Please restart the app.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      debugPrint('Attempting login for: ${_emailCtrl.text.trim()}');
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwdCtrl.text,
      );
      debugPrint('Login success');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Login FirebaseAuthException: ${e.code} - ${e.message}');
      setState(() {
        _error = switch (e.code) {
          'invalid-credential'  => 'Incorrect email or password.',
          'user-not-found'      => 'No account found with this email.',
          'wrong-password'      => 'Incorrect password.',
          'too-many-requests'   => 'Too many attempts. Please wait.',
          'network-request-failed' => 'Network error. Please check your internet.',
          _ => 'Login failed: ${e.message}',
        };
      });
    } catch (e) {
      debugPrint('Login general error: $e');
      setState(() => _error = 'An unexpected error occurred. ($e)');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset link sent to $email'), backgroundColor: AppTheme.green),
      );
    } catch (_) {
      setState(() => _error = 'Could not send reset email.');
    }
  }

  @override
  void dispose() { _emailCtrl.dispose(); _pwdCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Logo
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(18),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/tehcs.jpg'),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))],
                ),
              ),
              const SizedBox(height: 16),
              Text('Welcome Back', style: GoogleFonts.barlowCondensed(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.white, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text('Sign in to your TEHCS account', style: GoogleFonts.nunito(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.w300)),
              const SizedBox(height: 36),

              // Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 30, offset: const Offset(0, 12))],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Error
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Text(_error!, style: GoogleFonts.nunito(fontSize: 13, color: const Color(0xFFB91C1C))),
                        ),
                      ],

                      // Email
                      _label('Email Address'),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(hintText: 'you@example.com', prefixIcon: Icon(Icons.email_outlined, size: 20)),
                        validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
                      ),
                      const SizedBox(height: 14),

                      // Password
                      _label('Password'),
                      TextFormField(
                        controller: _pwdCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => v == null || v.length < 6 ? 'Enter your password' : null,
                      ),
                      const SizedBox(height: 8),

                      // Forgot
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _resetPassword,
                          child: Text('Forgot password?', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.navy)),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('Sign In', style: GoogleFonts.barlowCondensed(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account?", style: GoogleFonts.nunito(color: Colors.white60, fontSize: 13)),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: Text('Register', style: GoogleFonts.barlowCondensed(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.gold, letterSpacing: 0.5)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(text.toUpperCase(),
      style: GoogleFonts.barlowCondensed(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMid, letterSpacing: 1.2),
    ),
  );
}
