import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/booking.dart';
import '../services/session_control.dart';
import 'admin_messages_screen.dart';
import 'auth/login_screen.dart';
import '../widgets/animations.dart';

class AdminPanel extends StatefulWidget {
  final String mode;
  const AdminPanel({super.key, this.mode = 'staff'});
  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabs;
  DateTime? _pausedAt;

  static const _adminEmail = 'twitchempireinfo@gmail.com';
  bool get _isAdmin => FirebaseAuth.instance.currentUser?.email == _adminEmail;

  List<Tab> get _tabList => [
        const Tab(
            icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Overview'),
        const Tab(
            icon: Icon(Icons.calendar_today_outlined, size: 18),
            text: 'Bookings'),
        const Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Users'),
        const Tab(
            icon: Icon(Icons.chat_bubble_outline, size: 18), text: 'Support'),
        if (_isAdmin)
          const Tab(
              icon: Icon(Icons.attach_money_outlined, size: 18),
              text: 'Finance'),
        if (_isAdmin)
          const Tab(icon: Icon(Icons.badge_outlined, size: 18), text: 'Staff'),
        if (_isAdmin)
          const Tab(
              icon: Icon(Icons.category_outlined, size: 18),
              text: 'Categories'),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs = TabController(length: _isAdmin ? 7 : 4, vsync: this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabs.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final p = _pausedAt;
      _pausedAt = null;
      if (p != null && DateTime.now().difference(p) >= kAutoSignOutThreshold) {
        performForceSignOut(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (d) {
        if (!d) handleGuardedBackPress(context);
      },
      child: Scaffold(
        backgroundColor: AppTheme.offWhite,
        appBar: AppBar(
          backgroundColor: AppTheme.navyDark,
          automaticallyImplyLeading: false,
          title: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/tehcs.jpg',
                width: 30,
                height: 30,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        color: AppTheme.gold,
                        borderRadius: BorderRadius.circular(8)),
                    child: Center(
                        child: Text('T',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.navyDark)))),
              ),
            ),
            const SizedBox(width: 10),
            Text(_isAdmin ? 'ADMIN PORTAL' : 'STAFF VIEW',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2)),
            const Spacer(),
            Icon(Icons.circle,
                size: 8, color: _isAdmin ? AppTheme.red : AppTheme.gold),
            const SizedBox(width: 4),
            Text(_isAdmin ? 'Admin' : 'Staff',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white54,
                    letterSpacing: 0.5)),
          ]),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded,
                  color: Colors.white70, size: 20),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false);
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppTheme.gold,
            labelColor: AppTheme.gold,
            unselectedLabelColor: Colors.white38,
            labelStyle: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6),
            unselectedLabelStyle:
                GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
            tabs: _tabList,
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _OverviewTab(isAdmin: _isAdmin),
            _BookingsTab(isAdmin: _isAdmin),
            _UsersTab(isAdmin: _isAdmin),
            const AdminMessagesScreen(),
            if (_isAdmin) _FinanceTab(),
            if (_isAdmin) _StaffTab(),
            if (_isAdmin) _CategoriesTab(),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// 1. OVERVIEW TAB
// ══════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final bool isAdmin;
  const _OverviewTab({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Live stats
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
          builder: (_, bSnap) => StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('clients').snapshots(),
            builder: (_, cSnap) => StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('staff').snapshots(),
              builder: (_, sSnap) {
                final bookings = bSnap.data?.docs ?? [];
                final clients = cSnap.data?.docs.length ?? 0;
                final staff = sSnap.data?.docs.length ?? 0;
                final pending = bookings
                    .where((d) => (d.data() as Map)['status'] == 'pending')
                    .length;
                final active = bookings
                    .where((d) => (d.data() as Map)['status'] == 'active')
                    .length;
                final complete = bookings
                    .where((d) => (d.data() as Map)['status'] == 'complete')
                    .length;
                return Column(children: [
                  Row(children: [
                    _StatCard(
                        value: '${bookings.length}',
                        label: 'Total Bookings',
                        icon: Icons.calendar_today_outlined,
                        color: AppTheme.navy),
                    const SizedBox(width: 10),
                    _StatCard(
                        value: '$clients',
                        label: 'Customers',
                        icon: Icons.people_outline,
                        color: AppTheme.goldDark),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _StatCard(
                        value: '$staff',
                        label: 'Staff Members',
                        icon: Icons.badge_outlined,
                        color: const Color(0xFF6B21A8)),
                    const SizedBox(width: 10),
                    _StatCard(
                        value: '$active',
                        label: 'Active Jobs',
                        icon: Icons.work_outline,
                        color: AppTheme.green),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _StatCard(
                        value: '$pending',
                        label: 'Pending',
                        icon: Icons.pending_outlined,
                        color: AppTheme.goldDark),
                    const SizedBox(width: 10),
                    _StatCard(
                        value: '$complete',
                        label: 'Completed',
                        icon: Icons.check_circle_outline,
                        color: AppTheme.navy),
                  ]),
                ]);
              },
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Recent bookings
        _sectionHeader('RECENT BOOKINGS'),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (_, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return _emptyState('No bookings yet');
            return Column(
                children: docs.map((d) {
              final b = Booking.fromFirestore(d);
              return _BookingRow(booking: b, docId: d.id, isAdmin: isAdmin);
            }).toList());
          },
        ),
        const SizedBox(height: 20),

        // Staff on duty
        _sectionHeader('STAFF ON DUTY'),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('staff')
              .where('clockedIn', isEqualTo: true)
              .snapshots(),
          builder: (_, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty)
              return _emptyState('No staff currently clocked in');
            return Column(
                children: docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              return _StaffOnDutyRow(data: data);
            }).toList());
          },
        ),
        const SizedBox(height: 20),

        // Quote requests
        _sectionHeader('QUOTE REQUESTS'),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('quote_requests')
              .where('status', isEqualTo: 'pending')
              .orderBy('createdAt', descending: true)
              .limit(3)
              .snapshots(),
          builder: (_, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return _emptyState('No pending quote requests');
            return Column(
                children: docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              return _QuoteRow(data: data, docId: d.id);
            }).toList());
          },
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// 2. BOOKINGS TAB
// ══════════════════════════════════════════
class _BookingsTab extends StatefulWidget {
  final bool isAdmin;
  const _BookingsTab({required this.isAdmin});
  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> {
  String _filter = 'all';
  final _filters = ['all', 'pending', 'active', 'complete', 'cancelled'];

  Stream<QuerySnapshot> get _stream {
    var q = FirebaseFirestore.instance
        .collection('bookings')
        .orderBy('createdAt', descending: true);
    if (_filter != 'all') q = q.where('status', isEqualTo: _filter);
    return q.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Filter chips
      Container(
        color: AppTheme.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              children: _filters
                  .map((f) => GestureDetector(
                        onTap: () => setState(() => _filter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: _filter == f
                                ? AppTheme.navy
                                : AppTheme.offWhite,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                                color: _filter == f
                                    ? AppTheme.navy
                                    : AppTheme.border),
                          ),
                          child: Text(f[0].toUpperCase() + f.substring(1),
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _filter == f
                                      ? Colors.white
                                      : AppTheme.textMid,
                                  letterSpacing: 0.5)),
                        ),
                      ))
                  .toList()),
        ),
      ),
      Expanded(
          child: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.navy, strokeWidth: 2));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty)
            return _emptyState(
                'No ${_filter == 'all' ? '' : '$_filter '}bookings');
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final b = Booking.fromFirestore(docs[i]);
              return _BookingRow(
                  booking: b,
                  docId: docs[i].id,
                  isAdmin: widget.isAdmin,
                  expanded: true);
            },
          );
        },
      )),
    ]);
  }
}

// ══════════════════════════════════════════
// 3. USERS TAB
// ══════════════════════════════════════════
class _UsersTab extends StatefulWidget {
  final bool isAdmin;
  const _UsersTab({required this.isAdmin});
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: AppTheme.navyDark,
        child: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.gold,
          labelColor: AppTheme.gold,
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6),
          tabs: const [Tab(text: 'CUSTOMERS'), Tab(text: 'STAFF')],
        ),
      ),
      Expanded(
          child: TabBarView(
        controller: _tabs,
        children: [
          _UserList(collection: 'clients', emptyLabel: 'No customers yet'),
          _UserList(collection: 'staff', emptyLabel: 'No staff yet'),
        ],
      )),
    ]);
  }
}

class _UserList extends StatelessWidget {
  final String collection;
  final String emptyLabel;
  const _UserList({required this.collection, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.navy, strokeWidth: 2));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _emptyState(emptyLabel);
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final name = d['name'] ?? 'Unknown';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(.03), blurRadius: 6)
                  ]),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.navy,
                          child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(name,
                                style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.navy,
                                    letterSpacing: 0.3)),
                            Text(d['email'] ?? '',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppTheme.textMute,
                                    fontWeight: FontWeight.w300)),
                          ])),
                      if (collection == 'staff') ...[
                        _DbsBadge(status: d['dbsStatus'] ?? 'Pending'),
                      ],
                    ]),
                    if ((d['phone'] ?? '').isNotEmpty ||
                        (d['staffRole'] ?? '').isNotEmpty ||
                        (d['category'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(children: [
                        if ((d['phone'] ?? '').isNotEmpty) ...[
                          const Icon(Icons.phone_outlined,
                              size: 13, color: AppTheme.textMute),
                          const SizedBox(width: 4),
                          Text(d['phone'],
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppTheme.textMid)),
                          const SizedBox(width: 16),
                        ],
                        if ((d['staffRole'] ?? '').isNotEmpty) ...[
                          const Icon(Icons.work_outline,
                              size: 13, color: AppTheme.textMute),
                          const SizedBox(width: 4),
                          Text(d['staffRole'],
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppTheme.textMid)),
                        ],
                        if ((d['category'] ?? '').isNotEmpty) ...[
                          const SizedBox(width: 16),
                          const Icon(Icons.category_outlined,
                              size: 13, color: AppTheme.textMute),
                          const SizedBox(width: 4),
                          Text(d['category'],
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.goldDark,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ]),
                    ],
                    if (collection == 'staff') ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        _ActionBtn(
                            label: 'Verify DBS',
                            color: AppTheme.green,
                            onTap: () async {
                              await FirebaseFirestore.instance
                                  .collection('staff')
                                  .doc(docs[i].id)
                                  .update({'dbsStatus': 'Verified'});
                            }),
                        const SizedBox(width: 8),
                        _ActionBtn(
                            label: 'Assign Job',
                            color: AppTheme.navy,
                            onTap: () {}),
                      ]),
                    ],
                  ]),
            );
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════
// 5. FINANCE TAB (admin only)
// ══════════════════════════════════════════
class _FinanceTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('status', isEqualTo: 'complete')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        final payLater = docs
            .where((d) => (d.data() as Map)['payMethod'] == 'pay_later')
            .length;
        final paid = docs.length - payLater;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Summary cards
            Row(children: [
              _StatCard(
                  value: '${docs.length}',
                  label: 'Jobs Complete',
                  icon: Icons.check_circle_outline,
                  color: AppTheme.green),
              const SizedBox(width: 10),
              _StatCard(
                  value: '$payLater',
                  label: 'Invoices Pending',
                  icon: Icons.receipt_outlined,
                  color: AppTheme.goldDark),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _StatCard(
                  value: '$paid',
                  label: 'Paid Jobs',
                  icon: Icons.payments_outlined,
                  color: AppTheme.navy),
              const SizedBox(width: 10),
              _StatCard(
                  value: '—',
                  label: 'Revenue (Stripe)',
                  icon: Icons.trending_up_outlined,
                  color: const Color(0xFF6B21A8)),
            ]),
            const SizedBox(height: 20),

            _sectionHeader('PAYMENT BREAKDOWN'),
            const SizedBox(height: 10),
            ...['pay_later', 'card', 'bank', 'apple_pay', 'google_pay']
                .map((method) {
              final count = docs
                  .where((d) => (d.data() as Map)['payMethod'] == method)
                  .length;
              final label = switch (method) {
                'pay_later' => 'Invoice / Pay Later',
                'card' => 'Debit / Credit Card',
                'bank' => 'Bank Transfer',
                'apple_pay' => 'Apple Pay',
                'google_pay' => 'Google Pay',
                _ => method,
              };
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border)),
                child: Row(children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.navyDark,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('$count job${count != 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navy)),
                ]),
              );
            }),
            const SizedBox(height: 20),

            _sectionHeader('RECENT COMPLETED JOBS'),
            const SizedBox(height: 10),
            ...docs.take(10).map((d) {
              final data = d.data() as Map<String, dynamic>;
              final ts = (data['createdAt'] as Timestamp?)?.toDate();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border)),
                child: Row(children: [
                  Text(data['icon'] ?? '📋',
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(data['service'] ?? '',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.navy,
                                letterSpacing: 0.3)),
                        Text(data['clientName'] ?? '',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textMute,
                                fontWeight: FontWeight.w300)),
                      ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    _PayBadge(method: data['payMethod'] ?? ''),
                    if (ts != null)
                      Text(DateFormat('d MMM').format(ts),
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppTheme.textMute,
                              fontWeight: FontWeight.w300)),
                  ]),
                ]),
              );
            }),
          ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════
// 6. STAFF TAB (admin only)
// ══════════════════════════════════════════
class _StaffTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showAddStaff(context),
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: Text('Add Staff Member',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: const StadiumBorder(),
                elevation: 0),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
          child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('staff')
            .orderBy('addedAt', descending: true)
            .snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.navy, strokeWidth: 2));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty)
            return _emptyState('No staff members yet.\nAdd one above.');
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final name = d['name'] ?? 'Unknown';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(.03), blurRadius: 6)
                    ]),
                child: Row(children: [
                  CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.goldDark,
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(name,
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.navy,
                                letterSpacing: 0.3)),
                        Text(d['email'] ?? '',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textMute,
                                fontWeight: FontWeight.w300)),
                        if ((d['staffRole'] ?? '').isNotEmpty)
                          Text(d['staffRole'],
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.goldDark,
                                  fontWeight: FontWeight.w500)),
                      ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    _DbsBadge(status: d['dbsStatus'] ?? 'Pending'),
                    const SizedBox(height: 6),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      GestureDetector(
                        onTap: () =>
                            _updateDbs(docs[i].id, d['dbsStatus'] ?? 'Pending'),
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: AppTheme.light,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text('DBS',
                                style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.navy))),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () =>
                            _removeStaff(context, docs[i].id, d['email'] ?? ''),
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: AppTheme.red.withOpacity(.08),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text('Remove',
                                style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.red))),
                      ),
                    ]),
                  ]),
                ]),
              );
            },
          );
        },
      )),
    ]);
  }

  Future<void> _updateDbs(String docId, String current) async {
    final next = current == 'Verified' ? 'Expired' : 'Verified';
    await FirebaseFirestore.instance
        .collection('staff')
        .doc(docId)
        .update({'dbsStatus': next});
  }

  Future<void> _removeStaff(
      BuildContext context, String docId, String email) async {
    await FirebaseFirestore.instance.collection('staff').doc(docId).delete();
    if (email.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('staff_by_email')
          .doc(email.toLowerCase())
          .delete();
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Staff member removed.'),
      backgroundColor: AppTheme.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showAddStaff(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String role = 'Carer';
    String category = 'Non-Medical';
    final roles = [
      'Carer',
      'Cleaner',
      'Cook / Chef',
      'Driver',
      'Nurse',
      'Plumber',
      'Electrician',
      'Builder',
      'Other'
    ];
    final categories = ['Cleaning', 'Home Care', 'Non-Medical', 'Construction'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Keeps sheet above keyboard
      useSafeArea: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          // Read inset from the sheet's own context so it updates as keyboard appears
          final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;
          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: EdgeInsets.fromLTRB(22, 22, 22, 22 + keyboardHeight),
            // SingleChildScrollView ensures fields don't hide on small screens
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                                color: AppTheme.border,
                                borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 18),
                    Text('ADD STAFF MEMBER',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.navy,
                            letterSpacing: 1)),
                    const SizedBox(height: 16),
                    _inputField('Full Name', nameCtrl, Icons.person_outline),
                    const SizedBox(height: 12),
                    _inputField(
                        'Email Address', emailCtrl, Icons.email_outlined,
                        type: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    Text('JOB ROLE',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMute,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppTheme.offWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: role,
                          isExpanded: true,
                          dropdownColor: AppTheme.white,
                          style: GoogleFonts.inter(
                              fontSize: 14, color: AppTheme.navyDark),
                          items: roles
                              .map((r) =>
                                  DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (v) => setS(() => role = v!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('SERVICE CATEGORY',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMute,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppTheme.offWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: category,
                          isExpanded: true,
                          dropdownColor: AppTheme.white,
                          style: GoogleFonts.inter(
                              fontSize: 14, color: AppTheme.navyDark),
                          items: categories
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setS(() => category = v!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Staff only receive bookings that match this category.',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textMute,
                            fontWeight: FontWeight.w300)),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty)
                            return;
                          final email = emailCtrl.text.trim().toLowerCase();
                          await FirebaseFirestore.instance
                              .collection('staff_by_email')
                              .doc(email)
                              .set({
                            'name': nameCtrl.text.trim(),
                            'email': email,
                            'role': 'staff',
                            'staffRole': role,
                            'category': category,
                            'dbsStatus': 'Pending',
                            'available': true,
                            'addedAt': FieldValue.serverTimestamp(),
                          });
                          await FirebaseFirestore.instance
                              .collection('staff')
                              .add({
                            'name': nameCtrl.text.trim(),
                            'email': email,
                            'role': 'staff',
                            'staffRole': role,
                            'category': category,
                            'dbsStatus': 'Pending',
                            'available': true,
                            'addedAt': FieldValue.serverTimestamp(),
                          });
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content:
                                Text('${nameCtrl.text.trim()} added as staff.'),
                            backgroundColor: AppTheme.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ));
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const StadiumBorder(),
                            elevation: 0),
                        child: Text('Add Staff Member',
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8)),
                      ),
                    ),
                  ]),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════
// 7. CATEGORIES TAB (admin only)
// ══════════════════════════════════════════
class _CategoriesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showAddCategory(context),
            icon: const Icon(Icons.add, size: 18),
            label: Text('Add Category / Service',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.navyDark,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: const StadiumBorder(),
                elevation: 0),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
          child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categories')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.navy, strokeWidth: 2));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _emptyState(
                'No custom categories yet.\nDefault services are built into the app.');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border)),
                child: Row(children: [
                  Text(d['icon'] ?? '📋', style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(d['name'] ?? '',
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.navy,
                                letterSpacing: 0.3)),
                        Text(d['division'] ?? '',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.goldDark,
                                fontWeight: FontWeight.w500)),
                        if ((d['desc'] ?? '').isNotEmpty)
                          Text(d['desc'],
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textMute,
                                  fontWeight: FontWeight.w300),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                      ])),
                  GestureDetector(
                    onTap: () async => await FirebaseFirestore.instance
                        .collection('categories')
                        .doc(docs[i].id)
                        .delete(),
                    child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: AppTheme.red.withOpacity(.08),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.delete_outline,
                            color: AppTheme.red, size: 18)),
                  ),
                ]),
              );
            },
          );
        },
      )),
    ]);
  }

  void _showAddCategory(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final iconCtrl = TextEditingController(text: '📋');
    String division = 'Cleaning';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;
          return Container(
            decoration: const BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
            padding: EdgeInsets.fromLTRB(22, 22, 22, 22 + keyboardHeight),
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                                color: AppTheme.border,
                                borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 18),
                    Text('ADD CATEGORY',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.navy,
                            letterSpacing: 1)),
                    const SizedBox(height: 16),
                    Row(children: [
                      SizedBox(
                          width: 70,
                          child: _inputField(
                              'Icon', iconCtrl, Icons.emoji_emotions_outlined)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _inputField(
                              'Service Name', nameCtrl, Icons.label_outline)),
                    ]),
                    const SizedBox(height: 12),
                    _inputField(
                        'Description', descCtrl, Icons.description_outlined),
                    const SizedBox(height: 12),
                    Text('DIVISION',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMute,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppTheme.offWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: division,
                          isExpanded: true,
                          dropdownColor: AppTheme.white,
                          style: GoogleFonts.inter(
                              fontSize: 14, color: AppTheme.navyDark),
                          items: ['Cleaning', 'Home Care', 'Construction']
                              .map((d) =>
                                  DropdownMenuItem(value: d, child: Text(d)))
                              .toList(),
                          onChanged: (v) => setS(() => division = v!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.isEmpty) return;
                          await FirebaseFirestore.instance
                              .collection('categories')
                              .add({
                            'name': nameCtrl.text.trim(),
                            'desc': descCtrl.text.trim(),
                            'icon': iconCtrl.text.trim(),
                            'division': division,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.gold,
                            foregroundColor: AppTheme.navyDark,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const StadiumBorder(),
                            elevation: 0),
                        child: Text('Add Category',
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8)),
                      ),
                    ),
                  ]),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════
// SHARED HELPERS
// ══════════════════════════════════════════
Widget _sectionHeader(String t) => Text(t,
    style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppTheme.navy,
        letterSpacing: 1.5));

Widget _emptyState(String msg) => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.inbox_outlined, size: 48, color: AppTheme.textMute),
          const SizedBox(height: 12),
          Text(msg,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textMute,
                  fontWeight: FontWeight.w300)),
        ]),
      ),
    );

Widget _inputField(String label, TextEditingController ctrl, IconData icon,
        {TextInputType type = TextInputType.text}) =>
    TextField(
      controller: ctrl,
      keyboardType: type,
      style: GoogleFonts.inter(fontSize: 14, color: AppTheme.navyDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMute,
            letterSpacing: 0.8),
        prefixIcon: Icon(icon, size: 18, color: AppTheme.textMute),
        filled: true,
        fillColor: AppTheme.offWhite,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.navy, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      ),
    );

// ── Booking Row ──
class _BookingRow extends StatelessWidget {
  final Booking booking;
  final String docId;
  final bool isAdmin;
  final bool expanded;
  const _BookingRow(
      {required this.booking,
      required this.docId,
      required this.isAdmin,
      this.expanded = false});

  Color get _statusColor => switch (booking.status) {
        'active' => AppTheme.green,
        'complete' => AppTheme.navy,
        'cancelled' => AppTheme.red,
        _ => AppTheme.goldDark,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 6)
          ]),
      child: ExpansionTile(
        leading: Text(booking.icon, style: const TextStyle(fontSize: 24)),
        title: Text(booking.service,
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppTheme.navy,
                letterSpacing: 0.3)),
        subtitle: Text('${booking.clientName}  •  ${booking.date}',
            style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textMute,
                fontWeight: FontWeight.w300)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: _statusColor.withOpacity(.1),
              borderRadius: BorderRadius.circular(100)),
          child: Text(booking.status.toUpperCase(),
              style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: _statusColor,
                  letterSpacing: 0.5)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Divider(height: 1),
              const SizedBox(height: 10),
              _row(Icons.person_outline, 'Client', booking.clientName),
              _row(Icons.email_outlined, 'Email', booking.clientEmail),
              _row(Icons.phone_outlined, 'Phone',
                  booking.phone.isNotEmpty ? booking.phone : '—'),
              _row(Icons.access_time_outlined, 'Time',
                  '${booking.date}  •  ${booking.time}'),
              _row(Icons.schedule_outlined, 'Duration', '${booking.hours}h'),
              _row(Icons.location_on_outlined, 'Address',
                  booking.address.isNotEmpty ? booking.address : '—'),
              if (booking.notes.isNotEmpty)
                _row(Icons.notes_outlined, 'Notes', booking.notes),
              const SizedBox(height: 10),

              // Assign staff
              if (isAdmin) ...[
                _row(Icons.badge_outlined, 'Pay Method',
                    booking.payMethod.isNotEmpty ? booking.payMethod : '—'),
                const SizedBox(height: 10),
              ],

              // Status actions
              Row(children: [
                _ActionBtn(
                    label: 'Pending',
                    color: AppTheme.goldDark,
                    onTap: () => _setStatus('pending')),
                const SizedBox(width: 6),
                _ActionBtn(
                    label: 'Active',
                    color: AppTheme.green,
                    onTap: () => _setStatus('active')),
                const SizedBox(width: 6),
                _ActionBtn(
                    label: 'Complete',
                    color: AppTheme.navy,
                    onTap: () => _setStatus('complete')),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _setStatus(String status) async => FirebaseFirestore.instance
      .collection('bookings')
      .doc(docId)
      .update({'status': status});

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 14, color: AppTheme.textMute),
          const SizedBox(width: 8),
          Text('$label: ',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMid,
                  letterSpacing: 0.3)),
          Expanded(
              child: Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.navyDark,
                      fontWeight: FontWeight.w400))),
        ]),
      );
}

// ── Staff on duty row ──
class _StaffOnDutyRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _StaffOnDutyRow({required this.data});
  @override
  Widget build(BuildContext context) {
    final clockIn = (data['clockInTime'] as Timestamp?)?.toDate();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: AppTheme.green.withOpacity(.12), shape: BoxShape.circle),
            child: Center(
                child: Text(data['name']?.toString()[0].toUpperCase() ?? '?',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.green)))),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data['name'] ?? '',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                  letterSpacing: 0.3)),
          Text(data['staffRole'] ?? 'Staff',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textMute,
                  fontWeight: FontWeight.w300)),
        ])),
        if (clockIn != null)
          Text('Since ${DateFormat('HH:mm').format(clockIn)}',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.green,
                  letterSpacing: 0.3)),
      ]),
    );
  }
}

// ── Quote row ──
class _QuoteRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  const _QuoteRow({required this.data, required this.docId});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.request_quote_outlined,
                size: 22, color: AppTheme.navy),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(data['clientName'] ?? 'Unknown',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navy)),
                  Text(data['clientEmail'] ?? '',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textMute,
                          fontWeight: FontWeight.w300)),
                ])),
            GestureDetector(
              onTap: () => FirebaseFirestore.instance
                  .collection('quote_requests')
                  .doc(docId)
                  .update({'status': 'reviewed'}),
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: AppTheme.navy,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('Mark Reviewed',
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white))),
            ),
          ]),
          const SizedBox(height: 8),
          Text(data['description'] ?? '',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textMid,
                  fontWeight: FontWeight.w300,
                  height: 1.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ]),
      );
}

// ── Stat card ──
class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 6)
              ]),
          child: Row(children: [
            Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: color.withOpacity(.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CountUp(
                  value: int.tryParse(value) ?? 0,
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1)),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppTheme.textMute,
                      fontWeight: FontWeight.w300)),
            ]),
          ]),
        ),
      );
}

// ── DBS Badge ──
class _DbsBadge extends StatelessWidget {
  final String status;
  const _DbsBadge({required this.status});
  Color get _color => switch (status) {
        'Verified' => AppTheme.green,
        'Expired' => AppTheme.red,
        _ => AppTheme.goldDark
      };
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: _color.withOpacity(.1),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: _color.withOpacity(.3))),
        child: Text('DBS: $status',
            style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: _color,
                letterSpacing: 0.5)),
      );
}

// ── Action Button ──
class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(.25))),
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.5)),
        ),
      );
}

// ── Pay Badge ──
class _PayBadge extends StatelessWidget {
  final String method;
  const _PayBadge({required this.method});
  String get _label => switch (method) {
        'pay_later' => 'Invoice',
        'card' => 'Card',
        'bank' => 'Bank',
        'apple_pay' => 'Apple Pay',
        'google_pay' => 'Google Pay',
        _ => 'TBD',
      };
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: AppTheme.navy.withOpacity(.08),
            borderRadius: BorderRadius.circular(6)),
        child: Text(_label,
            style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
                letterSpacing: 0.4)),
      );
}
