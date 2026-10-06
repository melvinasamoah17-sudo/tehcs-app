import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../../widgets/animations.dart';

class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key});
  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic> _data = {};
  bool _loaded  = false;
  bool _editing = false;
  bool _saving  = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _dobCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl    = TextEditingController();
    _phoneCtrl   = TextEditingController();
    _addressCtrl = TextEditingController();
    _dobCtrl     = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _addressCtrl.dispose(); _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = _user?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('staff').doc(uid).get();
      if (snap.exists && mounted) {
        final d = snap.data() ?? {};
        setState(() {
          _data          = d;
          _loaded        = true;
          _nameCtrl.text    = d['name']    ?? _user?.displayName ?? '';
          _phoneCtrl.text   = d['phone']   ?? '';
          _addressCtrl.text = d['address'] ?? '';
          _dobCtrl.text     = d['dob']     ?? '';
        });
      } else if (mounted) {
        setState(() => _loaded = true);
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _save() async {
    final uid = _user?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('staff').doc(uid).update({
        'name':    _nameCtrl.text.trim(),
        'phone':   _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'dob':     _dobCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _user?.updateDisplayName(_nameCtrl.text.trim());
      if (mounted) {
        setState(() { _editing = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Profile updated ✓'),
          backgroundColor: AppTheme.green, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {}
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _toggleAvailability() async {
    final uid = _user?.uid;
    if (uid == null) return;
    final current = _data['available'] ?? false;
    await FirebaseFirestore.instance.collection('staff').doc(uid).update({'available': !current});
    setState(() => _data['available'] = !current);
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Sign Out', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.navy)),
        content: Text('Are you sure you want to sign out?', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMid)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMute))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy, shape: const StadiumBorder(), elevation: 0),
            child: Text('Sign Out', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white))),
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

  Color get _dbsColor => switch (_data['dbsStatus'] ?? 'Pending') {
    'Verified' => AppTheme.green,
    'Expired'  => AppTheme.red,
    _          => AppTheme.goldDark,
  };

  @override
  Widget build(BuildContext context) {
    final name  = _data['name'] ?? _user?.displayName ?? 'Staff';
    final email = _user?.email ?? '';
    final role  = _data['staffRole'] ?? 'Team Member';
    final dbs   = _data['dbsStatus'] ?? 'Pending';
    final avail = _data['available'] ?? false;

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: !_loaded
        ? const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2))
        : CustomScrollView(
          slivers: [
            // ── HEADER ──
            SliverToBoxAdapter(child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppTheme.navyDark, AppTheme.navy])),
              child: SafeArea(bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('MY PROFILE', style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
                      GestureDetector(
                        onTap: () => setState(() => _editing = !_editing),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: _editing ? AppTheme.gold : Colors.white.withOpacity(.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(children: [
                            Icon(_editing ? Icons.close : Icons.edit_outlined, size: 14,
                              color: _editing ? AppTheme.navyDark : Colors.white),
                            const SizedBox(width: 5),
                            Text(_editing ? 'Cancel' : 'Edit',
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800,
                                color: _editing ? AppTheme.navyDark : Colors.white, letterSpacing: 0.4)),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    // Avatar
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: AppTheme.gold,
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                        style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.w900, color: AppTheme.navyDark)),
                    ),
                    const SizedBox(height: 12),
                    Text(name, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3)),
                    const SizedBox(height: 4),
                    Text(email, style: GoogleFonts.inter(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w300)),
                    const SizedBox(height: 12),
                    // Badges row
                    Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                      _badge(Icons.engineering, role, AppTheme.gold.withOpacity(.2), AppTheme.gold),
                      _badge(Icons.assignment_outlined, 'DBS: $dbs', _dbsColor.withOpacity(.2), _dbsColor),
                      GestureDetector(
                        onTap: _toggleAvailability,
                        child: _badge(avail ? Icons.check_circle : Icons.cancel,
                          avail ? 'Available' : 'Unavailable',
                          avail ? AppTheme.green.withOpacity(.2) : AppTheme.red.withOpacity(.2),
                          avail ? AppTheme.green : AppTheme.red),
                      ),
                    ]),
                  ]),
                ),
              ),
            )),

            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [

                // ── INFO / EDIT ──
                _editing ? _buildEdit() : _buildInfo(),
                const SizedBox(height: 14),

                // ── STATS ──
                _buildStats(),
                const SizedBox(height: 14),

                // ── ACCOUNT ACTIONS ──
                _buildActions(),
                const SizedBox(height: 14),

                // ── SIGN OUT ──
                SizedBox(width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text('Sign Out', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.red, side: const BorderSide(color: AppTheme.red, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14), shape: const StadiumBorder()),
                  ),
                ),
                const SizedBox(height: 32),
              ]),
            )),
          ],
        ),
    );
  }

  Widget _badge(IconData icon, String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100),
      border: Border.all(color: fg.withOpacity(.35))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: fg),
      const SizedBox(width: 5),
      Text(text, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w800, color: fg, letterSpacing: 0.4)),
    ]),
  );

  // ── INFO VIEW ──
  Widget _buildInfo() => _Card(children: [
    _InfoTile(icon: Icons.person_outline,      label: 'Full Name',    value: _data['name']    ?? '—'),
    _InfoTile(icon: Icons.email_outlined,      label: 'Email',        value: _user?.email     ?? '—'),
    _InfoTile(icon: Icons.phone_outlined,      label: 'Phone',        value: _data['phone']   ?? '—'),
    _InfoTile(icon: Icons.cake_outlined,       label: 'Date of Birth',value: _data['dob']     ?? '—'),
    _InfoTile(icon: Icons.location_on_outlined,label: 'Address',      value: _data['address'] ?? '—'),
    _InfoTile(icon: Icons.work_outline,        label: 'Job Role',     value: _data['staffRole'] ?? '—'),
  ]);

  // ── EDIT FORM ──
  Widget _buildEdit() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _Card(children: [
      _EditTile(label: 'Full Name',    ctrl: _nameCtrl,    icon: Icons.person_outline),
      _EditTile(label: 'Phone',        ctrl: _phoneCtrl,   icon: Icons.phone_outlined,        type: TextInputType.phone),
      _EditTile(label: 'Address',      ctrl: _addressCtrl, icon: Icons.location_on_outlined),
      _EditTile(label: 'Date of Birth',ctrl: _dobCtrl,     icon: Icons.cake_outlined),
    ]),
    const SizedBox(height: 14),
    SizedBox(width: double.infinity,
      child: ElevatedButton(
        onPressed: _saving ? null : _save,
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: AppTheme.navyDark,
          padding: const EdgeInsets.symmetric(vertical: 14), shape: const StadiumBorder(), elevation: 0),
        child: _saving
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.navyDark))
          : Text('Save Changes', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      ),
    ),
  ]);

  // ── STATS ──
  Widget _buildStats() {
    final uid = _user?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: uid == null ? null : FirebaseFirestore.instance.collection('bookings')
        .where('assignedStaffId', isEqualTo: uid).snapshots(),
      builder: (_, snap) {
        final total    = snap.data?.docs.length ?? 0;
        final complete = snap.data?.docs.where((d) => (d.data() as Map)['status'] == 'complete').length ?? 0;
        final active   = snap.data?.docs.where((d) => (d.data() as Map)['status'] == 'active').length ?? 0;
        return Row(children: [
          Expanded(child: _StatCard(value: '$total',    label: 'Total Jobs',  color: AppTheme.navy)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(value: '$complete', label: 'Completed',   color: AppTheme.green)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(value: '$active',   label: 'Active',      color: AppTheme.goldDark)),
        ]);
      },
    );
  }

  // ── ACTIONS ──
  Widget _buildActions() => _Card(children: [
    _ActionTile(icon: Icons.lock_outline, label: 'Change Password', onTap: () async {
      final email = _user?.email;
      if (email == null) return;
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reset email sent to $email'),
        backgroundColor: AppTheme.green, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }),
    _ActionTile(icon: Icons.phone_outlined, label: 'Call Office', onTap: () async {
      final uri = Uri.parse('tel:+233240699329');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }),
    _ActionTile(icon: Icons.chat_outlined, label: 'WhatsApp Office', onTap: () async {
      final uri = Uri.parse('https://wa.me/233240699329');
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    }),
  ]);
}

// ══════════════════════════════════════════
// HELPER WIDGETS
// ══════════════════════════════════════════
class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.border),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 8)]),
    child: Column(children: children.asMap().entries.map((e) => Column(children: [
      if (e.key > 0) const Divider(height: 1, indent: 16, endIndent: 16),
      e.value,
    ])).toList()),
  );
}

class _InfoTile extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(children: [
      Icon(icon, size: 18, color: AppTheme.textMute),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMute, letterSpacing: 0.8)),
        const SizedBox(height: 3),
        Text(value, style: GoogleFonts.inter(fontSize: 14, color: value == '—' ? AppTheme.textMute : AppTheme.navyDark, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );
}

class _EditTile extends StatelessWidget {
  final String label; final TextEditingController ctrl; final IconData icon; final TextInputType type;
  const _EditTile({required this.label, required this.ctrl, required this.icon, this.type = TextInputType.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMute, letterSpacing: 1)),
      const SizedBox(height: 6),
      TextField(controller: ctrl, keyboardType: type,
        style: GoogleFonts.inter(fontSize: 14, color: AppTheme.navyDark),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: AppTheme.textMute),
          filled: true, fillColor: AppTheme.offWhite,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.navy, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        )),
    ]),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, size: 20, color: AppTheme.goldDark),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.navyDark, fontWeight: FontWeight.w500))),
        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMute),
      ]),
    ),
  );
}

class _StatCard extends StatelessWidget {
  final String value; final String label; final Color color;
  const _StatCard({required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
    child: Column(children: [
      CountUp(value: int.tryParse(value) ?? 0, style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w900, color: color, height: 1)),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
    ]),
  );
}
