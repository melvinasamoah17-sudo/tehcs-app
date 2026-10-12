import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../main_screen.dart';
import '../../services/auth_routing.dart';
import 'login_screen.dart';

// OTP screen expires after this many minutes of inactivity
const _kSessionMinutes = 15;
const _kLen = 6;

/// Email OTP verification. A 6-digit code is emailed by the `sendOtp`
/// Cloud Function and checked server-side by `verifyOtp`.
class VerifyEmailScreen extends StatefulWidget {
  final String role;
  const VerifyEmailScreen({super.key, this.role = 'customer'});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final List<TextEditingController> _ctrs =
      List.generate(_kLen, (_) => TextEditingController());
  final List<FocusNode> _foci = List.generate(_kLen, (_) => FocusNode());
  final _fn = FirebaseFunctions.instance;

  bool _checking = false;
  bool _sending = false;
  bool _verified = false;
  String? _message;
  bool _isError = false;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;
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

  @override
  void initState() {
    super.initState();

    _cardCtrs = List.generate(
        _kLen,
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

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _foci[0].requestFocus();
      _sendCode(first: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _ctrs) c.dispose();
    for (final f in _foci) f.dispose();
    for (final c in _cardCtrs) c.dispose();
    _checkCtrl.dispose();
    _textCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_verified) {
      if (DateTime.now().difference(_openedAt).inMinutes >= _kSessionMinutes) {
        _expireSession();
      }
    }
  }

  Future<void> _expireSession() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String get _code => _ctrs.map((c) => c.text).join();

  void _clearBoxes() {
    for (final c in _ctrs) c.clear();
    for (final ctrl in _cardCtrs) ctrl.reset();
    _foci[0].requestFocus();
  }

  void _onChanged(int index, String val) {
    if (val.length > 1) {
      final digits = val.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= _kLen) {
        // Pasted a full code.
        for (int i = 0; i < _kLen; i++) {
          _ctrs[i].text = digits[i];
          _animateCard(i);
        }
        _foci[_kLen - 1].requestFocus();
      } else if (digits.isNotEmpty) {
        // Typed over a filled box: keep the newest digit.
        _ctrs[index].text = digits[digits.length - 1];
        _animateCard(index);
        if (index < _kLen - 1) _foci[index + 1].requestFocus();
      } else {
        _ctrs[index].clear();
      }
      setState(() {});
      if (_code.length == _kLen) {
        Future.delayed(const Duration(milliseconds: 200), _verify);
      }
      return;
    }
    if (val.isNotEmpty) {
      _animateCard(index);
      if (index < _kLen - 1) {
        Future.delayed(const Duration(milliseconds: 80), () {
          if (mounted) _foci[index + 1].requestFocus();
        });
      }
    }
    setState(() {});
    if (_code.length == _kLen) {
      Future.delayed(const Duration(milliseconds: 200), _verify);
    }
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

  String _fnError(Object e, String fallback) {
    if (e is FirebaseFunctionsException) {
      return e.message ?? fallback;
    }
    return fallback;
  }

  Future<void> _verify() async {
    if (_checking || _verified) return;
    final code = _code;
    if (code.length < _kLen) {
      setState(() {
        _message = 'Please enter all $_kLen digits.';
        _isError = true;
      });
      return;
    }
    setState(() {
      _checking = true;
      _message = null;
      _isError = false;
    });
    try {
      await _fn.httpsCallable('verifyOtp').call({'code': code});
      // Refresh so emailVerified/token reflect the server-side change.
      await FirebaseAuth.instance.currentUser?.reload();
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      _showVerified();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = _fnError(e, 'Verification failed. Check your connection.');
        _isError = true;
      });
      _clearBoxes();
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

  Future<void> _goHome() async {
    final user = FirebaseAuth.instance.currentUser;
    final screen = user != null
        ? await resolveHomeScreen(user)
        : MainScreen(role: widget.role);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
      (_) => false,
    );
  }

  Future<void> _sendCode({bool first = false}) async {
    if (_resendCooldown > 0 || _sending) return;
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      final res = await _fn.httpsCallable('sendOtp').call();
      final data = res.data;
      if (data is Map && data['alreadyVerified'] == true) {
        _showVerified();
        return;
      }
      _startCooldown(45);
      setState(() {
        _message = first ? null : 'New code sent!';
        _isError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = _fnError(e, 'Could not send the code. Try again.');
        _isError = true;
      });
    }
    if (mounted) setState(() => _sending = false);
  }

  void _startCooldown(int seconds) {
    _resendCooldown = seconds;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) t.cancel();
    });
  }

  String get _maskedContact {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final parts = email.split('@');
    if (parts.length == 2 && parts[0].length > 2) {
      return '${parts[0].substring(0, 2)}${'•' * (parts[0].length - 2)}@${parts[1]}';
    }
    return email;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: AppTheme.textMid, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                'Type the code, or paste it. The email may take a minute — check spam too.',
                style: GoogleFonts.nunito(
                    fontSize: 11, color: AppTheme.textMute),
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
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 26),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: AppTheme.gold.withOpacity(.14),
                  shape: BoxShape.circle),
              child: const Center(
                  child: Icon(Icons.mark_email_unread_outlined,
                      size: 26, color: AppTheme.goldDark)),
            ),
            const SizedBox(height: 18),
            Text('Enter your code',
                style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                    letterSpacing: -0.3)),
            const SizedBox(height: 8),
            Text(
              'We emailed a $_kLen-digit code to\n$_maskedContact',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                  fontSize: 13, color: AppTheme.textMid, height: 1.6),
            ),
            const SizedBox(height: 28),

            // OTP boxes, or the fanned "hand of cards" while checking.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _checking
                  ? _CardFan(key: const ValueKey('fan'), digits: _code)
                  : Row(
                      key: const ValueKey('boxes'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                          _kLen,
                          (i) => Flexible(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 3),
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
                                ),
                              )),
                    ),
            ),

            if (_message != null) ...[
              const SizedBox(height: 14),
              Text(_message!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isError ? AppTheme.red : AppTheme.green)),
            ],
            const SizedBox(height: 24),

            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text("Didn't get a code?  ",
                  style: GoogleFonts.nunito(
                      color: AppTheme.textMid, fontSize: 13)),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _resendCooldown == 0 ? _sendCode : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _sending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.gold))
                      : _resendCooldown > 0
                          ? Text('${_resendCooldown}s',
                              style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: AppTheme.textMute,
                                  fontWeight: FontWeight.w700))
                          : Text('Resend',
                              style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.goldDark)),
                ),
              ),
            ]),
          ])),
          const SizedBox(height: 16),
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
                    color: AppTheme.textMid,
                    decoration: TextDecoration.underline,
                    decorationColor: AppTheme.textMute)),
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
                            fontWeight: FontWeight.w800,
                            color: AppTheme.green)))),
            const SizedBox(height: 4),
            SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                    opacity: _textFade,
                    child: Text('Your email is confirmed.',
                        style: GoogleFonts.nunito(
                            fontSize: 12, color: AppTheme.textMid)))),
            const SizedBox(height: 36),
            ScaleTransition(
                scale: _checkScale,
                child: FadeTransition(
                  opacity: _checkOpacity,
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.green.withOpacity(.08),
                        border:
                            Border.all(color: AppTheme.green, width: 2.5)),
                    child: const Center(
                        child: Icon(Icons.check_rounded,
                            color: AppTheme.green, size: 42)),
                  ),
                )),
            const SizedBox(height: 32),
            FadeTransition(
              opacity: _textFade,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goHome,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.navy,
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
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 26),
        decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.navy.withOpacity(.07),
                  blurRadius: 24,
                  offset: const Offset(0, 10))
            ]),
        child: child,
      );
}

/// The typed digits fan out like a hand of cards while the code is checked.
class _CardFan extends StatelessWidget {
  final String digits;
  const _CardFan({super.key, required this.digits});

  @override
  Widget build(BuildContext context) {
    final n = digits.length;
    return SizedBox(
      height: 96,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (_, t, __) => Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: List.generate(n, (i) {
            final mid = (n - 1) / 2;
            final off = i - mid;
            return Transform.translate(
              offset: Offset(off * 26 * t, off.abs() * off.abs() * 2.5 * t),
              child: Transform.rotate(
                angle: off * 0.13 * t,
                child: Container(
                  width: 46,
                  height: 66,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.gold, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.navy.withOpacity(.14),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Text(digits[i],
                      style: GoogleFonts.nunito(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.navy)),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
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
  late final FocusNode _keyNode = FocusNode(skipTraversal: true);

  void _onFocus() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    _keyNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.controller.text.isNotEmpty;
    final borderColor = widget.hasError
        ? AppTheme.red
        : _focused
            ? AppTheme.gold
            : filled
                ? AppTheme.navy.withOpacity(.35)
                : AppTheme.border;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: const BoxConstraints(maxWidth: 50),
      height: 62,
      decoration: BoxDecoration(
        color: _focused
            ? AppTheme.gold.withOpacity(.08)
            : filled
                ? AppTheme.light
                : AppTheme.offWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: _focused ? 2 : 1.2),
      ),
      child: KeyboardListener(
        focusNode: _keyNode,
        onKeyEvent: widget.onKey,
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: _kLen,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: widget.onChanged,
          style: GoogleFonts.nunito(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.navy,
              height: 1),
          cursorColor: AppTheme.gold,
          cursorWidth: 1.8,
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
