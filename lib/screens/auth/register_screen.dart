import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _pwdCtrl    = TextEditingController();
  bool _loading     = false;
  bool _obscure     = true;
  String? _error;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwdCtrl.text,
      );
      await cred.user!.updateDisplayName(_nameCtrl.text.trim());
      await cred.user!.sendEmailVerification();
      await FirebaseFirestore.instance.collection('clients').add({
        'uid':       cred.user!.uid,
        'name':      _nameCtrl.text.trim(),
        'email':     _emailCtrl.text.trim(),
        'phone':     _phoneCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
            (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Registration FirebaseAuthException: ${e.code} - ${e.message}');
      setState(() {
        _error = switch (e.code) {
          'email-already-in-use' => 'This email is already registered.',
          'weak-password'        => 'Password is too weak.',
          'invalid-email'        => 'Invalid email address.',
          'network-request-failed' => 'Network error. Please check your internet.',
          _ => 'Registration failed: ${e.message}',
        };
      });
    } catch (e) {
      debugPrint('Registration general error: $e');
      setState(() => _error = 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose(); _pwdCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Logo
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(12),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/tehcs.jpg'),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 3))],
                ),
              ),
              const SizedBox(height: 16),
              Text('Create Account', style: GoogleFonts.barlowCondensed(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.white, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text('Join TEHCS — Book services with ease', style: GoogleFonts.nunito(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.w300)),
              const SizedBox(height: 28),

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

                      _label('Full Name'),
                      TextFormField(
                        controller: _nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(hintText: 'Sarah Ackah', prefixIcon: Icon(Icons.person_outline, size: 20)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter your name' : null,
                      ),
                      const SizedBox(height: 14),

                      _label('Email Address'),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(hintText: 'you@example.com', prefixIcon: Icon(Icons.email_outlined, size: 20)),
                        validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
                      ),
                      const SizedBox(height: 14),

                      _label('Phone / WhatsApp'),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(hintText: '+233 or +44...', prefixIcon: Icon(Icons.phone_outlined, size: 20)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter your phone number' : null,
                      ),
                      const SizedBox(height: 14),

                      _label('Password'),
                      TextFormField(
                        controller: _pwdCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          hintText: 'Min. 8 characters',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => v == null || v.length < 8 ? 'Password must be at least 8 characters' : null,
                      ),
                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _register,
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: AppTheme.navyDark),
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('Create Account', style: GoogleFonts.barlowCondensed(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
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