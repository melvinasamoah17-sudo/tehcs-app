import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../main_screen.dart';
import 'login_screen.dart';

// OTP screen expires after this many minutes of inactivity
const _kSessionMinutes = 10;

class VerifyEmailScreen extends StatefulWidget {
  final String role;
  final String? phoneVerificationId;

  const VerifyEmailScreen({
    super.key,
    this.role = 'customer',
    this.phoneVerificationId,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final List<TextEditingController> _ctrs =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _foci = List.generate(4, (_) => FocusNode());

  bool _checking = false;
  bool _sending = false;
  bool _verified = false;
  String? _message;
  bool _isError = false;

  Timer? _autoCheck;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  // Session expiry
  final DateTime _openedAt = DateTime.now();

  late List<AnimationController> _cardCtrs;
  late List<Animation<double>> _cardTilts;
  late List<Animation<double>> _cardScales;
  late AnimationController _checkCtrl;
  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;
  late AnimationController _textCtrl;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  bool get _isPhoneMode => widget.phoneVerificationId != null;

  @override
  void initState() {
    super.initState();

    _cardCtrs = List.generate(
        4,
        (_) => AnimationController(
            vsync: this, duration: const Duration(milliseconds: 280)));
    _cardTilts = _cardCtrs
        .map((c) => Tween<double>(begin: -0.18, end: 0)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeOutBack)))
        .toList();
    _cardScales = _cardCtrs
        .map((c) => Tween<double>(begin: 0.65, end: 1)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeOutBack)))
        .toList();

    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _checkScale = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut));
    _checkOpacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _checkCtrl, curve: const Interval(0, 0.4)));
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _textFade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    if (!_isPhoneMode) {
      _autoCheck =
          Timer.periodic(const Duration(seconds: 5), (_) => _silentCheck());
    }
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _foci[0].requestFocus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _ctrs) c.dispose();
    for (final f in _foci) f.dispose();
    for (final c in _cardCtrs) c.dispose();
    _checkCtrl.dispose();
    _textCtrl.dispose();
    _autoCheck?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // Called when app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_verified) {
      _checkExpiry();
    }
  }

  void _checkExpiry() {
    final elapsed = DateTime.now().difference(_openedAt);
    if (elapsed.inMinutes >= _kSessionMinutes) {
      _expireSession();
    }
  }

  Future<void> _expireSession() async {
    _autoCheck?.cancel();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _silentCheck() async {
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
        _autoCheck?.cancel();
        if (mounted) _showVerified();
      }
    } catch (_) {}
  }

  String get _code => _ctrs.map((c) => c.text).join();

  void _onChanged(int index, String val) {
    if (val.length > 1) {
      final digits = val.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 4 && i < digits.length; i++) {
        _ctrs[i].text = digits[i];
        _animateCard(i);
      }
      _foci[digits.length >= 4 ? 3 : digits.length - 1].requestFocus();
      if (digits.length >= 4)
        Future.delayed(const Duration(milliseconds: 200), _verify);
      return;
    }
    if (val.isNotEmpty) {
      _animateCard(index);
      if (index < 3)
        Future.delayed(const Duration(milliseconds: 80), () {
          if (mounted) _foci[index + 1].requestFocus();
        });
    }
    setState(() {});
    if (_code.length == 4)
      Future.delayed(const Duration(milliseconds: 200), _verify);
  }

  void _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _ctrs[index].text.isEmpty &&
        index > 0) {
      _foci[index - 1].requestFocus();
      _ctrs[index - 1].clear();
      setState(() {});
    }
  }

  void _animateCard(int index) => _cardCtrs[index].forward(from: 0);

  Future<void> _verify() async {
    final code = _code;
    if (code.length < 4) {
      setState(() {
        _message = 'Please enter all 4 digits.';
        _isError = true;
      });
      return;
    }
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      if (_isPhoneMode) {
        final cred = PhoneAuthProvider.credential(
            verificationId: widget.phoneVerificationId!, smsCode: code);
        await FirebaseAuth.instance.signInWithCredential(cred);
        _showVerified();
      } else {
        await FirebaseAuth.instance.currentUser?.reload();
        if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
          _showVerified();
        } else {
          setState(() {
            _message = 'Not verified yet. Check your inbox or tap Resend.';
            _isError = true;
          });
          for (final c in _ctrs) c.clear();
          for (final ctrl in _cardCtrs) ctrl.reset();
          _foci[0].requestFocus();
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _message = e.code == 'invalid-verification-code'
            ? 'Incorrect code. Try again.'
            : 'Verification failed.';
        _isError = true;
      });
      for (final c in _ctrs) c.clear();
      for (final ctrl in _cardCtrs) ctrl.reset();
      _foci[0].requestFocus();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showVerified() async {
    if (!mounted) return;
    setState(() {
      _verified = true;
      _message = null;
    });
    _checkCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 350));
    _textCtrl.forward();
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => MainScreen(role: widget.role)),
      (_) => false,
    );
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0 || _sending) return;
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      if (!_isPhoneMode)
        await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      setState(() {
        _resendCooldown = 60;
        _message = 'Code sent!';
        _isError = false;
      });
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _resendCooldown--);
        if (_resendCooldown <= 0) t.cancel();
      });
    } catch (_) {
      setState(() {
        _message = 'Failed to resend. Try again.';
        _isError = true;
      });
    }
    if (mounted) setState(() => _sending = false);
  }

  String get _maskedContact {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final parts = email.split('@');
    if (parts.length == 2 && parts[0].length > 2) {
      return '${parts[0].substring(0, 2)}${'•' * (parts[0].length - 2)}@${parts[1]}';
    }
    return email;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.white54, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _verified ? _buildVerified() : _buildEntry(),
                ),
              ),
            ),
          ),
          if (!_verified)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                _isPhoneMode
                    ? 'Enter the 4-digit SMS code.'
                    : 'Click the email link, then tap Verify.',
                style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: Colors.white24,
                    fontWeight: FontWeight.w300),
                textAlign: TextAlign.center,
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildEntry() {
    return Column(
        key: const ValueKey('entry'),
        mainAxisSize: MainAxisSize.min,
        children: [
          _Card(
              child: Column(children: [
            Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 28),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.06),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(.1))),
              child: Center(
                  child: Icon(
                      _isPhoneMode ? Icons.smartphone : Icons.email_outlined,
                      size: 26,
                      color: Colors.white)),
            ),
            const SizedBox(height: 20),
            Text('Enter your code',
                style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3)),
            const SizedBox(height: 8),
            Text(
              _isPhoneMode
                  ? 'We texted a 4-digit code to your phone.'
                  : 'We sent a 4-digit code to\n$_maskedContact',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: Colors.white38,
                  fontWeight: FontWeight.w300,
                  height: 1.6),
            ),
            const SizedBox(height: 32),

            // 4 OTP boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  4,
                  (i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: AnimatedBuilder(
                          animation: _cardCtrs[i],
                          builder: (_, child) => Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateX(_cardTilts[i].value)
                              ..scale(_cardScales[i].value),
                            child: child,
                          ),
                          child: _OtpBox(
                              controller: _ctrs[i],
                              focusNode: _foci[i],
                              onChanged: (v) => _onChanged(i, v),
                              onKey: (e) => _onKey(i, e),
                              hasError: _isError),
                        ),
                      )),
            ),

            if (_message != null) ...[
              const SizedBox(height: 14),
              Text(_message!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                      fontSize: 12,
                      color:
                          _isError ? AppTheme.red : const Color(0xFF2ECC71))),
            ],
            const SizedBox(height: 28),

            if (_checking)
              const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white54))
            else
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text("Didn't get a code?  ",
                    style: GoogleFonts.nunito(
                        color: Colors.white38, fontSize: 13)),
                GestureDetector(
                  onTap: _resendCooldown == 0 ? _resend : null,
                  child: _sending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white54))
                      : _resendCooldown > 0
                          ? Text('${_resendCooldown}s',
                              style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: Colors.white24,
                                  fontWeight: FontWeight.w600))
                          : Text('Resend',
                              style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                ),
              ]),
          ])),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false);
            },
            child: Text('Use a different account',
                style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: Colors.white24,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white24)),
          ),
        ]);
  }

  Widget _buildVerified() {
    return Column(
        key: const ValueKey('verified'),
        mainAxisSize: MainAxisSize.min,
        children: [
          _Card(
              child: Column(children: [
            SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                    opacity: _textFade,
                    child: Text('Verified',
                        style: GoogleFonts.nunito(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)))),
            const SizedBox(height: 4),
            SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                    opacity: _textFade,
                    child: Text('Setting up your session...',
                        style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: Colors.white38,
                            fontWeight: FontWeight.w300)))),
            const SizedBox(height: 40),
            ScaleTransition(
                scale: _checkScale,
                child: FadeTransition(
                  opacity: _checkOpacity,
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF2ECC71), width: 2.5)),
                    child: const Center(
                        child: Icon(Icons.check_rounded,
                            color: Color(0xFF2ECC71), size: 42)),
                  ),
                )),
            const SizedBox(height: 18),
            ScaleTransition(
              scale: _checkScale,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71).withOpacity(.1),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: const Color(0xFF2ECC71).withOpacity(.3))),
                child: Text('Verified',
                    style: GoogleFonts.barlowCondensed(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2ECC71),
                        letterSpacing: 0.5)),
              ),
            ),
            const SizedBox(height: 36),
            FadeTransition(
              opacity: _textFade,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goHome,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0),
                  child: Text('Continue',
                      style: GoogleFonts.barlowCondensed(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8)),
                ),
              ),
            ),
          ])),
        ]);
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(26, 30, 26, 30),
        decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(.08))),
        child: child,
      );
}

class _OtpBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKey;
  final bool hasError;
  const _OtpBox(
      {required this.controller,
      required this.focusNode,
      required this.onChanged,
      required this.onKey,
      required this.hasError});
  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  bool _focused = false;
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.controller.text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 64,
      height: 74,
      decoration: BoxDecoration(
        color: _focused
            ? Colors.white.withOpacity(.08)
            : filled
                ? const Color(0xFF21262D)
                : const Color(0xFF1C2128),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: widget.hasError
                ? AppTheme.red.withOpacity(.7)
                : _focused
                    ? Colors.white.withOpacity(.5)
                    : filled
                        ? Colors.white.withOpacity(.2)
                        : Colors.white.withOpacity(.08),
            width: _focused ? 1.5 : 1),
      ),
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: widget.onKey,
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: widget.onChanged,
          style: GoogleFonts.nunito(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1),
          cursorColor: Colors.white54,
          cursorWidth: 1.5,
          decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero),
        ),
      ),
    );
  }
}
