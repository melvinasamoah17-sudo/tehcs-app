import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_routing.dart';
import '../../widgets/blur_slideshow.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _localAuth = LocalAuthentication();

  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;
  bool _appleLoading = false;
  bool _bioLoading = false;
  bool _bioAvailable = false;
  String? _error;

  // ── Animation controllers ──
  late AnimationController _fadeCtrl;
  late AnimationController _logoCtrl;
  late AnimationController _cardCtrl;
  late AnimationController _bioGlowCtrl;

  late Animation<double> _fadeAnim;
  late Animation<double> _logoScaleAnim;
  late Animation<double> _logoShakeAnim;
  late Animation<Offset> _cardSlideAnim;
  late Animation<double> _cardFadeAnim;
  late Animation<double> _bioGlowAnim;

  @override
  void initState() {
    super.initState();

    // Fade-in for whole screen
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Logo: bounce in then subtle pulse
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _logoScaleAnim = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.12)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 55),
      TweenSequenceItem(
          tween: Tween(begin: 1.12, end: 0.92)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 25),
      TweenSequenceItem(
          tween: Tween(begin: 0.92, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 20),
    ]).animate(_logoCtrl);
    _logoShakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 60),
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 4.0)
              .chain(CurveTween(curve: Curves.elasticIn)),
          weight: 20),
      TweenSequenceItem(
          tween: Tween(begin: 4.0, end: 0.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 20),
    ]).animate(_logoCtrl);

    // Card slides up from below
    _cardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _cardSlideAnim =
        Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
            CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));
    _cardFadeAnim = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);

    // Biometric button glow pulse (repeating)
    _bioGlowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _bioGlowAnim = Tween<double>(begin: 0.3, end: 0.75).animate(
        CurvedAnimation(parent: _bioGlowCtrl, curve: Curves.easeInOut));

    // Stagger: screen → logo → card
    _fadeCtrl.forward();
    Future.delayed(
        const Duration(milliseconds: 100), () => _logoCtrl.forward());
    Future.delayed(
        const Duration(milliseconds: 350), () => _cardCtrl.forward());

    _checkBiometrics();
  }

  // ── Check if biometrics available AND user already signed in ──
  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      final alreadyIn = FirebaseAuth.instance.currentUser != null;
      if (mounted) {
        setState(() => _bioAvailable = (canCheck || isSupported) && alreadyIn);
      }
    } catch (_) {
      // biometrics not available — silently hide the button
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    _fadeCtrl.dispose();
    _logoCtrl.dispose();
    _cardCtrl.dispose();
    _bioGlowCtrl.dispose();
    super.dispose();
  }

  Future<void> _navigate(User user) async {
    final screen = await resolveHomeScreen(user);
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => screen));
  }

  // ── BIOMETRIC ──
  Future<void> _signInBiometric() async {
    setState(() {
      _bioLoading = true;
      _error = null;
    });
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verify your identity to sign in to TEHCS',
        options: const AuthenticationOptions(
          biometricOnly: false, // allows device PIN as fallback
          stickyAuth: true,
        ),
      );
      if (!authenticated) {
        setState(() {
          _bioLoading = false;
        });
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Session expired. Please sign in with your password.';
          _bioAvailable = false;
        });
        return;
      }
      await _navigate(user);
    } catch (e) {
      setState(() => _error = 'Biometric authentication failed.');
    } finally {
      if (mounted) setState(() => _bioLoading = false);
    }
  }

  // ── EMAIL / PASSWORD ──
  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pwd = _pwdCtrl.text;
    if (email.isEmpty || pwd.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pwd);
      await _navigate(cred.user!);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'user-not-found' => 'No account found with this email.',
          'wrong-password' => 'Incorrect password.',
          'invalid-credential' => 'Incorrect email or password.',
          'too-many-requests' => 'Too many attempts. Please wait.',
          'network-request-failed' => 'No internet connection.',
          _ => 'Login failed. Please try again.',
        };
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── GOOGLE ──
  Future<void> _signInGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await GoogleSignIn().signOut();
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _googleLoading = false);
        return;
      }
      final auth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(cred);
      await _navigate(result.user!);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Google sign-in failed.');
    } catch (e) {
      setState(() => _error =
          'Google sign-in failed. Check your SHA-1 is added to Firebase.');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  // ── APPLE ──
  Future<void> _signInApple() async {
    setState(() {
      _appleLoading = true;
      _error = null;
    });
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      final result =
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      final user = result.user!;
      if (result.additionalUserInfo?.isNewUser == true) {
        final firstName = appleCredential.givenName ?? '';
        final lastName = appleCredential.familyName ?? '';
        final fullName = '$firstName $lastName'.trim();
        if (fullName.isNotEmpty) await user.updateDisplayName(fullName);
      }

      await _navigate(user);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        setState(() => _error = 'Apple sign-in failed. Please try again.');
      }
    } catch (e) {
      setState(() => _error = 'Apple sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _appleLoading = false);
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  Future<void> _forgotPassword() async {
    // If email field is empty, show a dialog to collect it
    String email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      final entered = await _promptEmail();
      if (entered == null || entered.isEmpty) return;
      email = entered;
    }

    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _loading = false);
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFF1C2128),
          title: Row(children: [
            const Icon(Icons.mark_email_read_outlined,
                color: Color(0xFF2ECC71), size: 22),
            const SizedBox(width: 10),
            Text('Email Sent',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ]),
          content: Text(
            'A password reset link has been sent to\n$email\n\nCheck your inbox (and spam folder).',
            style: GoogleFonts.nunito(
                fontSize: 13, color: Colors.white60, height: 1.6),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  shape: const StadiumBorder(),
                  elevation: 0),
              child: Text('OK',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final msg = switch (e.code) {
        'user-not-found' => 'No account found for $email.',
        'invalid-email' => 'That doesn\'t look like a valid email.',
        'too-many-requests' => 'Too many attempts. Please wait a moment.',
        _ => 'Could not send reset email. Please try again.',
      };
      setState(() => _error = msg);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not send reset email. Check your connection.';
      });
    }
  }

  Future<String?> _promptEmail() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1C2128),
        title: Text('Reset Password',
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Enter your email address and we\'ll send you a reset link.',
              style: GoogleFonts.nunito(
                  fontSize: 13, color: Colors.white60, height: 1.5)),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.nunito(color: Colors.white),
            cursorColor: AppTheme.gold,
            decoration: InputDecoration(
              hintText: 'your@email.com',
              hintStyle: GoogleFonts.nunito(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withOpacity(.06),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.gold, width: 1.5)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    color: Colors.white38, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navy,
                shape: const StadiumBorder(),
                elevation: 0),
            child: Text('Send Link',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            // ── Background: blurred photo slideshow (plain photos only) ──
            const Positioned.fill(
              child: BlurSlideshow(images: [
                'assets/images/ad_1.jpg',
                'assets/images/ad_2.jpg',
                'assets/images/ad_3.jpg',
                'assets/images/ad_4.jpg',
                'assets/images/ad_5.jpg',
              ]),
            ),

            // ── Content ──
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(children: [
                  const SizedBox(height: 32),

                  // ── TEHCS Logo — bounce in ──
                  AnimatedBuilder(
                    animation: _logoCtrl,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(_logoShakeAnim.value, 0),
                      child: Transform.scale(
                        scale: _logoScaleAnim.value,
                        child: child,
                      ),
                    ),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.gold,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.gold.withOpacity(.4),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/tehcs.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text('T',
                                style: GoogleFonts.barlowCondensed(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.navyDark)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Brand name — slide down after logo
                  SlideTransition(
                    position: _cardSlideAnim,
                    child: FadeTransition(
                      opacity: _cardFadeAnim,
                      child: Column(children: [
                        Text('TWITCH EMPIRE',
                            style: GoogleFonts.barlowCondensed(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 3)),
                        Text('HOME CARE SERVICE',
                            style: GoogleFonts.barlowCondensed(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.gold,
                                letterSpacing: 4)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Glassmorphism card — slides up ──
                  SlideTransition(
                    position: _cardSlideAnim,
                    child: FadeTransition(
                      opacity: _cardFadeAnim,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 1),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.10),
                                  Colors.white.withOpacity(0.04),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ── Heading ──
                                  RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.barlowCondensed(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                        color: Colors.white,
                                      ),
                                      children: const [
                                        TextSpan(text: 'Welcome '),
                                        TextSpan(
                                            text: 'Back',
                                            style: TextStyle(
                                                color: Color(0xFFF5A623))),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Enter your credentials to access your secure account',
                                    style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        color: Colors.white54,
                                        fontWeight: FontWeight.w300),
                                  ),
                                  const SizedBox(height: 20),

                                  // ── Biometric quick-access (animated glow) ──
                                  if (_bioAvailable) ...[
                                    AnimatedBuilder(
                                      animation: _bioGlowAnim,
                                      builder: (_, child) => Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.gold.withOpacity(
                                                  _bioGlowAnim.value * 0.45),
                                              blurRadius: 18,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: child,
                                      ),
                                      child: GestureDetector(
                                        onTap: _bioLoading
                                            ? null
                                            : _signInBiometric,
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppTheme.gold.withOpacity(.18),
                                                AppTheme.gold.withOpacity(.08),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: AppTheme.gold
                                                    .withOpacity(.4),
                                                width: 1),
                                          ),
                                          child: _bioLoading
                                              ? const Center(
                                                  child: SizedBox(
                                                      width: 22,
                                                      height: 22,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2.5,
                                                              color: AppTheme
                                                                  .gold)))
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    // Fingerprint icon pulses
                                                    AnimatedBuilder(
                                                      animation: _bioGlowAnim,
                                                      builder: (_, __) => Icon(
                                                        Icons.fingerprint,
                                                        color: AppTheme.gold
                                                            .withOpacity(0.6 +
                                                                _bioGlowAnim
                                                                        .value *
                                                                    0.4),
                                                        size: 26,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                        'Sign in with Biometrics',
                                                        style: GoogleFonts
                                                            .barlowCondensed(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: AppTheme.gold,
                                                          letterSpacing: 0.5,
                                                        )),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(children: [
                                      Expanded(
                                          child: Divider(
                                              color:
                                                  Colors.white.withOpacity(.12),
                                              thickness: 1)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text('OR USE PASSWORD',
                                            style: GoogleFonts.nunito(
                                                fontSize: 10,
                                                color: Colors.white30,
                                                letterSpacing: 1.1)),
                                      ),
                                      Expanded(
                                          child: Divider(
                                              color:
                                                  Colors.white.withOpacity(.12),
                                              thickness: 1)),
                                    ]),
                                    const SizedBox(height: 16),
                                  ],

                                  // ── Error banner ──
                                  if (_error != null) ...[
                                    _AnimatedErrorBanner(message: _error!),
                                    const SizedBox(height: 14),
                                  ],

                                  // ── Email Address ──
                                  _glassLabel('Email Address'),
                                  const SizedBox(height: 6),
                                  _glassField(
                                    ctrl: _emailCtrl,
                                    hint: 'name@domain.com',
                                    icon: Icons.email_outlined,
                                    type: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 14),

                                  // ── Password ──
                                  _glassLabel('Password'),
                                  const SizedBox(height: 6),
                                  _glassField(
                                    ctrl: _pwdCtrl,
                                    hint: '••••••••••',
                                    icon: Icons.lock_outline,
                                    obscure: _obscure,
                                    onSubmitted: (_) => _login(),
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 18,
                                        color: Colors.white38,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // ── Forgot password ──
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: GestureDetector(
                                      onTap: _forgotPassword,
                                      child: Text('Forgot password?',
                                          style: GoogleFonts.nunito(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.gold)),
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  // ── Sign In button — scale press ──
                                  _PressableButton(
                                    onTap: _loading ? null : _login,
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 15),
                                      decoration: BoxDecoration(
                                        color: AppTheme.gold,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Center(
                                        child: _loading
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        color: Colors.black))
                                            : Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text('Sign In',
                                                      style: GoogleFonts
                                                          .barlowCondensed(
                                                              fontSize: 17,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              color:
                                                                  Colors.black,
                                                              letterSpacing:
                                                                  0.8)),
                                                  const SizedBox(width: 8),
                                                  const Icon(
                                                      Icons
                                                          .arrow_forward_rounded,
                                                      size: 18,
                                                      color: Colors.black),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  // ── OR CONTINUE WITH ──
                                  Row(children: [
                                    Expanded(
                                        child: Divider(
                                            color:
                                                Colors.white.withOpacity(.12),
                                            thickness: 1)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      child: Text('OR CONTINUE WITH',
                                          style: GoogleFonts.nunito(
                                              fontSize: 10,
                                              color: Colors.white30,
                                              letterSpacing: 1.1)),
                                    ),
                                    Expanded(
                                        child: Divider(
                                            color:
                                                Colors.white.withOpacity(.12),
                                            thickness: 1)),
                                  ]),
                                  const SizedBox(height: 14),

                                  // ── Google button ──
                                  _GlassSocialButton(
                                    onTap:
                                        _googleLoading ? null : _signInGoogle,
                                    loading: _googleLoading,
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          RichText(
                                              text: const TextSpan(
                                            style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700),
                                            children: [
                                              TextSpan(
                                                  text: 'G',
                                                  style: TextStyle(
                                                      color:
                                                          Color(0xFF4285F4))),
                                              TextSpan(
                                                  text: 'o',
                                                  style: TextStyle(
                                                      color:
                                                          Color(0xFFEA4335))),
                                              TextSpan(
                                                  text: 'o',
                                                  style: TextStyle(
                                                      color:
                                                          Color(0xFFFBBC05))),
                                              TextSpan(
                                                  text: 'g',
                                                  style: TextStyle(
                                                      color:
                                                          Color(0xFF4285F4))),
                                              TextSpan(
                                                  text: 'l',
                                                  style: TextStyle(
                                                      color:
                                                          Color(0xFF34A853))),
                                              TextSpan(
                                                  text: 'e',
                                                  style: TextStyle(
                                                      color:
                                                          Color(0xFFEA4335))),
                                            ],
                                          )),
                                          const SizedBox(width: 10),
                                          Text('Google',
                                              style: GoogleFonts.nunito(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white70)),
                                        ]),
                                  ),

                                  // ── Apple button (iOS only) ──
                                  if (defaultTargetPlatform ==
                                          TargetPlatform.iOS ||
                                      defaultTargetPlatform ==
                                          TargetPlatform.macOS) ...[
                                    const SizedBox(height: 10),
                                    _GlassSocialButton(
                                      onTap:
                                          _appleLoading ? null : _signInApple,
                                      loading: _appleLoading,
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.apple,
                                                color: Colors.white70,
                                                size: 20),
                                            const SizedBox(width: 8),
                                            Text('Apple',
                                                style: GoogleFonts.nunito(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white70)),
                                          ]),
                                    ),
                                  ],
                                  const SizedBox(height: 18),

                                  // ── Sign Up link ──
                                  Center(
                                    child: GestureDetector(
                                      onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const RegisterScreen())),
                                      child: RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.nunito(
                                              fontSize: 13,
                                              color: Colors.white54),
                                          children: [
                                            const TextSpan(
                                                text:
                                                    "Don't have an account? "),
                                            TextSpan(
                                                text: 'Sign Up',
                                                style:
                                                    GoogleFonts.barlowCondensed(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: AppTheme.gold,
                                                        letterSpacing: 0.4)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ]),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _cardFadeAnim,
                    child: Text(
                        'Staff accounts are set up by the TEHCS admin team.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                            fontSize: 11,
                            color: Colors.white24,
                            fontWeight: FontWeight.w300)),
                  ),
                  const SizedBox(height: 28),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassLabel(String text) => Text(text,
      style: GoogleFonts.nunito(
          fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w600));

  Widget _glassField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        obscureText: obscure,
        onSubmitted: onSubmitted,
        style: GoogleFonts.nunito(fontSize: 14, color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.nunito(
              fontSize: 13, color: Colors.white24, fontWeight: FontWeight.w300),
          prefixIcon: Icon(icon, size: 18, color: Colors.white30),
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.white.withOpacity(.07),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(.12))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(.12))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.gold, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        ),
      );
}

// ══════════════════════════════════════════
// ANIMATED ERROR BANNER
// ══════════════════════════════════════════
class _AnimatedErrorBanner extends StatefulWidget {
  final String message;
  const _AnimatedErrorBanner({required this.message});
  @override
  State<_AnimatedErrorBanner> createState() => _AnimatedErrorBannerState();
}

class _AnimatedErrorBannerState extends State<_AnimatedErrorBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.red.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.red.withOpacity(.3)),
            ),
            child: Row(children: [
              Icon(Icons.error_outline, color: AppTheme.red, size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(widget.message,
                      style: GoogleFonts.nunito(
                          fontSize: 13, color: AppTheme.red))),
            ]),
          ),
        ),
      );
}

// ══════════════════════════════════════════
// PRESSABLE BUTTON (scale on press)
// ══════════════════════════════════════════
class _PressableButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _PressableButton({required this.onTap, required this.child});
  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 100),
        lowerBound: 0,
        upperBound: 1);
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap?.call();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _scale,
          builder: (_, child) =>
              Transform.scale(scale: _scale.value, child: child),
          child: widget.child,
        ),
      );
}

// ══════════════════════════════════════════
// GLASS SOCIAL BUTTON
// ══════════════════════════════════════════
class _GlassSocialButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final bool loading;
  const _GlassSocialButton(
      {required this.onTap, required this.child, this.loading = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: loading
              ? const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white54)))
              : child,
        ),
      );
}
