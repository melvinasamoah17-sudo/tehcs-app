import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});
  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic> _staffData = {};
  bool _loaded = false;
  bool _clockedIn = false;
  DateTime? _clockInTime;

  // ── Staff's own service category — pending jobs only pool to it ──
  String? _myCategory;
  String  _myName = '';

  @override
  void initState() {
    super.initState();
    _loadStaffData();
    _loadMyCategory();
  }

  Future<void> _loadMyCategory() async {
    try {
      String? cat;
      String  name = '';
      final email = _user?.email?.toLowerCase();
      if (email != null) {
        final byEmail = await FirebaseFirestore.instance
            .collection('staff_by_email').doc(email).get();
        if (byEmail.exists) {
          final d = byEmail.data() ?? {};
          cat  = d['category'] as String?;
          name = d['name'] as String? ?? '';
        }
      }
      final uid = _user?.uid;
      if ((cat == null || cat.isEmpty) && uid != null) {
        final byUid = await FirebaseFirestore.instance.collection('staff').doc(uid).get();
        if (byUid.exists) {
          final d = byUid.data() ?? {};
          cat ??= d['category'] as String?;
          if (name.isEmpty) name = d['name'] as String? ?? '';
        }
      }
      if (mounted) {
        setState(() {
          _myCategory = cat;
          _myName     = name.isNotEmpty ? name : (_user?.displayName ?? '');
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStaffData() async {
    final uid = _user?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('staff').doc(uid).get();
      if (snap.exists && mounted) {
        final d = snap.data() ?? {};
        setState(() {
          _staffData  = d;
          _clockedIn  = d['clockedIn'] ?? false;
          _clockInTime = (d['clockInTime'] as Timestamp?)?.toDate();
          _loaded     = true;
        });
      } else {
        if (mounted) setState(() => _loaded = true);
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _toggleClock() async {
    final uid = _user?.uid;
    if (uid == null) return;
    final now = DateTime.now();
    try {
      if (_clockedIn) {
        // Clock out
        await FirebaseFirestore.instance.collection('staff').doc(uid).update({
          'clockedIn':   false,
          'clockOutTime': FieldValue.serverTimestamp(),
          'lastSession': _clockInTime != null
            ? now.difference(_clockInTime!).inMinutes
            : 0,
        });
        // Log attendance
        await FirebaseFirestore.instance.collection('attendance').add({
          'uid':       uid,
          'name':      _staffData['name'] ?? '',
          'clockIn':   _clockInTime != null ? Timestamp.fromDate(_clockInTime!) : null,
          'clockOut':  FieldValue.serverTimestamp(),
          'date':      DateFormat('dd/MM/yyyy').format(now),
          'duration':  _clockInTime != null ? now.difference(_clockInTime!).inMinutes : 0,
        });
        if (mounted) setState(() { _clockedIn = false; _clockInTime = null; });
      } else {
        // Clock in
        await FirebaseFirestore.instance.collection('staff').doc(uid).update({
          'clockedIn':   true,
          'clockInTime': FieldValue.serverTimestamp(),
        });
        if (mounted) setState(() { _clockedIn = true; _clockInTime = now; });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_clockedIn ? Icons.check_circle : Icons.waving_hand, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Flexible(child: Text(_clockedIn ? 'Clocked in at ${DateFormat('HH:mm').format(now)}' : 'Clocked out at ${DateFormat('HH:mm').format(now)}')),
        ]),
        backgroundColor: _clockedIn ? AppTheme.green : AppTheme.navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (_) {}
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName {
    final name = _staffData['name'] ?? _user?.displayName ?? 'there';
    return name.toString().split(' ').first;
  }

  String get _clockedDuration {
    if (!_clockedIn || _clockInTime == null) return '';
    final diff = DateTime.now().difference(_clockInTime!);
    final h    = diff.inHours;
    final m    = diff.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final uid = _user?.uid;

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: CustomScrollView(
        slivers: [
          // ── HEADER ──
          SliverToBoxAdapter(child: _buildHeader()),

          // ── CLOCK IN/OUT ──
          SliverToBoxAdapter(child: _buildClockCard()),

          // ── TODAY'S JOBS ──
          SliverToBoxAdapter(child: _buildSectionLabel("TODAY'S JOBS")),
          if (uid != null)
            SliverToBoxAdapter(child: _buildTodayJobs(uid)),

          // ── STATS ──
          SliverToBoxAdapter(child: _buildSectionLabel('THIS WEEK')),
          if (uid != null)
            SliverToBoxAdapter(child: _buildWeekStats(uid)),

          // ── PENDING JOBS ──
          SliverToBoxAdapter(child: _buildSectionLabel('PENDING REQUESTS')),
          if (uid != null)
            SliverToBoxAdapter(child: _buildPendingJobs(uid)),

          // ── QUICK ACTIONS ──
          SliverToBoxAdapter(child: _buildQuickActions()),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppTheme.navyDark, AppTheme.navy]),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/images/tehcs.jpg', width: 36, height: 36, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: AppTheme.gold, borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text('T', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.navyDark))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TEHCS STAFF', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                  Text(_staffData['staffRole'] ?? 'Team Member', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.gold, letterSpacing: 0.8)),
                ]),
              ]),
              // Clock status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _clockedIn ? AppTheme.green.withOpacity(.2) : Colors.white.withOpacity(.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: _clockedIn ? AppTheme.green.withOpacity(.4) : Colors.white.withOpacity(.2)),
                ),
                child: Row(children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: _clockedIn ? AppTheme.green : Colors.white38, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(_clockedIn ? 'ON DUTY' : 'OFF DUTY',
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800,
                      color: _clockedIn ? AppTheme.green : Colors.white38, letterSpacing: 0.8)),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            Text('$_greeting,', style: GoogleFonts.inter(fontSize: 13, color: Colors.white60, fontWeight: FontWeight.w300)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_firstName, style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
              const SizedBox(width: 8),
              const Icon(Icons.waving_hand_rounded, color: AppTheme.gold, size: 24),
            ]),
            const SizedBox(height: 6),
            Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w300)),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // CLOCK CARD
  // ─────────────────────────────────────────
  Widget _buildClockCard() {
    return Container(
      color: AppTheme.navyDark,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _clockedIn ? AppTheme.green.withOpacity(.12) : Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _clockedIn ? AppTheme.green.withOpacity(.3) : Colors.white.withOpacity(.1)),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_clockedIn ? 'CLOCKED IN' : 'NOT CLOCKED IN',
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w800,
                color: _clockedIn ? AppTheme.green : Colors.white38, letterSpacing: 1)),
            const SizedBox(height: 4),
            if (_clockedIn && _clockInTime != null) ...[
              Text('Since ${DateFormat('HH:mm').format(_clockInTime!)}',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              Text(_clockedDuration, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.green, fontWeight: FontWeight.w600)),
            ] else
              Text('Tap to start your shift', style: GoogleFonts.inter(fontSize: 13, color: Colors.white38, fontWeight: FontWeight.w300)),
          ])),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _toggleClock,
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _clockedIn ? AppTheme.red : AppTheme.green,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: (_clockedIn ? AppTheme.red : AppTheme.green).withOpacity(.4), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(_clockedIn ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 28),
                Text(_clockedIn ? 'OUT' : 'IN',
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────
  // TODAY'S JOBS
  // ─────────────────────────────────────────
  Widget _buildTodayJobs(String uid) {
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bookings')
        .where('assignedStaffId', isEqualTo: uid)
        .where('date', isEqualTo: today)
        .orderBy('time')
        .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2)));
        }
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
              child: Column(children: [
                const Icon(Icons.celebration_outlined, size: 32, color: AppTheme.goldDark),
                const SizedBox(height: 8),
                Text('No jobs today', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textMute)),
                const SizedBox(height: 4),
                Text('Enjoy your day off!', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
              ]),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return _JobCard(data: data, docId: d.id, isToday: true);
          }).toList()),
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // WEEK STATS
  // ─────────────────────────────────────────
  Widget _buildWeekStats(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('attendance')
        .where('uid', isEqualTo: uid)
        .orderBy('clockIn', descending: true)
        .limit(7)
        .snapshots(),
      builder: (_, snap) {
        final docs   = snap.data?.docs ?? [];
        final totalM = docs.fold<int>(0, (sum, d) => sum + ((d.data() as Map)['duration'] as int? ?? 0));
        final hours  = totalM ~/ 60;
        final jobs   = docs.length;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _WeekStat(value: '$jobs',      label: 'Sessions',  color: AppTheme.navy),
            const SizedBox(width: 10),
            _WeekStat(value: '${hours}h',  label: 'Hours',     color: AppTheme.goldDark),
            const SizedBox(width: 10),
            _WeekStat(value: _staffData['dbsStatus'] == 'Verified' ? '✓' : '!',
              label: 'DBS', color: _staffData['dbsStatus'] == 'Verified' ? AppTheme.green : AppTheme.red),
          ]),
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // PENDING JOBS
  // ─────────────────────────────────────────
  Widget _buildPendingJobs(String uid) {
    final assignedStream = FirebaseFirestore.instance.collection('bookings')
        .where('assignedStaffId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();

    final poolStream = (_myCategory == null || _myCategory!.isEmpty)
        ? null
        : FirebaseFirestore.instance.collection('bookings')
            .where('category', isEqualTo: _myCategory)
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: assignedStream,
      builder: (_, snapA) {
        if (poolStream == null) {
          return _renderPendingJobs(snapA.data?.docs ?? []);
        }
        return StreamBuilder<QuerySnapshot>(
          stream: poolStream,
          builder: (_, snapB) {
            final seen = <String>{};
            final merged = <QueryDocumentSnapshot>[];
            for (final d in [...(snapA.data?.docs ?? []), ...(snapB.data?.docs ?? [])]) {
              if (seen.add(d.id)) merged.add(d);
            }
            merged.sort((x, y) {
              final tx = (x.data() as Map)['createdAt'] as Timestamp?;
              final ty = (y.data() as Map)['createdAt'] as Timestamp?;
              if (tx == null || ty == null) return 0;
              return ty.compareTo(tx);
            });
            return _renderPendingJobs(merged.take(5).toList());
          },
        );
      },
    );
  }

  Widget _renderPendingJobs(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
          child: Row(children: [
            const Icon(Icons.inbox_outlined, size: 24, color: AppTheme.textMute),
            const SizedBox(width: 12),
            Text('No pending requests', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMute)),
          ]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return _JobCard(data: data, docId: d.id, isToday: false, myName: _myName);
      }).toList()),
    );
  }

  // ─────────────────────────────────────────
  // QUICK ACTIONS
  // ─────────────────────────────────────────
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionLabelInline('QUICK ACTIONS'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _QuickAction(icon: Icons.phone, label: 'Call Office', color: AppTheme.navy,
            onTap: () async { final uri = Uri.parse('tel:+233240699329'); if (await canLaunchUrl(uri)) await launchUrl(uri); })),
          const SizedBox(width: 10),
          Expanded(child: _QuickAction(icon: Icons.chat, label: 'WhatsApp', color: const Color(0xFF25D366),
            onTap: () async { final uri = Uri.parse('https://wa.me/233240699329'); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); })),
          const SizedBox(width: 10),
          Expanded(child: _QuickAction(icon: Icons.calendar_month, label: 'My Rota', color: AppTheme.goldDark,
            onTap: () {})),
        ]),
      ]),
    );
  }

  Widget _buildSectionLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(text, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.navy, letterSpacing: 1.5)),
  );

  Widget _buildSectionLabelInline(String text) =>
    Text(text, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.navy, letterSpacing: 1.5));
}

// ══════════════════════════════════════════
// JOB CARD
// ══════════════════════════════════════════
class _JobCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isToday;
  final String myName;
  const _JobCard({required this.data, required this.docId, required this.isToday, this.myName = ''});

  bool get _isOpenPool =>
      data['status'] == 'pending' &&
      (data['assignedStaffId'] as String? ?? '').isEmpty;

  Color get _statusColor => switch (data['status'] as String? ?? '') {
    'active'    => AppTheme.green,
    'complete'  => AppTheme.navy,
    'cancelled' => AppTheme.red,
    _           => AppTheme.goldDark,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Status bar
        Container(height: 4, decoration: BoxDecoration(color: _statusColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(16)))),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(data['icon'] ?? '📋', style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data['service'] ?? 'Service', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 0.3)),
                Text(data['clientName'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _statusColor.withOpacity(.1), borderRadius: BorderRadius.circular(100)),
                child: Text((data['status'] ?? 'pending').toString().toUpperCase(),
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: _statusColor, letterSpacing: 0.5)),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _Chip(icon: Icons.calendar_today_outlined, text: data['date'] ?? 'TBD'),
              const SizedBox(width: 8),
              _Chip(icon: Icons.access_time_outlined,   text: data['time'] ?? 'TBD'),
              const SizedBox(width: 8),
              _Chip(icon: Icons.schedule_outlined,      text: '${data['hours'] ?? 0}h'),
            ]),
            if ((data['address'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textMute),
                const SizedBox(width: 4),
                Expanded(child: Text(data['address'], style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMute, fontWeight: FontWeight.w300), overflow: TextOverflow.ellipsis)),
              ]),
            ],
            if (data['status'] == 'pending') ...[
              const SizedBox(height: 12),
              Row(children: [
                if (!_isOpenPool) ...[
                  Expanded(child: OutlinedButton(
                    onPressed: () => _updateStatus(context, 'cancelled'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.red, side: const BorderSide(color: AppTheme.red), shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 9)),
                    child: Text('Decline', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
                  )),
                  const SizedBox(width: 10),
                ],
                Expanded(child: ElevatedButton(
                  onPressed: () => _acceptJob(context),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green, foregroundColor: Colors.white, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 9), elevation: 0),
                  child: Text('Accept', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
                )),
              ]),
            ],
            if (data['status'] == 'active') ...[
              const SizedBox(height: 12),
              SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(context, 'complete'),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text('Mark Complete', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy, foregroundColor: Colors.white, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 10), elevation: 0),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Future<void> _updateStatus(BuildContext context, String status) async {
    await FirebaseFirestore.instance.collection('bookings').doc(docId).update({'status': status});
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(status == 'active' ? Icons.check_circle : status == 'complete' ? Icons.flag : Icons.cancel,
          color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(status == 'active' ? 'Job accepted!' : status == 'complete' ? 'Marked complete!' : 'Job declined.')),
      ]),
      backgroundColor: status == 'active' ? AppTheme.green : status == 'complete' ? AppTheme.navy : AppTheme.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // Transaction-safe accept — prevents two staff in the same category
  // claiming the same open-pool booking at once.
  Future<void> _acceptJob(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance.collection('bookings').doc(docId);
    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(ref);
        final d = snap.data() as Map<String, dynamic>? ?? {};
        final currentAssigned = d['assignedStaffId'] as String? ?? '';
        if (currentAssigned.isNotEmpty && currentAssigned != uid) {
          throw StateError('ALREADY_TAKEN');
        }
        txn.update(ref, {
          'status':            'active',
          'assignedStaffId':   uid,
          'assignedStaffName': myName,
          'acceptedAt':        FieldValue.serverTimestamp(),
        });
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Flexible(child: Text('Job accepted!')),
        ]),
        backgroundColor: AppTheme.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (!context.mounted) return;
      final taken = e is StateError && e.message == 'ALREADY_TAKEN';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(taken
            ? 'This job was just accepted by another staff member.'
            : 'Could not accept job. Please try again.'),
        backgroundColor: AppTheme.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }
}

// ══════════════════════════════════════════
// HELPER WIDGETS
// ══════════════════════════════════════════
class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Chip({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(color: AppTheme.offWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppTheme.textMute),
      const SizedBox(width: 4),
      Text(text, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMid, letterSpacing: 0.3)),
    ]),
  );
}

class _WeekStat extends StatelessWidget {
  final String value;
  final String label;
  final Color  color;
  const _WeekStat({required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(children: [
        Text(value, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w900, color: color, height: 1)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
      ]),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color  color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(.2))),
      child: Column(children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.4), textAlign: TextAlign.center),
      ]),
    ),
  );
}
