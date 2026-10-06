import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animations.dart';

class StaffJobsScreen extends StatefulWidget {
  const StaffJobsScreen({super.key});
  @override
  State<StaffJobsScreen> createState() => _StaffJobsScreenState();
}

class _StaffJobsScreenState extends State<StaffJobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _uid   = FirebaseAuth.instance.currentUser?.uid;
  final _email = FirebaseAuth.instance.currentUser?.email?.toLowerCase();

  final _filters = ['All', 'Pending', 'Active', 'Complete', 'Cancelled'];

  // ── Staff's own category — bookings only pool to matching category ──
  String? _myCategory;
  String  _myName = '';
  bool    _categoryLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _filters.length, vsync: this);
    _tabs.addListener(() => setState(() {}));
    _loadMyCategory();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  // Looks up this staff member's category (and display name) — primarily
  // from staff_by_email (where admin writes it), falling back to the
  // staff/{uid} doc for older records.
  Future<void> _loadMyCategory() async {
    try {
      String? cat;
      String  name = '';
      if (_email != null) {
        final byEmail = await FirebaseFirestore.instance
            .collection('staff_by_email').doc(_email).get();
        if (byEmail.exists) {
          final d = byEmail.data() ?? {};
          cat  = d['category'] as String?;
          name = d['name'] as String? ?? '';
        }
      }
      if ((cat == null || cat.isEmpty) && _uid != null) {
        final byUid = await FirebaseFirestore.instance
            .collection('staff').doc(_uid).get();
        if (byUid.exists) {
          final d = byUid.data() ?? {};
          cat ??= d['category'] as String?;
          if (name.isEmpty) name = d['name'] as String? ?? '';
        }
      }
      if (mounted) {
        setState(() {
          _myCategory     = cat;
          _myName         = name.isNotEmpty
              ? name
              : (FirebaseAuth.instance.currentUser?.displayName ?? '');
          _categoryLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _categoryLoaded = true);
    }
  }

  // Bookings already assigned to me (any or specific status)
  Stream<QuerySnapshot> _assignedStream({String? status}) {
    if (_uid == null) return const Stream.empty();
    var q = FirebaseFirestore.instance
        .collection('bookings')
        .where('assignedStaffId', isEqualTo: _uid);
    if (status != null) q = q.where('status', isEqualTo: status);
    return q.orderBy('createdAt', descending: true).snapshots();
  }

  // Open job pool: pending bookings matching my category, not yet claimed
  Stream<QuerySnapshot>? _poolStream() {
    final cat = _myCategory;
    if (cat == null || cat.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('category', isEqualTo: cat)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: AppTheme.navyDark,
            automaticallyImplyLeading: false,
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('MY JOBS', style: GoogleFonts.poppins(
                      fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                    const SizedBox(height: 2),
                    StreamBuilder<QuerySnapshot>(
                      stream: _uid == null ? null : FirebaseFirestore.instance
                          .collection('bookings')
                          .where('assignedStaffId', isEqualTo: _uid)
                          .snapshots(),
                      builder: (_, snap) {
                        final total  = snap.data?.docs.length ?? 0;
                        final active = snap.data?.docs.where((d) => (d.data() as Map)['status'] == 'active').length ?? 0;
                        final catLabel = (_categoryLoaded && (_myCategory ?? '').isNotEmpty)
                            ? '  •  ${_myCategory!} jobs'
                            : '';
                        return Text('$total total  •  $active active$catLabel',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.w300));
                      },
                    ),
                  ]),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppTheme.gold,
              unselectedLabelColor: Colors.white38,
              indicatorColor: AppTheme.gold,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.8),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: _filters.map((f) => Tab(text: f)).toList(),
            ),
          ),
        ],
        body: !_categoryLoaded
            ? const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2))
            : TabBarView(
                controller: _tabs,
                children: _filters.map((f) {
                  switch (f) {
                    case 'All':
                      return _MergedJobList(
                        streamA: _assignedStream(),
                        streamB: _poolStream(),
                        myName: _myName,
                        emptyIcon: Icons.assignment_outlined,
                        emptyLabel: 'No jobs yet',
                        emptySubLabel: (_myCategory ?? '').isEmpty
                            ? 'Ask an admin to set your service category'
                            : 'New ${_myCategory!} bookings will appear here',
                      );
                    case 'Pending':
                      return _MergedJobList(
                        streamA: _assignedStream(status: 'pending'),
                        streamB: _poolStream(),
                        myName: _myName,
                        emptyIcon: Icons.schedule,
                        emptyLabel: 'No pending jobs',
                        emptySubLabel: (_myCategory ?? '').isEmpty
                            ? 'Ask an admin to set your service category'
                            : 'New ${_myCategory!} bookings will appear here',
                      );
                    default:
                      return _JobList(
                        stream: _assignedStream(status: f.toLowerCase()),
                        filter: f,
                        myName: _myName,
                      );
                  }
                }).toList(),
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// JOB LIST — single stream (Active / Complete / Cancelled)
// ══════════════════════════════════════════
class _JobList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final String filter;
  final String myName;
  const _JobList({required this.stream, required this.filter, required this.myName});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(_filterIcon(filter), size: 48, color: AppTheme.textMute),
            const SizedBox(height: 14),
            Text('No $filter jobs',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMute)),
            const SizedBox(height: 6),
            Text('Your jobs will appear here once accepted',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return FadeSlideIn(index: i, child: _StaffJobCard(data: data, docId: docs[i].id, myName: myName));
          },
        );
      },
    );
  }

  IconData _filterIcon(String f) => switch (f) {
    'Pending'   => Icons.schedule,
    'Active'    => Icons.circle,
    'Complete'  => Icons.flag,
    'Cancelled' => Icons.cancel,
    _ => Icons.assignment_outlined,
  };
}

// ══════════════════════════════════════════
// MERGED JOB LIST — combines "assigned to me" + "open pool" streams,
// de-duplicated by doc id, sorted by createdAt desc. No external packages
// needed: nested StreamBuilders let the framework handle resubscription.
// ══════════════════════════════════════════
class _MergedJobList extends StatelessWidget {
  final Stream<QuerySnapshot> streamA;
  final Stream<QuerySnapshot>? streamB;
  final String myName;
  final IconData emptyIcon;
  final String emptyLabel;
  final String emptySubLabel;

  const _MergedJobList({
    required this.streamA,
    required this.streamB,
    required this.myName,
    required this.emptyIcon,
    required this.emptyLabel,
    required this.emptySubLabel,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: streamA,
      builder: (_, snapA) {
        if (streamB == null) {
          return _build(
            context,
            snapA.data?.docs ?? [],
            [],
            waiting: snapA.connectionState == ConnectionState.waiting,
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: streamB,
          builder: (_, snapB) {
            final waiting = snapA.connectionState == ConnectionState.waiting &&
                snapB.connectionState == ConnectionState.waiting;
            return _build(
              context,
              snapA.data?.docs ?? [],
              snapB.data?.docs ?? [],
              waiting: waiting,
            );
          },
        );
      },
    );
  }

  Widget _build(
    BuildContext context,
    List<QueryDocumentSnapshot> a,
    List<QueryDocumentSnapshot> b, {
    required bool waiting,
  }) {
    if (waiting && a.isEmpty && b.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2));
    }

    final seen = <String>{};
    final merged = <QueryDocumentSnapshot>[];
    for (final d in [...a, ...b]) {
      if (seen.add(d.id)) merged.add(d);
    }
    merged.sort((x, y) {
      final tx = (x.data() as Map)['createdAt'] as Timestamp?;
      final ty = (y.data() as Map)['createdAt'] as Timestamp?;
      if (tx == null && ty == null) return 0;
      if (tx == null) return 1;
      if (ty == null) return -1;
      return ty.compareTo(tx);
    });

    if (merged.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(emptyIcon, size: 48, color: AppTheme.textMute),
        const SizedBox(height: 14),
        Text(emptyLabel,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMute)),
        const SizedBox(height: 6),
        Text(emptySubLabel,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: merged.length,
      itemBuilder: (_, i) {
        final data = merged[i].data() as Map<String, dynamic>;
        return FadeSlideIn(index: i, child: _StaffJobCard(data: data, docId: merged[i].id, myName: myName));
      },
    );
  }
}

// ══════════════════════════════════════════
// STAFF JOB CARD
// ══════════════════════════════════════════
class _StaffJobCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final String myName;
  const _StaffJobCard({required this.data, required this.docId, required this.myName});

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Is this job still an unclaimed open-pool job (no one assigned yet)?
  bool get _isOpenPool =>
      data['status'] == 'pending' &&
      (data['assignedStaffId'] as String? ?? '').isEmpty;

  Color get _statusColor => switch (data['status'] as String? ?? '') {
    'active'    => AppTheme.green,
    'complete'  => AppTheme.navy,
    'cancelled' => AppTheme.red,
    _           => AppTheme.goldDark,
  };

  String get _statusLabel => switch (data['status'] as String? ?? '') {
    'active'    => 'Active',
    'complete'  => 'Complete',
    'cancelled' => 'Cancelled',
    _           => _isOpenPool ? 'Available' : 'Pending',
  };

  IconData get _statusIcon => switch (data['status'] as String? ?? '') {
    'active'    => Icons.circle,
    'complete'  => Icons.check_circle,
    'cancelled' => Icons.cancel,
    _           => Icons.schedule,
  };

  @override
  Widget build(BuildContext context) {
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        // Status bar
        Container(height: 4, decoration: BoxDecoration(
          color: _statusColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(18)))),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── TOP ROW ──
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: _statusColor.withOpacity(.08), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(data['icon'] ?? '📋', style: const TextStyle(fontSize: 26))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data['service'] ?? 'Service',
                  style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 0.3)),
                const SizedBox(height: 3),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_statusIcon, size: 11, color: _statusColor),
                  const SizedBox(width: 4),
                  Text(_statusLabel, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: _statusColor, letterSpacing: 0.4)),
                ]),
              ])),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppTheme.textMute, size: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) => _handleAction(context, val),
                itemBuilder: (_) => [
                  if (data['status'] == 'pending') ...[
                    _item('accept', Icons.check_circle_outline, 'Accept Job', color: AppTheme.green),
                    if (!_isOpenPool)
                      _item('decline', Icons.cancel_outlined, 'Decline Job', color: AppTheme.red),
                  ],
                  if (data['status'] == 'active')
                    _item('complete', Icons.flag_outlined,         'Mark Complete', color: AppTheme.navy),
                  _item('call',    Icons.phone_outlined,         'Call Client'),
                  _item('whatsapp',Icons.chat_outlined,          'WhatsApp Client'),
                ],
              ),
            ]),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── CLIENT INFO ──
            _Row(icon: Icons.person_outline, label: 'Client', value: data['clientName'] ?? '—'),
            const SizedBox(height: 8),

            // ── DATE & TIME ──
            Row(children: [
              Expanded(child: _Row(icon: Icons.calendar_today_outlined, label: 'Date', value: data['date'] ?? 'TBD')),
              Expanded(child: _Row(icon: Icons.access_time_outlined,    label: 'Time', value: data['time'] ?? 'TBD')),
            ]),
            const SizedBox(height: 8),

            // ── DURATION & PAYMENT ──
            Row(children: [
              Expanded(child: _Row(icon: Icons.schedule_outlined, label: 'Duration',
                value: '${data['hours'] ?? 0}h')),
              Expanded(child: _Row(icon: Icons.payment_outlined, label: 'Payment',
                value: _payLabel(data['payMethod']))),
            ]),

            // ── ADDRESS ──
            if ((data['address'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              _Row(icon: Icons.location_on_outlined, label: 'Address', value: data['address']),
            ],

            // ── NOTES ──
            if ((data['notes'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              _Row(icon: Icons.notes_outlined, label: 'Notes', value: data['notes'], multiline: true),
            ],

            // ── BOOKED AT ──
            if (createdAt != null) ...[
              const SizedBox(height: 10),
              Text('Booked ${DateFormat('d MMM yyyy, HH:mm').format(createdAt)}',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
            ],

            // ── ACTION BUTTONS ──
            if (data['status'] == 'pending') ...[
              const SizedBox(height: 14),
              Row(children: [
                if (!_isOpenPool) ...[
                  Expanded(child: OutlinedButton(
                    onPressed: () => _handleAction(context, 'decline'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.red,
                      side: const BorderSide(color: AppTheme.red), shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 11)),
                    child: Text('Decline', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800)),
                  )),
                  const SizedBox(width: 10),
                ],
                Expanded(child: ElevatedButton(
                  onPressed: () => _handleAction(context, 'accept'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green,
                    foregroundColor: Colors.white, shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 11), elevation: 0),
                  child: Text('Accept', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800)),
                )),
              ]),
            ],

            if (data['status'] == 'active') ...[
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _callClient(),
                  icon: const Icon(Icons.phone_outlined, size: 16),
                  label: Text('Call', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.navy,
                    side: const BorderSide(color: AppTheme.border), shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 11)),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _handleAction(context, 'complete'),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text('Complete', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy,
                    foregroundColor: Colors.white, shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 11), elevation: 0),
                )),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    switch (action) {
      case 'accept':
        await _acceptJob(context);
        break;
      case 'decline':
        await _updateStatus(context, 'cancelled');
        break;
      case 'complete':
        await _showCompleteDialog(context);
        break;
      case 'call':
        _callClient();
        break;
      case 'whatsapp':
        _whatsAppClient();
        break;
    }
  }

  // Accept a job — uses a transaction so two staff in the same category
  // can't both claim the same open-pool booking at once.
  Future<void> _acceptJob(BuildContext context) async {
    final uid = _myUid;
    if (uid.isEmpty) return;
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
          'status':             'active',
          'assignedStaffId':    uid,
          'assignedStaffName':  myName,
          'acceptedAt':         FieldValue.serverTimestamp(),
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

  Future<void> _updateStatus(BuildContext context, String status) async {
    await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
      'status': status,
      if (status == 'active')   'acceptedAt':  FieldValue.serverTimestamp(),
      if (status == 'complete') 'completedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(status == 'active' ? Icons.check_circle : status == 'complete' ? Icons.flag : Icons.cancel,
          color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(status == 'active' ? 'Job accepted!' : status == 'complete' ? 'Job completed!' : 'Job declined.')),
      ]),
      backgroundColor: status == 'active' ? AppTheme.green : status == 'complete' ? AppTheme.navy : AppTheme.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _showCompleteDialog(BuildContext context) async {
    final notesCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Complete Job', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.navy)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Add any completion notes before marking this job as done.',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMute)),
          const SizedBox(height: 14),
          TextField(
            controller: notesCtrl, maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Notes, observations, issues...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMute, fontWeight: FontWeight.w300),
              filled: true, fillColor: AppTheme.offWhite,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMute)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
                'status':          'complete',
                'completedAt':     FieldValue.serverTimestamp(),
                'completionNotes': notesCtrl.text.trim(),
              });
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.flag, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Flexible(child: Text('Job marked as complete!')),
                ]),
                backgroundColor: AppTheme.navy, behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy, shape: const StadiumBorder(), elevation: 0),
            child: Text('Mark Complete', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _callClient() async {
    final phone = data['clientPhone'] ?? '';
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsAppClient() async {
    final phone = (data['clientPhone'] ?? '').toString().replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isEmpty) return;
    final msg = Uri.encodeComponent('Hello, I am your TEHCS carer assigned for ${data['service']} on ${data['date']}.');
    final uri = Uri.parse('https://wa.me/$phone?text=$msg');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _payLabel(dynamic m) => switch (m?.toString() ?? '') {
    'pay_later'  => 'Invoice',
    'bank'       => 'Bank Transfer',
    'card'       => 'Card',
    'apple_pay'  => 'Apple Pay',
    'google_pay' => 'Google Pay',
    _ => 'TBD',
  };

  PopupMenuItem<String> _item(String val, IconData icon, String label, {Color? color}) =>
    PopupMenuItem(value: val,
      child: Row(children: [
        Icon(icon, size: 18, color: color ?? AppTheme.textMid),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.inter(fontSize: 14, color: color ?? AppTheme.navyDark, fontWeight: FontWeight.w500)),
      ]),
    );
}

// ══════════════════════════════════════════
// HELPER ROW
// ══════════════════════════════════════════
class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool multiline;
  const _Row({required this.icon, required this.label, required this.value, this.multiline = false});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: AppTheme.textMute),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textMute, letterSpacing: 0.8)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.navyDark, fontWeight: FontWeight.w500),
          maxLines: multiline ? 3 : 1, overflow: TextOverflow.ellipsis),
      ])),
    ],
  );
}
