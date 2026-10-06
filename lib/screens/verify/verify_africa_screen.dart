import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────
// VERIFYAFRICA CONFIG
// Get your API key from: https://verifyafrica.io
// Dashboard → Settings → API Keys
// ─────────────────────────────────────────
const _vaBaseUrl = 'https://api.verifyafrica.io/v1';
// Supplied at build time: flutter run --dart-define-from-file=secrets.json
const _vaApiKey  = String.fromEnvironment('VERIFY_AFRICA_API_KEY');

class VerifyAfricaScreen extends StatefulWidget {
  final String role; // 'customer' | 'staff'
  const VerifyAfricaScreen({super.key, this.role = 'customer'});

  @override
  State<VerifyAfricaScreen> createState() => _VerifyAfricaScreenState();
}

class _VerifyAfricaScreenState extends State<VerifyAfricaScreen>
    with SingleTickerProviderStateMixin {

  final _pageCtrl   = PageController();
  int   _step       = 0; // 0=select ID, 1=enter details, 2=selfie, 3=result

  // ── ID Types ──
  String _idType    = 'GHANA_CARD';
  final _idTypes = [
    {'id': 'GHANA_CARD',  'label': 'Ghana Card',        'icon': Icons.badge_outlined, 'desc': 'National ID Card'},
    {'id': 'PASSPORT',    'label': 'Passport',           'icon': Icons.import_contacts_outlined, 'desc': 'International Passport'},
    {'id': 'DRIVERS',     'label': 'Driver\'s Licence',  'icon': Icons.directions_car_outlined, 'desc': 'DVLA Driver\'s Licence'},
    {'id': 'SSNIT',       'label': 'SSNIT Card',         'icon': Icons.account_balance_outlined, 'desc': 'Social Security Card'},
    {'id': 'VOTERS',      'label': 'Voter\'s ID',        'icon': Icons.how_to_vote_outlined, 'desc': 'Electoral Commission ID'},
  ];

  // ── Form fields ──
  final _idNumberCtrl  = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _dobCtrl       = TextEditingController();

  // ── State ──
  File?   _selfie;
  bool    _loading    = false;
  bool    _verified   = false;
  bool    _failed     = false;
  String? _error;
  Map<String, dynamic>? _result;

  late AnimationController _animCtrl;
  late Animation<double>   _checkScale;

  @override
  void initState() {
    super.initState();
    _animCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _checkScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _idNumberCtrl.dispose(); _firstNameCtrl.dispose();
    _lastNameCtrl.dispose(); _dobCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 1 && !_validateDetails()) return;
    if (_step < 3) {
      setState(() { _step++; _error = null; });
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() { _step--; _error = null; });
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
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

  Future<void> _pickSelfie() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked != null && mounted) {
      setState(() => _selfie = File(picked.path));
    }
  }

  // ── VERIFY ID ──
  Future<void> _verifyId() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await http.post(
        Uri.parse('$_vaBaseUrl/verify/id'),
        headers: {
          'Authorization': 'Bearer $_vaApiKey',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({
          'id_type':    _idType,
          'id_number':  _idNumberCtrl.text.trim(),
          'first_name': _firstNameCtrl.text.trim(),
          'last_name':  _lastNameCtrl.text.trim(),
          'dob':        _dobCtrl.text.trim(),
          'country':    'GH',
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        // Save verification result to Firestore
        await _saveVerification(data, 'id_verified');
        setState(() { _result = data; _verified = true; _loading = false; });
        _animCtrl.forward();
      } else {
        setState(() {
          _failed = true;
          _error  = data['message'] ?? 'Verification failed. Please check your details.';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error   = 'Network error. Please check your connection and try again.';
        _loading = false;
      });
    }
  }

  // ── LIVENESS / SELFIE CHECK ──
  Future<void> _verifyLiveness() async {
    if (_selfie == null) {
      setState(() => _error = 'Please take a selfie first.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final bytes  = await _selfie!.readAsBytes();
      final base64 = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('$_vaBaseUrl/verify/liveness'),
        headers: {
          'Authorization': 'Bearer $_vaApiKey',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({
          'image':   base64,
          'country': 'GH',
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        await _saveVerification(data, 'liveness_verified');
        setState(() { _result = data; _verified = true; _loading = false; });
        _animCtrl.forward();
      } else {
        setState(() {
          _failed = true;
          _error  = data['message'] ?? 'Liveness check failed. Please try again in good lighting.';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() { _error = 'Network error. Please try again.'; _loading = false; });
    }
  }

  Future<void> _saveVerification(Map<String, dynamic> data, String type) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final col = widget.role == 'staff' ? 'staff' : 'clients';
    await FirebaseFirestore.instance.collection(col).doc(uid).update({
      type:              true,
      'verifiedAt':      FieldValue.serverTimestamp(),
      'idType':          _idType,
      'verifyAfricaRef': data['reference'] ?? '',
    });
    // Also log to verifications collection
    await FirebaseFirestore.instance.collection('verifications').add({
      'uid':       uid,
      'role':      widget.role,
      'type':      type,
      'idType':    _idType,
      'status':    'verified',
      'reference': data['reference'] ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
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
              _buildStep2Selfie(),
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
        Text('Choose the type of ID you want to verify with',
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
    final idLabel = _idTypes.firstWhere((t) => t['id'] == _idType)['label'] as String;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Enter Your Details'),
        Text('Enter the details exactly as they appear on your $idLabel',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
        const SizedBox(height: 20),

        if (_error != null) _ErrorBox(message: _error!),

        _label('ID Number'),
        _field(ctrl: _idNumberCtrl, hint: 'e.g. GHA-XXXXXXXXX-X', icon: Icons.credit_card_outlined,
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
              _dobCtrl.text =
                '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
            }
          },
          child: AbsorbPointer(child: _field(ctrl: _dobCtrl, hint: 'YYYY-MM-DD', icon: Icons.cake_outlined)),
        ),
        const SizedBox(height: 28),
        _nextBtn('Verify My ID', _next),
      ]),
    );
  }

  // ═══════════════════════════════════════
  // STEP 2 — SELFIE / LIVENESS
  // ═══════════════════════════════════════
  Widget _buildStep2Selfie() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Liveness Check'),
        Text('Take a selfie to confirm you are the ID holder',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
        const SizedBox(height: 24),

        // Selfie preview / placeholder
        GestureDetector(
          onTap: _pickSelfie,
          child: Container(
            width: double.infinity, height: 260,
            decoration: BoxDecoration(
              color: AppTheme.navy.withOpacity(.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _selfie != null ? AppTheme.green : AppTheme.border,
                width: _selfie != null ? 2 : 1, style: BorderStyle.solid)),
            child: _selfie != null
              ? Stack(fit: StackFit.expand, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Image.file(_selfie!, fit: BoxFit.cover)),
                  Positioned(top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppTheme.green, borderRadius: BorderRadius.circular(100)),
                      child: Text('✓ Photo taken', style: GoogleFonts.poppins(
                        fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.4)))),
                ])
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.camera_alt_outlined, size: 48, color: AppTheme.textMute),
                  const SizedBox(height: 12),
                  Text('Tap to take selfie', style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textMute)),
                  const SizedBox(height: 6),
                  Text('Make sure your face is clearly visible\nand well-lit', textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMute,
                      fontWeight: FontWeight.w300, height: 1.5)),
                ]),
          ),
        ),
        const SizedBox(height: 16),

        // Tips
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
            ...['Face the camera directly and remove glasses',
                'Make sure the room is well lit',
                'Keep a neutral expression',
                'Do not cover your face'].map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.goldDark),
                const SizedBox(width: 8),
                Text(tip, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMid, fontWeight: FontWeight.w300)),
              ]),
            )),
          ]),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorBox(message: _error!),
        ],
        const SizedBox(height: 20),

        if (_selfie != null)
          _nextBtn(
            _loading ? 'Verifying...' : 'Submit & Verify',
            _loading ? null : _verifyLiveness,
            loading: _loading,
          )
        else
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _pickSelfie,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: Text('Take Selfie', style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navy, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: const StadiumBorder(), elevation: 0),
            ),
          ),

        const SizedBox(height: 10),
        // Skip liveness — just do ID check
        Center(child: TextButton(
          onPressed: _loading ? null : _verifyId,
          child: Text('Skip selfie — verify ID only', style: GoogleFonts.inter(
            fontSize: 13, color: AppTheme.textMute, fontWeight: FontWeight.w300,
            decoration: TextDecoration.underline, decorationColor: AppTheme.textMute)),
        )),
        const SizedBox(height: 20),
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
          onPressed: () => Navigator.of(context).pop(true),
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
            setState(() { _failed = false; _error = null; _step = 1; });
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
        onPressed: () => Navigator.pop(context),
        child: Text('Skip for now', style: GoogleFonts.inter(
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
  static const _labels = ['ID Type', 'Details', 'Selfie', 'Result'];
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
