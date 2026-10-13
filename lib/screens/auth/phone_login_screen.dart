import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_routing.dart';
import '../../services/phone_auth_helper.dart';
import '../../services/region_service.dart';

/// Sign in (or sign up) with a phone number and an SMS code.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String _dial = RegionService.current.dial;
  String? _verificationId;
  String? _phone;
  bool _loading = false;
  String? _error;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    final phone = PhoneAuthHelper.normalize(_phoneCtrl.text.trim(), dial: _dial);
    if (!PhoneAuthHelper.looksValid(phone)) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      // Android may read the SMS automatically and sign straight in.
      verificationCompleted: (cred) => _signIn(cred),
      verificationFailed: (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = PhoneAuthHelper.friendly(e);
        });
      },
      codeSent: (id, _) {
        if (!mounted) return;
        setState(() {
          _verificationId = id;
          _phone = phone;
          _loading = false;
        });
        _startCooldown();
      },
      codeAutoRetrievalTimeout: (id) => _verificationId ??= id,
    );
  }

  Future<void> _confirm() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6 || _verificationId == null) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    await _signIn(PhoneAuthProvider.credential(
        verificationId: _verificationId!, smsCode: code));
  }

  Future<void> _signIn(PhoneAuthCredential cred) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await FirebaseAuth.instance.signInWithCredential(cred);
      final screen = await resolveHomeScreen(result.user!);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => screen), (_) => false);
    } catch (e) {
      if (mounted) setState(() => _error = PhoneAuthHelper.friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeStep = _verificationId != null;
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.navy),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(codeStep ? 'Enter the code' : 'Sign in with phone',
                style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy)),
            const SizedBox(height: 8),
            Text(
                codeStep
                    ? 'We sent a 6-digit code by SMS to $_phone.'
                    : 'We will text you a 6-digit code. No password needed.',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppTheme.textMid)),
            const SizedBox(height: 24),
            if (!codeStep)
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.inter(color: AppTheme.navy, fontSize: 16),
                decoration: InputDecoration(
                    labelText: 'Phone number',
                    hintText: _dial == '44' ? '07123 456789' : '024 123 4567',
                    prefixIcon: PhoneAuthHelper.dialPicker(
                        _dial, (v) => setState(() => _dial = v)),
                    prefixIconConstraints: const BoxConstraints()),
              )
            else
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                autofocus: true,
                style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 10,
                    color: AppTheme.navy),
                decoration: const InputDecoration(counterText: ''),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppTheme.red)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : (codeStep ? _confirm : _sendCode),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(codeStep ? 'Verify and sign in' : 'Send code',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              ),
            ),
            if (codeStep) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _cooldown > 0 || _loading
                      ? null
                      : () {
                          setState(() {
                            _verificationId = null;
                            _codeCtrl.clear();
                          });
                          _sendCode();
                        },
                  child: Text(
                      _cooldown > 0 ? 'Resend code in ${_cooldown}s' : 'Resend code',
                      style: GoogleFonts.poppins(color: AppTheme.navy)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
