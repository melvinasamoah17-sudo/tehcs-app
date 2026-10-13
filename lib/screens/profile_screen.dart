import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'auth/login_screen.dart';
import '../services/auth_routing.dart';
import 'verify/verify_africa_screen.dart';
import '../services/contact_helper.dart';
import '../services/region_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  bool _editing = false;
  bool _saving = false;

  // ── Edit controllers ──
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _emergCtrl;
  late TextEditingController _medCtrl;
  late TextEditingController _dobCtrl;

  Map<String, dynamic> _data = {};
  String _role = 'customer';
  bool _loaded = false;
  File? _newPhoto;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _emergCtrl = TextEditingController();
    _medCtrl = TextEditingController();
    _dobCtrl = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _emergCtrl.dispose();
    _medCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = _user?.uid;
    if (uid == null) return;
    try {
      final db = FirebaseFirestore.instance;

      // 1. Check staff_by_email (admin adds staff here by email)
      final email = _user?.email?.toLowerCase();
      if (email != null) {
        final byEmail = await db.collection('staff_by_email').doc(email).get();
        if (byEmail.exists) {
          final d = byEmail.data() ?? {};
          if (mounted) {
            setState(() {
              _data = {...d, 'role': 'staff'};
              _role = 'staff';
              _loaded = true;
              _nameCtrl.text = d['name'] ?? _user?.displayName ?? '';
              _phoneCtrl.text = d['phone'] ?? '';
              _addressCtrl.text = d['address'] ?? '';
              _emergCtrl.text = d['emergencyContact'] ?? '';
              _medCtrl.text = d['medicalNotes'] ?? '';
              _dobCtrl.text = d['dob'] ?? '';
            });
          }
          return;
        }
      }

      // 2. Try staff collection by uid (legacy / future use)
      var snap = await db.collection('staff').doc(uid).get();
      if (snap.exists) {
        _role = 'staff';
      } else {
        // 3. Fall back to clients collection
        snap = await db.collection('clients').doc(uid).get();
      }
      if (snap.exists && mounted) {
        final d = snap.data() ?? {};
        setState(() {
          _data = d;
          _loaded = true;
          _nameCtrl.text = d['name'] ?? _user?.displayName ?? '';
          _phoneCtrl.text = d['phone'] ?? '';
          _addressCtrl.text = d['address'] ?? '';
          _emergCtrl.text = d['emergencyContact'] ?? '';
          _medCtrl.text = d['medicalNotes'] ?? '';
          _dobCtrl.text = d['dob'] ?? '';
          _role = d['role'] ?? _role;
        });
      } else if (mounted) {
        setState(() {
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _loaded = true;
        });
    }
  }

  /// Switch between Ghana and UK style, saved to the account.
  Future<void> _changeCountry() async {
    final picked = await showModalBottomSheet<AppRegion>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final r in AppRegion.all)
            ListTile(
              leading: Text(r.flag, style: const TextStyle(fontSize: 24)),
              title: Text(r.name),
              trailing: r.code == RegionService.current.code
                  ? const Icon(Icons.check, color: AppTheme.green)
                  : null,
              onTap: () => Navigator.pop(ctx, r),
            ),
        ]),
      ),
    );
    final uid = _user?.uid;
    if (picked == null || uid == null) return;
    await RegionService.set(picked);
    final col = _role == 'staff' ? 'staff' : 'clients';
    try {
      await FirebaseFirestore.instance
          .collection(col)
          .doc(uid)
          .update({'country': picked.code});
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _saveProfile() async {
    final uid = _user?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final col = _role == 'staff' ? 'staff' : 'clients';
      final data = {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        if (_role == 'customer') ...{
          'emergencyContact': _emergCtrl.text.trim(),
          'medicalNotes': _medCtrl.text.trim(),
          'dob': _dobCtrl.text.trim(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection(col).doc(uid).update(data);
      await _user?.updateDisplayName(_nameCtrl.text.trim());
      if (mounted) {
        setState(() {
          _editing = false;
          _data.addAll(data);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Profile updated ✓'),
          backgroundColor: AppTheme.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to save. Please try again.'),
          backgroundColor: AppTheme.red,
          behavior: SnackBarBehavior.floating,
        ));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null && mounted)
      setState(() => _newPhoto = File(picked.path));
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Sign Out',
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.navy)),
        content: Text('Are you sure you want to sign out?',
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMid)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMute))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  shape: const StadiumBorder(),
                  elevation: 0),
              child: Text('Sign Out',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white))),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: CustomScrollView(
        slivers: [
          // ── HEADER ──
          SliverToBoxAdapter(child: _buildHeader()),

          if (!_loaded)
            const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.navy, strokeWidth: 2))),

          if (_loaded) ...[
            // ── EDIT / VIEW FORM ──
            SliverToBoxAdapter(
                child: _editing ? _buildEditForm() : _buildViewForm()),

            // ── ACCOUNT SECTION ──
            SliverToBoxAdapter(child: _buildAccountSection()),

            // ── SIGN OUT ──
            SliverToBoxAdapter(child: _buildSignOut()),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────
  Widget _buildHeader() {
    final name = _data['name'] ??
        _user?.displayName ??
        _user?.email?.split('@').first ??
        'User';
    final email = _user?.email ?? '';
    final role = _data['role'] ?? _role;
    final isStaff = role == 'staff';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.navyDark, AppTheme.navy]),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          child: Column(children: [
            // Top bar
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('PROFILE',
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5)),
              GestureDetector(
                onTap: () => setState(() {
                  _editing = !_editing;
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _editing
                        ? AppTheme.gold
                        : Colors.white.withOpacity(.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(children: [
                    Icon(_editing ? Icons.close : Icons.edit_outlined,
                        size: 14,
                        color: _editing ? AppTheme.navyDark : Colors.white),
                    const SizedBox(width: 5),
                    Text(_editing ? 'Cancel' : 'Edit',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _editing ? AppTheme.navyDark : Colors.white,
                            letterSpacing: 0.4)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 22),

            // Avatar
            GestureDetector(
              onTap: _editing ? _pickPhoto : null,
              child: Stack(children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppTheme.gold,
                  backgroundImage:
                      _newPhoto != null ? FileImage(_newPhoto!) : null,
                  child: _newPhoto == null
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: GoogleFonts.poppins(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.navyDark))
                      : null,
                ),
                if (_editing)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                          color: AppTheme.gold,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppTheme.navyDark, width: 2)),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 14, color: AppTheme.navyDark),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),

            Text(name,
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.3)),
            const SizedBox(height: 4),
            Text(email,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white54,
                    fontWeight: FontWeight.w300)),
            const SizedBox(height: 10),

            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isStaff
                    ? AppTheme.gold.withOpacity(.2)
                    : Colors.white.withOpacity(.1),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                    color: isStaff
                        ? AppTheme.gold.withOpacity(.4)
                        : Colors.white.withOpacity(.2)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isStaff ? Icons.engineering : Icons.home,
                    size: 14, color: isStaff ? AppTheme.gold : Colors.white),
                const SizedBox(width: 6),
                Text(
                  isStaff ? 'Staff Member' : 'Customer',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isStaff ? AppTheme.gold : Colors.white,
                      letterSpacing: 0.5),
                ),
              ]),
            ),

            // Staff DBS badge
            if (isStaff) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: _dbsColor(_data['dbsStatus']).withOpacity(.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: _dbsColor(_data['dbsStatus']).withOpacity(.35)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.assignment_outlined,
                      size: 14, color: _dbsColor(_data['dbsStatus'])),
                  const SizedBox(width: 6),
                  Text(
                    'DBS: ${_data['dbsStatus'] ?? 'Pending'}',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _dbsColor(_data['dbsStatus']),
                        letterSpacing: 0.5),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Color _dbsColor(String? status) => switch (status) {
        'Verified' => AppTheme.green,
        'Expired' => AppTheme.red,
        _ => AppTheme.goldDark,
      };

  // ─────────────────────────────────────────
  // VIEW FORM
  // ─────────────────────────────────────────
  Widget _buildViewForm() {
    final isStaff = _role == 'staff';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Section(title: 'Personal Information', children: [
          _InfoRow(
              icon: Icons.person_outline,
              label: 'Full Name',
              value: _data['name'] ?? _user?.displayName ?? '—'),
          _InfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: _user?.email ?? '—'),
          _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: _data['phone'] ?? '—'),
          _InfoRow(
              icon: Icons.cake_outlined,
              label: 'Date of Birth',
              value: _data['dob'] ?? '—'),
          _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: _data['address'] ?? '—'),
        ]),
        if (!isStaff) ...[
          const SizedBox(height: 14),
          _Section(title: 'Home Care Details', children: [
            _InfoRow(
                icon: Icons.emergency_outlined,
                label: 'Emergency Contact',
                value: _data['emergencyContact'] ?? '—'),
            _InfoRow(
                icon: Icons.medical_services_outlined,
                label: 'Medical Notes',
                value: _data['medicalNotes'] ?? '—',
                multiline: true),
            _InfoRow(
                icon: Icons.schedule_outlined,
                label: 'Preferred Time',
                value: _data['preferredTime'] ?? '—'),
          ]),
        ],
        if (isStaff) ...[
          const SizedBox(height: 14),
          _Section(title: 'Work Details', children: [
            _InfoRow(
                icon: Icons.work_outline,
                label: 'Job Role',
                value: _data['staffRole'] ?? '—'),
            _InfoRow(
                icon: Icons.verified_outlined,
                label: 'DBS Status',
                value: _data['dbsStatus'] ?? 'Pending'),
            _InfoRow(
                icon: (_data['available'] ?? false)
                    ? Icons.check_circle
                    : Icons.cancel,
                label: 'Availability',
                value: (_data['available'] ?? false)
                    ? 'Available'
                    : 'Unavailable'),
          ]),
        ],
      ]),
    );
  }

  // ─────────────────────────────────────────
  // EDIT FORM
  // ─────────────────────────────────────────
  Widget _buildEditForm() {
    final isStaff = _role == 'staff';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionHeader('Personal Information'),
        _EditField(
            label: 'Full Name', ctrl: _nameCtrl, icon: Icons.person_outline),
        _EditField(
            label: 'Phone Number',
            ctrl: _phoneCtrl,
            icon: Icons.phone_outlined,
            type: TextInputType.phone),
        _EditField(
            label: 'Home Address',
            ctrl: _addressCtrl,
            icon: Icons.location_on_outlined),
        _EditField(
            label: 'Date of Birth', ctrl: _dobCtrl, icon: Icons.cake_outlined),
        if (!isStaff) ...[
          const SizedBox(height: 8),
          _SectionHeader('Home Care Details'),
          _EditField(
              label: 'Emergency Contact',
              ctrl: _emergCtrl,
              icon: Icons.emergency_outlined,
              type: TextInputType.phone),
          _EditField(
              label: 'Medical Notes',
              ctrl: _medCtrl,
              icon: Icons.medical_services_outlined,
              multiline: true),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.navyDark,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppTheme.navyDark))
                : Text('Save Changes',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  // ─────────────────────────────────────────
  // ACCOUNT SECTION
  // ─────────────────────────────────────────
  Widget _buildAccountSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: _Section(title: 'Account', children: [
        // ID verification is Ghana only for now
        if (!RegionService.current.isUK)
        _ActionRow(
          icon: Icons.verified_user_outlined,
          label: _data['id_verified'] == true
              ? '✓ Identity Verified'
              : 'Verify My Identity',
          color: _data['id_verified'] == true ? AppTheme.green : AppTheme.navy,
          onTap: _data['id_verified'] == true
              ? null
              : () async {
                  final verified = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => VerifyAfricaScreen(role: _role)));
                  if (verified == true && mounted) {
                    setState(() => _data['id_verified'] = true);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Identity verified successfully ✓'),
                      backgroundColor: AppTheme.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                },
        ),
        _ActionRow(
            icon: Icons.public,
            label: 'Country: ${RegionService.current.flag} ${RegionService.current.name}',
            onTap: _changeCountry),
        _ActionRow(
            icon: Icons.lock_outline,
            label: 'Change Password',
            onTap: _changePassword),
        _ActionRow(
            icon: Icons.phone_outlined,
            label: 'Call TEHCS Support',
            onTap: () => ContactHelper.callOffice(context)),
        _ActionRow(
            icon: Icons.chat_outlined,
            label: 'WhatsApp Support',
            onTap: () async {
              final uri = Uri.parse('https://wa.me/233240699329');
              if (await canLaunchUrl(uri))
                await launchUrl(uri, mode: LaunchMode.externalApplication);
            }),
        _ActionRow(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            onTap: () async {
              final uri = Uri.parse('https://tehcs.com/privacy');
              if (await canLaunchUrl(uri))
                await launchUrl(uri, mode: LaunchMode.externalApplication);
            }),
        _ActionRow(
            icon: Icons.description_outlined,
            label: 'Terms of Service',
            onTap: () async {
              final uri = Uri.parse('https://tehcs.com/terms');
              if (await canLaunchUrl(uri))
                await launchUrl(uri, mode: LaunchMode.externalApplication);
            }),
      ]),
    );
  }

  Future<void> _changePassword() async {
    final email = _user?.email;
    if (email == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Password reset email sent to $email'),
        backgroundColor: AppTheme.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not send reset email.'),
        backgroundColor: AppTheme.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ─────────────────────────────────────────
  // RE-CHECK ROLE (for staff added via admin panel)
  // ─────────────────────────────────────────
  Future<void> _reCheckRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final destination = await resolveHomeScreen(user);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not switch role. Please try again.'),
        backgroundColor: AppTheme.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ─────────────────────────────────────────
  // SIGN OUT
  // ─────────────────────────────────────────
  Widget _buildSignOut() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      child: Column(
        children: [
          // Show "Switch to Staff View" only when role mismatch is possible
          if (_role == 'staff')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _reCheckRole,
                  icon: const Icon(Icons.switch_account_rounded, size: 18),
                  label: Text('Switch to Staff View',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text('Sign Out',
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.red,
                side: const BorderSide(color: AppTheme.red, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// REUSABLE WIDGETS
// ══════════════════════════════════════════
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionHeader(title),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 8)
            ],
          ),
          child: Column(
            children: children
                .asMap()
                .entries
                .map((e) => Column(children: [
                      if (e.key > 0)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                      e.value,
                    ]))
                .toList(),
          ),
        ),
      ]);
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(title.toUpperCase(),
            style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMute,
                letterSpacing: 1.2)),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool multiline;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.multiline = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: AppTheme.textMute),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label.toUpperCase(),
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMute,
                        letterSpacing: 0.8)),
                const SizedBox(height: 3),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: value == '—'
                            ? AppTheme.textMute
                            : AppTheme.navyDark,
                        fontWeight: FontWeight.w500),
                    maxLines: multiline ? 5 : 1,
                    overflow: TextOverflow.ellipsis),
              ])),
        ]),
      );
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData icon;
  final TextInputType type;
  final bool multiline;
  const _EditField(
      {required this.label,
      required this.ctrl,
      required this.icon,
      this.type = TextInputType.text,
      this.multiline = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label.toUpperCase(),
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMute,
                    letterSpacing: 1.1)),
          ),
          TextField(
            controller: ctrl,
            keyboardType: type,
            maxLines: multiline ? 3 : 1,
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.navyDark),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 18, color: AppTheme.textMute),
              filled: true,
              fillColor: AppTheme.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.navy, width: 1.5)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            ),
          ),
        ]),
      );
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  const _ActionRow(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, size: 20, color: color ?? AppTheme.navy),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.navyDark,
                        fontWeight: FontWeight.w500))),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppTheme.textMute),
          ]),
        ),
      );
}
