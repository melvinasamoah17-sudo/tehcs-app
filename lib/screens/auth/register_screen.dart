import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_routing.dart';
import '../../services/phone_auth_helper.dart';
import '../../services/region_service.dart';
import '../verify/verify_africa_screen.dart';
import 'verify_email_screen.dart';
import '../../widgets/blur_slideshow.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _step = 0; // 0 = basic info, 1 = extra info

  // ── Controllers ──
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pwdCtrl   = TextEditingController();
  final _pwd2Ctrl  = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emergCtrl   = TextEditingController();
  final _medCtrl     = TextEditingController();
  final _dobCtrl     = TextEditingController();

  bool _obscure  = true;
  bool _obscure2 = true;
  bool _agreed   = false;
  bool _loading  = false;
  bool _googleLoading = false;
  bool _appleLoading  = false;
  String? _error;
  File? _photo;
  String _prefTime = 'Morning';

  final _prefTimes = ['Morning', 'Afternoon', 'Evening', 'Flexible'];

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _pwdCtrl.dispose();
    _pwd2Ctrl.dispose();
    _addressCtrl.dispose();
    _emergCtrl.dispose();
    _medCtrl.dispose();
    _dobCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null && mounted) setState(() => _photo = File(picked.path));
  }

  bool _validateBasic() {
    if (_nameCtrl.text.trim().isEmpty) {
      _setErr('Please enter your full name.');
      return false;
    }
    if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) {
      _setErr('Enter a valid email address.');
      return false;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      _setErr('Please enter your phone number.');
      return false;
    }
    if (_pwdCtrl.text.length < 8) {
      _setErr('Password must be at least 8 characters.');
      return false;
    }
    if (_pwdCtrl.text != _pwd2Ctrl.text) {
      _setErr('Passwords do not match.');
      return false;
    }
    if (!_agreed) {
      _setErr('Please agree to the Terms & Privacy Policy.');
      return false;
    }
    return true;
  }

  void _setErr(String msg) => setState(() => _error = msg);

  void _next() {
    setState(() => _error = null);
    if (_step == 0) {
      if (!_validateBasic()) return;
      setState(() => _step = 1);
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _register();
    }
  }

  void _back() {
    setState(() => _error = null);
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  double get _pwdStrength {
    final p = _pwdCtrl.text;
    if (p.isEmpty) return 0;
    double s = 0;
    if (p.length >= 8) s += 0.25;
    if (p.length >= 12) s += 0.25;
    if (p.contains(RegExp(r'[0-9]'))) s += 0.25;
    if (p.contains(RegExp(r'[!@#\$%^&*]'))) s += 0.25;
    return s;
  }

  Color get _pwdColor {
    final s = _pwdStrength;
    if (s <= 0.25) return AppTheme.red;
    if (s <= 0.5)  return AppTheme.gold;
    return AppTheme.green;
  }

  String get _pwdLabel {
    final s = _pwdStrength;
    if (s == 0)    return '';
    if (s <= 0.25) return 'Weak';
    if (s <= 0.5)  return 'Fair';
    if (s <= 0.75) return 'Strong';
    return 'Very Strong ✓';
  }

  Future<void> _register() async {
    setState(() { _loading = true; _error = null; });
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwdCtrl.text,
      );
      await cred.user?.updateDisplayName(_nameCtrl.text.trim());

      final uid = cred.user!.uid;
      final region = RegionService.current;
      await FirebaseFirestore.instance.collection('clients').doc(uid).set({
        'uid':              uid,
        'name':             _nameCtrl.text.trim(),
        'email':            _emailCtrl.text.trim(),
        'phone':            PhoneAuthHelper.normalize(_phoneCtrl.text.trim(), dial: region.dial),
        'role':             'customer',
        'country':          region.code,
        'address':          _addressCtrl.text.trim(),
        'dob':              _dobCtrl.text.trim(),
        'emergencyContact': _emergCtrl.text.trim(),
        'medicalNotes':     _medCtrl.text.trim(),
        'preferredTime':    _prefTime,
        'createdAt':        FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      // Identity verification is part of sign-up (Ghana); email check follows.
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => idVerificationRequired
              ? const VerifyAfricaScreen(role: 'customer', onboarding: true)
              : const VerifyEmailScreen(role: 'customer')));
    } on FirebaseAuthException catch (e) {
      _setErr(switch (e.code) {
        'email-already-in-use' => 'An account already exists with this email.',
        'weak-password'        => 'Password is too weak.',
        'invalid-email'        => 'Invalid email address.',
        _                      => 'Registration failed. Please try again.',
      });
    } catch (e) {
      _setErr('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _navigateAfterSocial(User user) async {
    final screen = await resolveHomeScreen(user);
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => screen));
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
      await _navigateAfterSocial(result.user!);
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

      await _navigateAfterSocial(user);
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
              child: Column(
                children: [
                  // Back button + step dots
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                    child: Row(children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 18),
                        onPressed: _back,
                      ),
                      const Spacer(),
                      Row(
                        children: List.generate(2, (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: i == _step ? 24 : 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: i == _step
                                ? AppTheme.gold
                                : i < _step
                                    ? AppTheme.gold.withOpacity(.4)
                                    : Colors.white12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )),
                      ),
                    ]),
                  ),

                  Expanded(
                    child: PageView(
                      controller: _pageCtrl,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStep0Basic(),
                        _buildStep1Extra(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════
  // STEP 0 — BASIC INFO (new design)
  // ═══════════════════════════════════
  Widget _buildStep0Basic() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // ── Glassmorphism card ──
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
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
                          TextSpan(text: 'Create '),
                          TextSpan(
                            text: 'Account',
                            style: TextStyle(color: Color(0xFFF5A623)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Join us today to access your secure workspace',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: Colors.white54,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_error != null) _ErrorBox(message: _error!),

                    // ── Country (switches the app to Ghana or UK style) ──
                    _glassLabel('Where are you based?'),
                    const SizedBox(height: 6),
                    Row(children: [
                      for (final r in AppRegion.all) ...[
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              await RegionService.set(r);
                              setState(() {});
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: RegionService.current.code == r.code
                                    ? AppTheme.gold
                                    : Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: RegionService.current.code == r.code
                                        ? AppTheme.gold
                                        : Colors.white24),
                              ),
                              child: Center(
                                child: Text('${r.flag}  ${r.isUK ? 'UK' : r.name}',
                                    style: GoogleFonts.nunito(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: RegionService.current.code == r.code
                                            ? AppTheme.navyDark
                                            : Colors.white)),
                              ),
                            ),
                          ),
                        ),
                        if (r != AppRegion.all.last) const SizedBox(width: 10),
                      ],
                    ]),
                    const SizedBox(height: 14),

                    // ── Full Name ──
                    _glassLabel('Full Name'),
                    const SizedBox(height: 6),
                    _glassField(
                      ctrl: _nameCtrl,
                      hint: 'Alex Johnson',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 14),

                    // ── Email ──
                    _glassLabel('Email Address'),
                    const SizedBox(height: 6),
                    _glassField(
                      ctrl: _emailCtrl,
                      hint: 'name@domain.com',
                      icon: Icons.email_outlined,
                      type: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),

                    // ── Password + Confirm (side by side like video) ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _glassLabel('Password'),
                              const SizedBox(height: 6),
                              _glassField(
                                ctrl: _pwdCtrl,
                                hint: '••••••••',
                                icon: Icons.lock_outline,
                                obscure: _obscure,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                    color: Colors.white38,
                                  ),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _glassLabel('Confirm Password'),
                              const SizedBox(height: 6),
                              _glassField(
                                ctrl: _pwd2Ctrl,
                                hint: '•••',
                                icon: Icons.lock_outline,
                                obscure: _obscure2,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscure2
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                    color: Colors.white38,
                                  ),
                                  onPressed: () => setState(() => _obscure2 = !_obscure2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // ── Password strength ──
                    if (_pwdCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _pwdStrength,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation(_pwdColor),
                              minHeight: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(_pwdLabel,
                            style: GoogleFonts.nunito(
                                fontSize: 10, color: _pwdColor, fontWeight: FontWeight.w700)),
                      ]),
                    ],
                    const SizedBox(height: 14),

                    // ── Phone ──
                    _glassLabel('Phone / WhatsApp'),
                    const SizedBox(height: 6),
                    _glassField(
                      ctrl: _phoneCtrl,
                      hint: '+${RegionService.current.dial} ${RegionService.current.phoneHint}',
                      icon: Icons.phone_outlined,
                      type: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // ── Terms checkbox ──
                    GestureDetector(
                      onTap: () => setState(() => _agreed = !_agreed),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            color: _agreed ? AppTheme.gold : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: _agreed ? AppTheme.gold : Colors.white38,
                              width: 1.5,
                            ),
                          ),
                          child: _agreed
                              ? const Icon(Icons.check, size: 14, color: Colors.black)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'I agree to the Terms & Privacy Policy',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: Colors.white60,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // ── Create Account button ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Create Account',
                                style: GoogleFonts.barlowCondensed(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8)),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── OR SIGN UP WITH ──
                    Row(children: [
                      Expanded(child: Divider(color: Colors.white.withOpacity(.12), thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR SIGN UP WITH',
                            style: GoogleFonts.nunito(
                                fontSize: 10, color: Colors.white30, letterSpacing: 1.1)),
                      ),
                      Expanded(child: Divider(color: Colors.white.withOpacity(.12), thickness: 1)),
                    ]),
                    const SizedBox(height: 14),

                    // ── Google + Apple buttons ──
                    Row(children: [
                      Expanded(
                        child: _socialButton(
                          label: 'Google',
                          icon: Icons.g_mobiledata,
                          loading: _googleLoading,
                          onTap: (_googleLoading || _appleLoading)
                              ? null
                              : _signInGoogle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _socialButton(
                          label: 'Apple',
                          icon: Icons.apple,
                          loading: _appleLoading,
                          onTap: (_googleLoading || _appleLoading)
                              ? null
                              : _signInApple,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 18),

                    // ── Sign In link ──
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pushReplacement(context,
                            MaterialPageRoute(builder: (_) => const LoginScreen())),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.nunito(fontSize: 13, color: Colors.white54),
                            children: [
                              const TextSpan(text: 'Already have an account? '),
                              TextSpan(
                                text: 'Sign In',
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.gold,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _socialButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white70),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(label,
                      style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }

  Widget _glassLabel(String text) => Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 12,
          color: Colors.white60,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _glassField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        obscureText: obscure,
        onChanged: onChanged,
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

  // ═══════════════════════════════════
  // STEP 1 — EXTRA INFO (unchanged)
  // ═══════════════════════════════════
  Widget _buildStep1Extra() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        Text('Your Profile',
            style: GoogleFonts.barlowCondensed(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5)),
        Text('Optional — helps us personalise your care',
            style: GoogleFonts.nunito(
                fontSize: 13,
                color: Colors.white54,
                fontWeight: FontWeight.w300)),
        const SizedBox(height: 24),
        if (_error != null) _ErrorBox(message: _error!),
        _label('Home Address'),
        _field(
            ctrl: _addressCtrl,
            hint: RegionService.current.addressHint,
            icon: Icons.location_on_outlined),
        const SizedBox(height: 14),
        _label('Date of Birth'),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime(1990),
              firstDate: DateTime(1920),
              lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)),
              builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                      colorScheme: ColorScheme.dark(
                          primary: AppTheme.gold, surface: AppTheme.navy)),
                  child: child!),
            );
            if (picked != null && mounted) {
              setState(() => _dobCtrl.text =
                  '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}');
            }
          },
          child: AbsorbPointer(
              child: _field(
                  ctrl: _dobCtrl,
                  hint: 'DD / MM / YYYY',
                  icon: Icons.cake_outlined)),
        ),
        const SizedBox(height: 14),
        _label('Emergency Contact'),
        _field(
            ctrl: _emergCtrl,
            hint: 'Name & phone number',
            icon: Icons.emergency_outlined,
            type: TextInputType.phone),
        const SizedBox(height: 14),
        _label('Preferred Service Times'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(.1))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _prefTime,
              isExpanded: true,
              dropdownColor: AppTheme.navy,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white38),
              style: GoogleFonts.nunito(fontSize: 14, color: Colors.white),
              items: _prefTimes
                  .map((s) => DropdownMenuItem(
                      value: s,
                      child: Row(children: [
                        const Icon(Icons.schedule_outlined,
                            size: 18, color: Colors.white38),
                        const SizedBox(width: 10),
                        Text(s),
                      ])))
                  .toList(),
              onChanged: (v) => setState(() => _prefTime = v!),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _label('Medical Notes (optional)'),
        TextField(
          controller: _medCtrl,
          maxLines: 3,
          style: GoogleFonts.nunito(fontSize: 14, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Allergies, conditions or special requirements...',
            hintStyle: GoogleFonts.nunito(
                fontSize: 13,
                color: Colors.white24,
                fontWeight: FontWeight.w300),
            filled: true,
            fillColor: Colors.white.withOpacity(.06),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(.1))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(.1))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.gold, width: 1.5)),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
              'By creating an account you agree to our Terms of Service and Privacy Policy.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: Colors.white30,
                  fontWeight: FontWeight.w300,
                  height: 1.6)),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _next,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: const StadiumBorder(),
                elevation: 0),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.black))
                : Text('Create Account',
                    style: GoogleFonts.barlowCondensed(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
          ),
        ),
        const SizedBox(height: 28),
      ]),
    );
  }

  // ── Step 1 helpers (original style, dark bg) ──
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(text.toUpperCase(),
            style: GoogleFonts.barlowCondensed(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white38,
                letterSpacing: 1.2)),
      );

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        obscureText: obscure,
        onChanged: onChanged,
        style: GoogleFonts.nunito(fontSize: 14, color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.nunito(
              fontSize: 14, color: Colors.white24, fontWeight: FontWeight.w300),
          prefixIcon: Icon(icon, size: 20, color: Colors.white24),
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.white.withOpacity(.06),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(.1))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(.1))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.gold, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: AppTheme.red.withOpacity(.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.red.withOpacity(.3))),
        child: Row(children: [
          Icon(Icons.error_outline, color: AppTheme.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: GoogleFonts.nunito(fontSize: 13, color: AppTheme.red))),
        ]),
      );
}
