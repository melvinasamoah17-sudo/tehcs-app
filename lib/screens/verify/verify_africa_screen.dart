import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_routing.dart';
import '../auth/login_screen.dart';

// ─────────────────────────────────────────
// VERIFYAFRICA CONFIG (API v2)
// Docs: https://github.com/verifyafricadev/verifyafrica-api-docs
// Key: VerifyAfrica dashboard → API keys (starts with "VA-")
// ─────────────────────────────────────────
const _vaBaseUrl = 'https://api.verifyafrica.io/api/v2/public/verifications';
// Supplied at build time: flutter run --dart-define-from-file=secrets.json
const _vaApiKey  = String.fromEnvironment('VERIFY_AFRICA_API_KEY');

/// ID type → [VerifyAfrica registry check, ID-number field].
/// The Ghana Card has no registry check, so it uses hosted document capture.
const _registryChecks = {
  'PASSPORT': ['gh_passport_lookup',        'passport_number'],
  'DRIVERS':  ['gh_drivers_license_lookup', 'license_number'],
  'SSNIT':    ['gh_ssnit_lookup',           'ssnit_number'],
  'VOTERS':   ['gh_voter_card_lookup',      'voter_id'],
};

class _VaError implements Exception {
  final String message;
  _VaError(this.message);
}

class VerifyAfricaScreen extends StatefulWidget {
  final String role; // 'customer' | 'staff'
  /// Part of sign-up: cannot be skipped, and continues into the app.
  final bool onboarding;
  const VerifyAfricaScreen({super.key, this.role = 'customer', this.onboarding = false});

  @override
  State<VerifyAfricaScreen> createState() => _VerifyAfricaScreenState();
}

class _VerifyAfricaScreenState extends State<VerifyAfricaScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  final _pageCtrl   = PageController();
  int   _step       = 0; // 0=select ID, 1=enter details, 2=verify, 3=result

  // ── ID Types ──
  // Ghana only for now; UK documents to be added later.
  final String _country = 'GH';
  String _idType    = 'GHANA_CARD';
  static const _idTypesByCountry = {
    'GH': [
      {'id': 'GHANA_CARD',  'label': 'Ghana Card',        'icon': Icons.badge_outlined, 'desc': 'National ID Card', 'hint': 'e.g. GHA-XXXXXXXXX-X'},
      {'id': 'PASSPORT',    'label': 'Passport',           'icon': Icons.import_contacts_outlined, 'desc': 'Ghanaian Passport', 'hint': 'e.g. G1234567'},
      {'id': 'DRIVERS',     'label': 'Driver\'s Licence',  'icon': Icons.directions_car_outlined, 'desc': 'DVLA Ghana Driver\'s Licence', 'hint': 'Licence number'},
      {'id': 'SSNIT',       'label': 'SSNIT Card',         'icon': Icons.account_balance_outlined, 'desc': 'Social Security Card', 'hint': 'SSNIT number'},
      {'id': 'VOTERS',      'label': 'Voter\'s ID',        'icon': Icons.how_to_vote_outlined, 'desc': 'Electoral Commission ID', 'hint': 'Voter ID number'},
    ],
  };
  List<Map<String, Object>> get _idTypes => _idTypesByCountry[_country]!;

  // ── Form fields ──
  final _idNumberCtrl  = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _dobCtrl       = TextEditingController();
  String _dobIso       = ''; // sent to the API as YYYY-MM-DD

  // ── State ──
  bool    _loading    = false;
  bool    _verified   = false;
  bool    _pending    = false; // waiting for VerifyAfrica's result
  bool    _awaitingReturn = false; // user is on the hosted capture page
  String? _verificationId;
  String? _captureUrl;
  String? _error;
  Map<String, dynamic>? _result;
  Timer?  _poll;

  late AnimationController _animCtrl;
  late Animation<double>   _checkScale;

  bool get _hasRegistryCheck => _registryChecks.containsKey(_idType);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _checkScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut));
    _resumePending();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _pageCtrl.dispose();
    _idNumberCtrl.dispose(); _firstNameCtrl.dispose();
    _lastNameCtrl.dispose(); _dobCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // Back from the hosted capture page → fetch the result.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingReturn) {
      _awaitingReturn = false;
      _startPolling();
    }
  }

  void _goTo(int step) {
    setState(() { _step = step; });
    _pageCtrl.animateToPage(step,
      duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  void _next() {
    if (_step == 1 && !_validateDetails()) return;
    if (_step < 3) {
      setState(() { _step++; _error = null; });
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  void _back() {
    if (_step > 0 && !_pending) {
      setState(() { _step--; _error = null; });
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else if (widget.onboarding) {
      _signOut();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  Future<void> _finish() async {
    if (!widget.onboarding) {
      Navigator.of(context).pop(true);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _signOut();
    final screen = await resolveHomeScreen(user);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen), (_) => false);
  }

  bool _validateDetails() {
    if (_idNumberCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your ID number.');
      return false;
    }
    if (_firstNameCtrl.text.trim().isEmpty || _lastNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your full name.');
      return false;
    }
    return true;
  }

  // ═══════════════════════════════════════
  // VERIFYAFRICA API
  // ═══════════════════════════════════════
  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_vaApiKey',
    'Content-Type':  'application/json',
    'Accept':        'application/json',
  };

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic>? data;
    try { data = jsonDecode(res.body) as Map<String, dynamic>; } catch (_) {}
    if (res.statusCode >= 200 && res.statusCode < 300 &&
        data != null && data['success'] != false) {
      return data;
    }
    final msg = data?['message'] ??
        'Verification service error (HTTP ${res.statusCode}). Please try again later.';
    throw _VaError(msg.toString());
  }

  Future<Map<String, dynamic>> _vaPost(String path, Map<String, dynamic> body) async {
    if (_vaApiKey.isEmpty) {
      throw _VaError('Identity verification is not set up in this version of the app.');
    }
    final res = await http
        .post(Uri.parse('$_vaBaseUrl$path'), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    return _decode(res);
  }

  Map<String, dynamic> get _personFields => {
    'first_name': _firstNameCtrl.text.trim(),
    'last_name':  _lastNameCtrl.text.trim(),
  };

  DocumentReference<Map<String, dynamic>>? get _profileRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection(widget.role == 'staff' ? 'staff' : 'clients').doc(uid);
  }

  String _friendlyError(Object e) {
    if (e is _VaError) return e.message;
    if (e is SocketException) return 'No internet connection. Please check your connection and try again.';
    if (e is TimeoutException) return 'The verification service is taking too long. Please try again.';
    return 'Something went wrong. Please try again.';
  }

  /// Opens VerifyAfrica's secure page (selfie and/or ID photos).
  Future<void> _startHosted() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user  = FirebaseAuth.instance.currentUser;
      final email = (user?.email?.isNotEmpty ?? false)
          ? user!.email! : '${user?.uid ?? 'customer'}@users.tehcs.app';
      final reg = _registryChecks[_idType];
      final Map<String, dynamic> res;
      if (reg == null) {
        // Ghana Card → photograph front and back of the card
        res = await _vaPost('/requests/document_verification/', {
          'mode': 'link',
          'send_email': false,
          'allow_file_upload': false,
          'input_data': {
            'email': email, 'language': 'EN', 'ttl': 60, 'country': _country,
            ..._personFields,
            'document': {
              'verification_mode': 'any',
              'backside_proof_required': true,
              'fetch_enhanced_data': true,
              'name': {..._personFields, 'fuzzy_match': true},
            },
          },
        });
      } else {
        // Registry lookup + selfie match on VerifyAfrica's page
        res = await _vaPost('/requests/government_registry_checks/', {
          'verification_type': reg[0],
          'mode': 'link',
          'send_email': false,
          'allow_file_upload': false,
          'input_data': {
            'email': email, 'language': 'EN', 'ttl': 60,
            'require_selfie': true,
            reg[1]: _idNumberCtrl.text.trim(),
            ..._personFields,
            if (_dobIso.isNotEmpty) 'date_of_birth': _dobIso,
          },
        });
      }
      final data = (res['data'] as Map?) ?? {};
      _verificationId = data['id']?.toString();
      _captureUrl     = (data['link'] as Map?)?['url']?.toString();
      if (_verificationId == null || _captureUrl == null) {
        throw _VaError('The verification service did not return a capture page. Please try again.');
      }
      await _rememberPending();
      setState(() { _loading = false; _pending = true; });
      await _openCapturePage();
    } catch (e) {
      if (mounted) setState(() { _error = _friendlyError(e); _loading = false; });
    }
  }

  Future<void> _openCapturePage() async {
    final url = _captureUrl;
    if (url == null) return;
    _awaitingReturn = true;
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
    if (!ok && mounted) {
      _awaitingReturn = false;
      setState(() => _error = 'Could not open the verification page.');
    }
  }

  /// Skip selfie: check the ID number against the government record only.
  Future<void> _verifyIdOnly() async {
    final reg = _registryChecks[_idType];
    if (reg == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _vaPost('/requests/government_registry_checks/', {
        'verification_type': reg[0],
        'mode': 'direct',
        'input_data': {
          'language': 'EN',
          reg[1]: _idNumberCtrl.text.trim(),
          ..._personFields,
          if (_dobIso.isNotEmpty) 'date_of_birth': _dobIso,
        },
      });
      final data = (res['data'] as Map?) ?? {};
      _verificationId = data['id']?.toString();
      if (_verificationId == null) {
        throw _VaError('The verification service did not accept the request. Please try again.');
      }
      _captureUrl = null;
      await _rememberPending();
      setState(() { _loading = false; _pending = true; });
      if (!_handleStatus(data)) _startPolling();
    } catch (e) {
      if (mounted) setState(() { _error = _friendlyError(e); _loading = false; });
    }
  }

  /// Ask VerifyAfrica for the result every few seconds for up to ~3 minutes.
  void _startPolling() {
    _poll?.cancel();
    var tries = 0;
    _checkStatus();
    _poll = Timer.periodic(const Duration(seconds: 4), (t) {
      if (!_pending || ++tries > 45) { t.cancel(); return; }
      _checkStatus();
    });
  }

  Future<void> _checkStatus({bool manual = false}) async {
    final id = _verificationId;
    if (id == null) return;
    if (manual) setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(
        Uri.parse('$_vaBaseUrl/requests/?verification_id=${Uri.encodeQueryComponent(id)}'),
        headers: _headers,
      ).timeout(const Duration(seconds: 20));
      final data = (_decode(res)['data'] as Map?) ?? {};
      final done = _handleStatus(data);
      if (manual && !done && mounted) {
        setState(() => _error = 'Still checking — this can take a minute. Please wait.');
      }
    } catch (e) {
      if (manual && mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (manual && mounted) setState(() => _loading = false);
    }
  }

  /// Returns true when VerifyAfrica has finished (passed or failed).
  bool _handleStatus(Map data) {
    final status = (data['status'] ?? 'PENDING').toString().toUpperCase();
    if (status == 'SUCCESS') {
      _poll?.cancel();
      _saveVerification().whenComplete(() {
        if (!mounted) return;
        setState(() {
          _result = Map<String, dynamic>.from(data);
          _verified = true; _pending = false;
        });
        _animCtrl.forward();
        _goTo(3);
      });
      return true;
    }
    if (status == 'FAILED' || status == 'ERROR') {
      _poll?.cancel();
      _clearPending();
      if (mounted) {
        setState(() {
          _pending = false; _verified = false;
          _error = 'We could not verify this ID. Make sure the ID number and your '
              'name match your ID exactly, then try again.';
        });
        _goTo(3);
      }
      return true;
    }
    return false;
  }

  // Remember an in-progress check so it can be resumed after closing the app.
  Future<void> _rememberPending() async {
    try {
      await _profileRef?.set({
        'pendingVerificationId': _verificationId,
        'pendingVerificationIdType': _idType,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _clearPending() async {
    try {
      await _profileRef?.update({
        'pendingVerificationId': FieldValue.delete(),
        'pendingVerificationIdType': FieldValue.delete(),
      });
    } catch (_) {}
  }

  Future<void> _resumePending() async {
    try {
      final d = (await _profileRef?.get())?.data() ?? {};
      final id = d['pendingVerificationId'] as String?;
      if (id == null || !mounted) return;
      _verificationId = id;
      _idType = (d['pendingVerificationIdType'] as String?) ?? _idType;
      setState(() => _pending = true);
      _goTo(2);
      _startPolling();
    } catch (_) {}
  }

  Future<void> _saveVerification() async {
    final ref = _profileRef;
    if (ref == null) return;
    try {
      await ref.set({
        'id_verified':     true,
        'verifiedAt':      FieldValue.serverTimestamp(),
        'idType':          _idType,
        'idCountry':       _country,
        'verifyAfricaRef': _verificationId ?? '',
        'pendingVerificationId': FieldValue.delete(),
        'pendingVerificationIdType': FieldValue.delete(),
      }, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('verifications').add({
        'uid':       ref.id,
        'role':      widget.role,
        'type':      'id_verified',
        'idType':    _idType,
        'idCountry': _country,
        'status':    'verified',
        'reference': _verificationId ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.navyDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: _back),
        title: Text('Identity Verification', style: GoogleFonts.poppins(
          fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(child: Text('${_step + 1}/4',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white54))),
          ),
        ],
      ),
      body: Column(children: [
        // Step progress bar
        _StepBar(step: _step),
        Expanded(
          child: PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStep0SelectId(),
              _buildStep1Details(),
              _buildStep2Verify(),
              _buildStep3Result(),
            ],
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════
  // STEP 0 — SELECT ID TYPE
  // ═══════════════════════════════════════
  Widget _buildStep0SelectId() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Select ID Type'),
        Text(widget.onboarding
            ? 'Last step of sign-up — verify your identity to start using TEHCS. Choose the type of ID.'
            : 'Choose the type of ID you want to verify with',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
        const SizedBox(height: 20),

        // VerifyAfrica badge
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.navy.withOpacity(.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.navy.withOpacity(.15))),
          child: Row(children: [
            const Icon(Icons.lock_outline, size: 24, color: AppTheme.navy),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Powered by VerifyAfrica', style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.navy, letterSpacing: 0.3)),
              Text('Your identity is verified securely. We do not store your ID documents.',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMute,
                  fontWeight: FontWeight.w300, height: 1.5)),
            ])),
          ]),
        ),
        const SizedBox(height: 20),

        ..._idTypes.map((t) {
          final sel = _idType == t['id'];
          return GestureDetector(
            onTap: () => setState(() => _idType = t['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sel ? AppTheme.navy.withOpacity(.05) : AppTheme.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sel ? AppTheme.navy : AppTheme.border, width: sel ? 1.5 : 1)),
              child: Row(children: [
                Icon(t['icon'] as IconData, size: 28, color: sel ? AppTheme.navy : AppTheme.textMid),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t['label'] as String, style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w900,
                    color: sel ? AppTheme.navy : AppTheme.navyDark, letterSpacing: 0.3)),
                  Text(t['desc'] as String, style: GoogleFonts.inter(
                    fontSize: 12, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
                ])),
                Icon(sel ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: sel ? AppTheme.navy : AppTheme.border, size: 22),
              ]),
            ),
          );
        }),

        const SizedBox(height: 20),
        _nextBtn('Continue', _next),
      ]),
    );
  }

  // ═══════════════════════════════════════
  // STEP 1 — ENTER DETAILS
  // ═══════════════════════════════════════
  Widget _buildStep1Details() {
    final idInfo  = _idTypes.firstWhere((t) => t['id'] == _idType);
    final idLabel = idInfo['label'] as String;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Enter Your Details'),
        Text('Enter the details exactly as they appear on your $idLabel',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
        const SizedBox(height: 20),

        if (_error != null) _ErrorBox(message: _error!),

        _label('ID Number'),
        _field(ctrl: _idNumberCtrl, hint: idInfo['hint'] as String, icon: Icons.credit_card_outlined,
          caps: TextCapitalization.characters),
        const SizedBox(height: 14),

        _label('First Name (as on ID)'),
        _field(ctrl: _firstNameCtrl, hint: 'First name', icon: Icons.person_outline),
        const SizedBox(height: 14),

        _label('Last Name (as on ID)'),
        _field(ctrl: _lastNameCtrl, hint: 'Last name', icon: Icons.person_outline),
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
                  colorScheme: ColorScheme.light(primary: AppTheme.navy)),
                child: child!),
            );
            if (picked != null && mounted) {
              final dd = picked.day.toString().padLeft(2, '0');
              final mm = picked.month.toString().padLeft(2, '0');
              _dobIso       = '${picked.year}-$mm-$dd';
              _dobCtrl.text = '$dd/$mm/${picked.year}';
            }
          },
          child: AbsorbPointer(child: _field(ctrl: _dobCtrl, hint: 'DD/MM/YYYY', icon: Icons.cake_outlined)),
        ),
        const SizedBox(height: 28),
        _nextBtn('Verify My ID', _next),
      ]),
    );
  }

  // ═══════════════════════════════════════
  // STEP 2 — VERIFY (hosted capture or ID-number check)
  // ═══════════════════════════════════════
  Widget _buildStep2Verify() {
    if (_pending) return _buildWaiting();
    final isCard = !_hasRegistryCheck;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(isCard ? 'Scan Your Ghana Card' : 'Confirm It\'s You'),
        Text(
          isCard
              ? 'You\'ll be taken to VerifyAfrica\'s secure page to photograph the front and back of your Ghana Card.'
              : 'You\'ll be taken to VerifyAfrica\'s secure page to take a quick selfie, which is matched with your ID record.',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMute, fontWeight: FontWeight.w300, height: 1.5)),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.gold.withOpacity(.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.gold.withOpacity(.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TIPS FOR BEST RESULTS', style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.goldDark, letterSpacing: 1)),
            const SizedBox(height: 8),
            ...(isCard
                ? ['Place the card on a plain, dark surface',
                   'Make sure all four corners are visible',
                   'Avoid glare and shadows',
                   'Come back to this app when you\'re done']
                : ['Face the camera directly and remove glasses',
                   'Make sure the room is well lit',
                   'Do not cover your face',
                   'Come back to this app when you\'re done'])
              .map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.goldDark),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tip, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMid, fontWeight: FontWeight.w300))),
                ]),
              )),
          ]),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorBox(message: _error!),
        ],
        const SizedBox(height: 20),

        _nextBtn(
          _loading ? 'Please wait...' : (isCard ? 'Scan My Ghana Card' : 'Verify With Selfie'),
          _loading ? null : _startHosted,
          loading: _loading,
        ),

        if (!isCard) ...[
          const SizedBox(height: 10),
          Center(child: TextButton(
            onPressed: _loading ? null : _verifyIdOnly,
            child: Text('Skip selfie — check ID number only', style: GoogleFonts.inter(
              fontSize: 13, color: AppTheme.textMute, fontWeight: FontWeight.w300,
              decoration: TextDecoration.underline, decorationColor: AppTheme.textMute)),
          )),
        ],
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildWaiting() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        const SizedBox(height: 30),
        const SizedBox(width: 56, height: 56,
          child: CircularProgressIndicator(color: AppTheme.navy, strokeWidth: 3)),
        const SizedBox(height: 24),
        Text('Checking Your ID', style: GoogleFonts.poppins(
          fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Text(
          _captureUrl != null
              ? 'Finish the steps on the VerifyAfrica page, then come back here. We\'ll update this screen automatically.'
              : 'We\'re checking your details with the official record. This usually takes under a minute.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMid, fontWeight: FontWeight.w300, height: 1.6)),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _ErrorBox(message: _error!),
        ],
        const SizedBox(height: 24),
        _nextBtn(_loading ? 'Checking...' : 'Check Result Now',
          _loading ? null : () => _checkStatus(manual: true), loading: _loading),
        if (_captureUrl != null) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: _openCapturePage,
            child: Text('Open the verification page again', style: GoogleFonts.inter(
              fontSize: 13, color: AppTheme.navy, fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline, decorationColor: AppTheme.navy)),
          ),
        ],
        TextButton(
          onPressed: () {
            _poll?.cancel();
            _clearPending();
            setState(() { _pending = false; _verificationId = null; _captureUrl = null; _error = null; });
          },
          child: Text('Start again', style: GoogleFonts.inter(
            fontSize: 13, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════
  // STEP 3 — RESULT
  // ═══════════════════════════════════════
  Widget _buildStep3Result() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: _verified ? _buildSuccess() : _buildFailed(),
      ),
    );
  }

  Widget _buildSuccess() {
    final name = (_result?['data']?['first_name'] ?? _firstNameCtrl.text).toString();
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      ScaleTransition(
        scale: _checkScale,
        child: Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.green, width: 3)),
          child: const Center(child: Icon(Icons.verified_user_rounded, color: AppTheme.green, size: 52))),
      ),
      const SizedBox(height: 24),
      Text('Identity Verified!', style: GoogleFonts.poppins(
        fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      Text('Welcome, $name! Your identity has been successfully verified.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMid, fontWeight: FontWeight.w300, height: 1.7)),
      const SizedBox(height: 24),

      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.green.withOpacity(.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.green.withOpacity(.2))),
        child: Column(children: [
          _ResultRow(Icons.check_circle, 'Identity confirmed'),
          const SizedBox(height: 8),
          _ResultRow(Icons.lock, 'Documents not stored'),
          const SizedBox(height: 8),
          _ResultRow(Icons.assignment_turned_in, 'Verification record saved'),
        ]),
      ),
      const SizedBox(height: 28),

      SizedBox(width: double.infinity,
        child: ElevatedButton(
          onPressed: _finish,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold, foregroundColor: AppTheme.navyDark,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: const StadiumBorder(), elevation: 0),
          child: Text('Continue', style: GoogleFonts.poppins(
            fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        ),
      ),
    ]);
  }

  Widget _buildFailed() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 100, height: 100,
        decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: AppTheme.red, width: 3)),
        child: const Center(child: Icon(Icons.gpp_bad_rounded, color: AppTheme.red, size: 52)),
      ),
      const SizedBox(height: 24),
      Text('Verification Failed', style: GoogleFonts.poppins(
        fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 0.5)),
      const SizedBox(height: 10),
      Text(_error ?? 'We could not verify your identity. Please check your details and try again.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMid, fontWeight: FontWeight.w300, height: 1.7)),
      const SizedBox(height: 28),
      SizedBox(width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            setState(() { _error = null; _step = 1; _verificationId = null; _captureUrl = null; });
            _pageCtrl.animateToPage(1,
              duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.navy, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: const StadiumBorder(), elevation: 0),
          child: Text('Try Again', style: GoogleFonts.poppins(
            fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        ),
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: widget.onboarding ? _signOut : () => Navigator.pop(context),
        child: Text(widget.onboarding ? 'Sign out' : 'Skip for now', style: GoogleFonts.inter(
          fontSize: 13, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
      ),
    ]);
  }

  // ── HELPERS ──
  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(t, style: GoogleFonts.poppins(
      fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 0.5)),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t.toUpperCase(), style: GoogleFonts.poppins(
      fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMute, letterSpacing: 1.2)),
  );

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    TextCapitalization caps = TextCapitalization.words,
  }) => TextField(
    controller: ctrl,
    textCapitalization: caps,
    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.navyDark),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMute, fontWeight: FontWeight.w300),
      prefixIcon: Icon(icon, size: 18, color: AppTheme.textMute),
      filled: true, fillColor: AppTheme.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.navy, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
  );

  Widget _nextBtn(String label, VoidCallback? onTap, {bool loading = false}) =>
    SizedBox(width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.gold, foregroundColor: AppTheme.navyDark,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: const StadiumBorder(), elevation: 0),
        child: loading
          ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.navyDark))
          : Text(label, style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      ),
    );
}

// ── Step progress bar ──
class _StepBar extends StatelessWidget {
  final int step;
  const _StepBar({required this.step});
  static const _labels = ['ID Type', 'Details', 'Verify', 'Result'];
  @override
  Widget build(BuildContext context) => Container(
    color: AppTheme.navyDark,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Column(children: [
      Row(children: List.generate(4, (i) => Expanded(child: Row(children: [
        Expanded(child: AnimatedContainer(
          duration: const Duration(milliseconds: 300), height: 3,
          decoration: BoxDecoration(
            color: i <= step ? AppTheme.gold : Colors.white12,
            borderRadius: BorderRadius.circular(2)),
        )),
        if (i < 3) const SizedBox(width: 4),
      ])))),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(4, (i) => Text(_labels[i],
          style: GoogleFonts.poppins(
            fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5,
            color: i <= step ? AppTheme.gold : Colors.white24)))),
    ]),
  );
}

// ── Error box ──
class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: AppTheme.red.withOpacity(.08), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.red.withOpacity(.25))),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppTheme.red, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.red))),
    ]),
  );
}

// ── Result row ──
class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ResultRow(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 16, color: AppTheme.green),
    const SizedBox(width: 10),
    Text(text, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMid)),
  ]);
}
