import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../theme/dash_theme.dart';
import '../widgets/dashboard_widgets.dart';
import '../models/booking.dart';
import '../services/session_control.dart';
import 'admin_messages_screen.dart';
import 'auth/login_screen.dart';
import '../widgets/animations.dart';
import '../widgets/admin_notification_bell.dart';
import '../services/push_service.dart';
import '../services/booking_export.dart';

class AdminPanel extends StatefulWidget {
  final String mode;
  const AdminPanel({super.key, this.mode = 'staff'});
  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> with WidgetsBindingObserver {
  DateTime? _pausedAt;

  /// Which page is showing (see [_pages]); visited pages stay alive.
  int _page = 0;
  final Set<int> _visited = {0};

  /// Staff only see bookings for the service they are registered to.
  String? _staffCategory;

  /// How many portal screens are open (tells the theme it's a staff session).
  static int _open = 0;

  static const _adminEmail = 'twitchempireinfo@gmail.com';
  bool get _isAdmin => FirebaseAuth.instance.currentUser?.email == _adminEmail;

  // Page indexes
  static const _home = 0, _bookings = 1, _support = 2, _users = 3;
  static const _finance = 4, _staff = 5, _categories = 6;

  static const _pageTitles = {
    _bookings: ('MANAGE', 'Bookings'),
    _support: ('INBOX', 'Support Chats'),
    _users: ('PEOPLE', 'Users'),
    _finance: ('MONEY', 'Finance'),
    _staff: ('TEAM', 'Staff'),
    _categories: ('SERVICES', 'Categories'),
  };

  List<DashNavItem> get _navItems => [
        const DashNavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
        const DashNavItem(Icons.calendar_month_outlined,
            Icons.calendar_month_rounded, 'Bookings'),
        const DashNavItem(Icons.chat_bubble_outline_rounded,
            Icons.chat_bubble_rounded, 'Chats'),
        const DashNavItem(
            Icons.people_outline_rounded, Icons.people_rounded, 'Users'),
        if (_isAdmin)
          const DashNavItem(
              Icons.grid_view_outlined, Icons.grid_view_rounded, 'More'),
      ];

  /// Bottom-bar slot for the current page (Finance/Staff/Categories → More).
  int get _navIndex => _page >= _finance ? 4 : _page;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open++;
    _syncSession();
    PushService.init(); // phone push notifications
    if (!_isAdmin) _loadStaffCategory();
  }

  /// Night mode only applies while a portal screen is open. Updated after
  /// the frame, because the app root rebuilds when it changes.
  static void _syncSession() {
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ThemeController.staffSession.value = _open > 0);
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _loadStaffCategory() async {
    final user = FirebaseAuth.instance.currentUser;
    String cat = '';
    try {
      final email = user?.email?.toLowerCase();
      if (email != null) {
        final d = await FirebaseFirestore.instance
            .collection('staff_by_email')
            .doc(email)
            .get();
        cat = (d.data()?['category'] as String?) ?? '';
      }
      if (cat.isEmpty && user != null) {
        final d = await FirebaseFirestore.instance
            .collection('staff')
            .doc(user.uid)
            .get();
        cat = (d.data()?['category'] as String?) ?? '';
      }
    } catch (_) {}
    if (mounted) setState(() => _staffCategory = cat);
  }

  /// null = admin (everything); '' = staff with no service assigned.
  String? get _scope => _isAdmin ? null : (_staffCategory ?? '');

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _open--;
    _syncSession();
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

  void _go(int page) => setState(() {
        _page = page;
        _visited.add(page);
      });

  void _onNav(int i) {
    if (_isAdmin && i == 4) {
      _showMore();
    } else {
      _go(i);
    }
  }

  Future<void> _showMore() async {
    final page = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Dash.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: Dash.border,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            for (final (page, icon, label, color) in [
              (
                _finance,
                Icons.payments_rounded,
                'Finance',
                const Color(0xFF5DB043)
              ),
              (_staff, Icons.badge_rounded, 'Staff', const Color(0xFF3D80E8)),
              (
                _categories,
                Icons.category_rounded,
                'Categories',
                const Color(0xFF8B5CF6)
              ),
            ])
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color),
                ),
                title: Text(label,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, color: Dash.text)),
                trailing:
                    Icon(Icons.chevron_right_rounded, color: Dash.textMute),
                onTap: () => Navigator.pop(ctx, page),
              ),
          ]),
        ),
      ),
    );
    if (page != null) _go(page);
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  Widget _pageFor(int i) => switch (i) {
        _home => _OverviewTab(
            isAdmin: _isAdmin, category: _scope, onOpen: (p) => _go(p)),
        _bookings => _BookingsTab(isAdmin: _isAdmin, category: _scope),
        _users => _UsersTab(isAdmin: _isAdmin),
        _support => const AdminMessagesScreen(),
        _finance => _FinanceTab(),
        _staff => _StaffTab(),
        _categories => _CategoriesTab(),
        _ => const SizedBox.shrink(),
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.changes,
      builder: (context, _) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_page != _home) {
            _go(_home);
          } else {
            handleGuardedBackPress(context);
          }
        },
        child: Scaffold(
          backgroundColor: Dash.bg,
          // Rebuild everything with the new colours when day/night changes.
          body: KeyedSubtree(
            key: ValueKey(ThemeController.isDark),
            child: Column(children: [
              _header(),
              Expanded(
                child: IndexedStack(
                  index: _page,
                  children: [
                    for (var i = 0; i <= _categories; i++)
                      _visited.contains(i) && (_isAdmin || i < _finance)
                          ? _pageFor(i)
                          : const SizedBox.shrink(),
                  ],
                ),
              ),
            ]),
          ),
          bottomNavigationBar: DashBottomNav(
            items: _navItems,
            index: _navIndex,
            onTap: _onNav,
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : _isAdmin
            ? 'TEHCS Admin'
            : (user?.email?.split('@').first ?? 'Staff');
    final title = _pageTitles[_page];
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  title?.$1 ??
                      (_isAdmin
                          ? 'WELCOME BACK · ADMIN'
                          : 'WELCOME BACK · STAFF'),
                  style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: Dash.textMute)),
              Text(title?.$2 ?? name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Dash.text)),
            ]),
          ),
          const ThemeToggleButton(),
          if (_isAdmin) const AdminNotificationBell(),
          PopupMenuButton<String>(
            tooltip: 'Account',
            color: Dash.card,
            offset: const Offset(0, 50),
            onSelected: (v) {
              if (v == 'logout') _signOut();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(user?.email ?? '',
                    style:
                        GoogleFonts.inter(fontSize: 12, color: Dash.textMute)),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  const Icon(Icons.logout_rounded,
                      color: AppTheme.red, size: 20),
                  const SizedBox(width: 10),
                  Text('Sign out',
                      style: GoogleFonts.inter(
                          color: AppTheme.red, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.gold,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'T',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navyDark)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// 1. OVERVIEW TAB
// ══════════════════════════════════════════
class _OverviewTab extends StatefulWidget {
  final bool isAdmin;
  final String? category; // null = all services (admin)
  final ValueChanged<int> onOpen; // jump to another page
  const _OverviewTab(
      {required this.isAdmin, this.category, required this.onOpen});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  int _days = 7;

  late final _bookingsStream =
      FirebaseFirestore.instance.collection('bookings').snapshots();
  late final _clientsStream = widget.isAdmin
      ? FirebaseFirestore.instance.collection('clients').snapshots()
      : const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();

  static DateTime _created(Map d) =>
      (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

  String get _periodLabel => switch (_days) {
        7 => 'last week',
        30 => 'last month',
        _ => 'previous 90 days',
      };

  /// (number of bars, days per bar) for the chosen period.
  (int, int) get _buckets => switch (_days) {
        7 => (7, 1),
        30 => (10, 3),
        _ => (13, 7),
      };

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!widget.isAdmin) ...[
          _ServiceBanner(category: category),
          const SizedBox(height: 14),
        ],
        PeriodSelector(
            days: _days, onChanged: (d) => setState(() => _days = d)),
        const SizedBox(height: 16),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _bookingsStream,
          builder: (_, bSnap) =>
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _clientsStream,
            builder: (_, cSnap) {
              if (bSnap.connectionState == ConnectionState.waiting &&
                  !bSnap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.gold, strokeWidth: 2)),
                );
              }
              final bookings = (bSnap.data?.docs ?? [])
                  .map((d) => d.data())
                  .where((d) => _inScope(d, category))
                  .toList();
              final clients =
                  (cSnap.data?.docs ?? []).map((d) => d.data()).toList();
              return _stats(bookings, clients);
            },
          ),
        ),
        const SizedBox(height: 22),

        // Recent bookings
        DashTitle(
          kicker: 'Latest',
          title: 'Recent bookings',
          trailing: TextButton(
            onPressed: () => widget.onOpen(1),
            child: Text('View all',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3D80E8))),
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .orderBy('createdAt', descending: true)
              .limit(category == null ? 5 : 200)
              .snapshots(),
          builder: (_, snap) {
            final docs = (snap.data?.docs ?? [])
                .where((d) => _inScope(d.data() as Map, category))
                .take(5)
                .toList();
            if (docs.isEmpty) return _emptyState('No bookings yet');
            return Column(
                children: docs.map((d) {
              final b = Booking.fromFirestore(d);
              return _BookingRow(
                  booking: b, docId: d.id, isAdmin: widget.isAdmin);
            }).toList());
          },
        ),
        const SizedBox(height: 22),

        // Staff on duty
        const DashTitle(kicker: 'Right now', title: 'Staff on duty'),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('staff')
              .where('clockedIn', isEqualTo: true)
              .snapshots(),
          builder: (_, snap) {
            final docs = (snap.data?.docs ?? [])
                .where((d) => _inScope(d.data() as Map, category))
                .toList();
            if (docs.isEmpty) {
              return _emptyState('No staff currently clocked in');
            }
            return Column(
                children: docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              return _StaffOnDutyRow(data: data);
            }).toList());
          },
        ),
        const SizedBox(height: 22),

        // Quote requests
        const DashTitle(kicker: 'Waiting', title: 'Quote requests'),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('quote_requests')
              .where('status', isEqualTo: 'pending')
              .orderBy('createdAt', descending: true)
              .limit(3)
              .snapshots(),
          builder: (_, snap) {
            final docs = (snap.data?.docs ?? [])
                .where((d) => _inScope(d.data() as Map, category))
                .toList();
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

  Widget _stats(
      List<Map<String, dynamic>> bookings, List<Map<String, dynamic>> clients) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: _days));
    final prevStart = start.subtract(Duration(days: _days));
    bool inCur(Map d) => _created(d).isAfter(start);
    bool inPrev(Map d) {
      final c = _created(d);
      return c.isAfter(prevStart) && !c.isAfter(start);
    }

    int total(String s) => bookings.where((d) => d['status'] == s).length;
    int delta(String s) =>
        bookings.where((d) => d['status'] == s && inCur(d)).length -
        bookings.where((d) => d['status'] == s && inPrev(d)).length;

    // Time buckets for charts
    final (n, per) = _buckets;
    final bucketStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: n * per - 1));
    List<double> series(List<Map<String, dynamic>> docs,
        [double Function(Map d)? weight]) {
      final out = List<double>.filled(n, 0);
      for (final d in docs) {
        final i = _created(d).difference(bucketStart).inDays ~/ per;
        if (i >= 0 && i < n) out[i] += weight?.call(d) ?? 1;
      }
      return out;
    }

    final labels = [
      for (var i = 0; i < n; i++)
        per == 1
            ? DateFormat('E').format(bucketStart.add(Duration(days: i)))
            : DateFormat('d/M')
                .format(bucketStart.add(Duration(days: i * per))),
    ];

    final curBookings = bookings.where(inCur).toList();
    final prevBookings = bookings.where(inPrev).length;
    double hoursOf(Map d) => ((d['hours'] as num?) ?? 0).toDouble();
    final curHours = curBookings.fold<double>(0, (a, d) => a + hoursOf(d));
    final prevHours =
        bookings.where(inPrev).fold<double>(0, (a, d) => a + hoursOf(d));
    final curClients = clients.where(inCur).length;
    final prevClients = clients.where(inPrev).length;

    String fmtHours(double h) =>
        h % 1 == 0 ? '${h.toInt()}h' : '${h.toStringAsFixed(1)}h';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Coloured status tiles ──
      Row(children: [
        Expanded(
          child: GradientStatTile(
            title: 'Active Jobs',
            value: total('active'),
            delta: delta('active'),
            periodLabel: _periodLabel,
            colors: GradientStatTile.green,
            icon: Icons.work_rounded,
            onTap: () => widget.onOpen(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GradientStatTile(
            title: 'Cancelled',
            value: total('cancelled'),
            delta: delta('cancelled'),
            periodLabel: _periodLabel,
            colors: GradientStatTile.red,
            icon: Icons.cancel_rounded,
            onTap: () => widget.onOpen(1),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: GradientStatTile(
            title: 'Pending',
            value: total('pending'),
            delta: delta('pending'),
            periodLabel: _periodLabel,
            colors: GradientStatTile.yellow,
            icon: Icons.hourglass_top_rounded,
            onTap: () => widget.onOpen(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GradientStatTile(
            title: 'Completed',
            value: total('complete'),
            delta: delta('complete'),
            periodLabel: _periodLabel,
            colors: GradientStatTile.blue,
            icon: Icons.task_alt_rounded,
            onTap: () => widget.onOpen(1),
          ),
        ),
      ]),
      const SizedBox(height: 14),

      // ── Sparkline cards ──
      Row(children: [
        Expanded(
          child: SparkCard(
            value: '${curBookings.length}',
            label: 'New bookings',
            points: series(bookings),
            color: const Color(0xFF5DB043),
            trend: curBookings.length - prevBookings,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: widget.isAdmin
              ? SparkCard(
                  value: '$curClients',
                  label: 'New customers',
                  points: series(clients),
                  color: const Color(0xFF3D80E8),
                  trend: curClients - prevClients,
                )
              : SparkCard(
                  value: fmtHours(curHours),
                  label: 'Hours booked',
                  points: series(bookings, hoursOf),
                  color: const Color(0xFF3D80E8),
                  trend: (curHours - prevHours).sign.toInt(),
                ),
        ),
      ]),
      if (widget.isAdmin) ...[
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: SparkCard(
              value: fmtHours(curHours),
              label: 'Hours booked',
              points: series(bookings, hoursOf),
              color: const Color(0xFFF5B533),
              trend: (curHours - prevHours).sign.toInt(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SparkCard(
              value:
                  '${bookings.where((d) => d['status'] == 'complete' && inCur(d)).length}',
              label: 'Jobs completed',
              points: series(
                  bookings.where((d) => d['status'] == 'complete').toList()),
              color: const Color(0xFF8B5CF6),
              trend: delta('complete'),
            ),
          ),
        ]),
      ],
      const SizedBox(height: 14),

      // ── Bar chart ──
      DashCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DashTitle(
            kicker: 'Activity',
            title: per == 1 ? 'Bookings per day' : 'Bookings over time',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Dash.field, borderRadius: BorderRadius.circular(10)),
              child: Text('${curBookings.length} total',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Dash.textMid)),
            ),
          ),
          const SizedBox(height: 12),
          BarChart(values: series(bookings), labels: labels),
        ]),
      ),
      const SizedBox(height: 14),

      // ── Breakdown with progress bars ──
      DashCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DashTitle(
            kicker: widget.isAdmin ? 'Services' : 'Your jobs',
            title: widget.isAdmin ? 'Bookings by service' : 'Job progress',
            trailing: TextButton(
              onPressed: () => widget.onOpen(1),
              child: Text('View all',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3D80E8))),
            ),
          ),
          const SizedBox(height: 6),
          ..._breakdown(curBookings),
        ]),
      ),
    ]);
  }

  List<Widget> _breakdown(List<Map<String, dynamic>> cur) {
    if (cur.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text('No bookings in this period.',
              style: GoogleFonts.inter(fontSize: 13, color: Dash.textMute)),
        ),
      ];
    }
    if (!widget.isAdmin) {
      final total = cur.length;
      int c(String s) => cur.where((d) => d['status'] == s).length;
      return [
        for (final (s, label, icon, color) in [
          (
            'active',
            'In progress',
            Icons.play_circle_fill_rounded,
            const Color(0xFF5DB043)
          ),
          (
            'pending',
            'Waiting to start',
            Icons.hourglass_top_rounded,
            const Color(0xFFF5B533)
          ),
          (
            'complete',
            'Completed',
            Icons.task_alt_rounded,
            const Color(0xFF3D80E8)
          ),
          ('cancelled', 'Cancelled', Icons.cancel_rounded, AppTheme.red),
        ])
          ProgressRow(
            icon: icon,
            color: color,
            title: label,
            subtitle: '${(c(s) * 100 / total).round()}% of your jobs',
            trailing: '${c(s)}/$total',
            progress: c(s) / total,
          ),
      ];
    }
    final byCat = <String, List<Map<String, dynamic>>>{};
    for (final d in cur) {
      final cat = (d['category'] ?? '').toString();
      byCat.putIfAbsent(cat.isEmpty ? 'Other' : cat, () => []).add(d);
    }
    final rows = byCat.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return [
      for (final e in rows.take(5))
        Builder(builder: (_) {
          final (icon, color) = _serviceStyle(e.key);
          final done = e.value.where((d) => d['status'] == 'complete').length;
          return ProgressRow(
            icon: icon,
            color: color,
            title: _titleCase(e.key),
            subtitle: '$done completed',
            trailing:
                '${e.value.length} booking${e.value.length == 1 ? '' : 's'}',
            progress: e.value.length / cur.length,
          );
        }),
    ];
  }

  static (IconData, Color) _serviceStyle(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('clean')) {
      return (Icons.cleaning_services_rounded, const Color(0xFF3D80E8));
    }
    if (c.contains('construct') || c.contains('build')) {
      return (Icons.construction_rounded, const Color(0xFFF5B533));
    }
    if (c.contains('care') || c.contains('health') || c.contains('nurs')) {
      return (Icons.volunteer_activism_rounded, const Color(0xFFE2394A));
    }
    if (c.contains('garden'))
      return (Icons.yard_rounded, const Color(0xFF5DB043));
    return (Icons.home_repair_service_rounded, const Color(0xFF8B5CF6));
  }

  static String _titleCase(String s) => s
      .split(RegExp(r'[_\s]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

// ══════════════════════════════════════════
// 2. BOOKINGS TAB
// ══════════════════════════════════════════
class _BookingsTab extends StatefulWidget {
  final bool isAdmin;
  final String? category; // null = all services (admin)
  const _BookingsTab({required this.isAdmin, this.category});
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

  // ── Admin: export bookings to Excel (per service), optionally delete ──
  Future<void> _export() async {
    final snap = await FirebaseFirestore.instance
        .collection('bookings')
        .orderBy('createdAt', descending: true)
        .get();
    final all = snap.docs;
    if (!mounted) return;
    if (all.isEmpty) {
      _toast('There are no bookings to export.');
      return;
    }
    final counts = <String, int>{};
    for (final d in all) {
      final c = BookingExport.categoryOf(d.data());
      counts[c] = (counts[c] ?? 0) + 1;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Dash.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Export bookings to Excel',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Dash.accent)),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.table_view_outlined, color: Dash.accent),
              title: const Text('All services'),
              subtitle: Text('${all.length} bookings · one sheet per service'),
              onTap: () => Navigator.pop(ctx, '*'),
            ),
            const Divider(height: 1),
            for (final e in counts.entries)
              ListTile(
                leading: Icon(Icons.description_outlined, color: Dash.textMid),
                title: Text(e.key),
                subtitle: Text('${e.value} bookings'),
                onTap: () => Navigator.pop(ctx, e.key),
              ),
          ]),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final docs = choice == '*'
        ? all
        : all
            .where((d) => BookingExport.categoryOf(d.data()) == choice)
            .toList();
    final title = choice == '*' ? 'All services' : choice;
    try {
      await BookingExport.exportAndShare(docs, title: title);
    } catch (_) {
      _toast('Could not create the Excel file. Please try again.');
      return;
    }
    if (!mounted) return;
    // Offer to clear the exported bookings now they're saved for the records.
    final del = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete exported bookings?'),
        content: Text(
            'Exported ${docs.length} bookings ($title). Do you also want to delete '
            'them from the app? Only do this once you have saved the Excel file. '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep them')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Delete', style: TextStyle(color: AppTheme.red))),
        ],
      ),
    );
    if (del != true) return;
    try {
      await BookingExport.deleteAll(docs);
      _toast('Deleted ${docs.length} bookings.', ok: true);
    } catch (_) {
      _toast('Could not delete the bookings. Please try again.');
    }
  }

  void _toast(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppTheme.green : AppTheme.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (!widget.isAdmin && (widget.category ?? '').isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: _ServiceBanner(category: widget.category),
        ),
      // Filter chips
      Container(
        color: Dash.card,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Expanded(
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
                                color:
                                    _filter == f ? AppTheme.navy : Dash.field,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                    color: _filter == f
                                        ? Dash.accent
                                        : Dash.border),
                              ),
                              child: Text(f[0].toUpperCase() + f.substring(1),
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _filter == f
                                          ? Colors.white
                                          : Dash.textMid,
                                      letterSpacing: 0.5)),
                            ),
                          ))
                      .toList()),
            ),
          ),
          if (widget.isAdmin)
            IconButton(
              tooltip: 'Export to Excel',
              icon: Icon(Icons.file_download_outlined, color: Dash.accent),
              onPressed: _export,
            ),
        ]),
      ),
      Expanded(
          child: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(
                    color: Dash.accent, strokeWidth: 2));
          }
          final docs = (snap.data?.docs ?? [])
              .where((d) => _inScope(d.data() as Map, widget.category))
              .toList();
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
    // Staff don't see the staff list
    if (!widget.isAdmin) {
      return _UserList(collection: 'clients', emptyLabel: 'No customers yet');
    }
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
          return Center(
              child: CircularProgressIndicator(
                  color: Dash.accent, strokeWidth: 2));
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
                  color: Dash.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Dash.border),
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
                                    color: Dash.accent,
                                    letterSpacing: 0.3)),
                            Text(d['email'] ?? '',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Dash.textMute,
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
                          Icon(Icons.phone_outlined,
                              size: 13, color: Dash.textMute),
                          const SizedBox(width: 4),
                          Text(d['phone'],
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Dash.textMid)),
                          const SizedBox(width: 16),
                        ],
                        if ((d['staffRole'] ?? '').isNotEmpty) ...[
                          Icon(Icons.work_outline,
                              size: 13, color: Dash.textMute),
                          const SizedBox(width: 4),
                          Text(d['staffRole'],
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Dash.textMid)),
                        ],
                        if ((d['category'] ?? '').isNotEmpty) ...[
                          const SizedBox(width: 16),
                          Icon(Icons.category_outlined,
                              size: 13, color: Dash.textMute),
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
                            color: Dash.accent,
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
                  color: Dash.accent),
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
                    color: Dash.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Dash.border)),
                child: Row(children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Dash.text,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('$count job${count != 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Dash.accent)),
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
                    color: Dash.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Dash.border)),
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
                                color: Dash.accent,
                                letterSpacing: 0.3)),
                        Text(data['clientName'] ?? '',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Dash.textMute,
                                fontWeight: FontWeight.w300)),
                      ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    _PayBadge(method: data['payMethod'] ?? ''),
                    if (ts != null)
                      Text(DateFormat('d MMM').format(ts),
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Dash.textMute,
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
            return Center(
                child: CircularProgressIndicator(
                    color: Dash.accent, strokeWidth: 2));
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
                    color: Dash.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Dash.border),
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
                                color: Dash.accent,
                                letterSpacing: 0.3)),
                        Text(d['email'] ?? '',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Dash.textMute,
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
                                color: Dash.field,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text('DBS',
                                style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Dash.accent))),
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
    final categories = [
      'Cleaning',
      'Home Care',
      'Medical',
      'Non-Medical',
      'Construction'
    ];

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
            decoration: BoxDecoration(
              color: Dash.card,
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
                                color: Dash.border,
                                borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 18),
                    Text('ADD STAFF MEMBER',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Dash.accent,
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
                            color: Dash.textMute,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                          color: Dash.field,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Dash.border)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: role,
                          isExpanded: true,
                          dropdownColor: Dash.card,
                          style:
                              GoogleFonts.inter(fontSize: 14, color: Dash.text),
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
                            color: Dash.textMute,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                          color: Dash.field,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Dash.border)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: category,
                          isExpanded: true,
                          dropdownColor: Dash.card,
                          style:
                              GoogleFonts.inter(fontSize: 14, color: Dash.text),
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
                            color: Dash.textMute,
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
            return Center(
                child: CircularProgressIndicator(
                    color: Dash.accent, strokeWidth: 2));
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
                    color: Dash.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Dash.border)),
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
                                color: Dash.accent,
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
                                  color: Dash.textMute,
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
            decoration: BoxDecoration(
                color: Dash.card,
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
                                color: Dash.border,
                                borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 18),
                    Text('ADD CATEGORY',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Dash.accent,
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
                            color: Dash.textMute,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                          color: Dash.field,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Dash.border)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: division,
                          isExpanded: true,
                          dropdownColor: Dash.card,
                          style:
                              GoogleFonts.inter(fontSize: 14, color: Dash.text),
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

/// Whether a booking / staff / quote record belongs to [category].
/// null category = admin, sees everything.
bool _inScope(Map data, String? category) {
  if (category == null) return true;
  if (category.isEmpty) return false;
  return (data['category'] ?? '').toString() == category;
}

/// Tells staff which service they're seeing (or that none is assigned).
class _ServiceBanner extends StatelessWidget {
  final String? category;
  const _ServiceBanner({required this.category});
  @override
  Widget build(BuildContext context) {
    final none = (category ?? '').isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: (none ? AppTheme.goldDark : Dash.accent).withOpacity(.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: (none ? AppTheme.goldDark : Dash.accent).withOpacity(.2))),
      child: Row(children: [
        Icon(none ? Icons.info_outline : Icons.work_outline,
            size: 18, color: none ? AppTheme.goldDark : Dash.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
              none
                  ? 'You have not been assigned to a service yet. Ask the admin to set your service.'
                  : 'Showing bookings for your service: $category',
              style: GoogleFonts.inter(fontSize: 12.5, color: Dash.text)),
        ),
      ]),
    );
  }
}

Widget _sectionHeader(String t) => Text(t,
    style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Dash.accent,
        letterSpacing: 1.5));

Widget _emptyState(String msg) => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined, size: 48, color: Dash.textMute),
          const SizedBox(height: 12),
          Text(msg,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Dash.textMute,
                  fontWeight: FontWeight.w300)),
        ]),
      ),
    );

Widget _inputField(String label, TextEditingController ctrl, IconData icon,
        {TextInputType type = TextInputType.text}) =>
    TextField(
      controller: ctrl,
      keyboardType: type,
      style: GoogleFonts.inter(fontSize: 14, color: Dash.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Dash.textMute,
            letterSpacing: 0.8),
        prefixIcon: Icon(icon, size: 18, color: Dash.textMute),
        filled: true,
        fillColor: Dash.field,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Dash.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Dash.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Dash.accent, width: 1.5)),
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
        'complete' => Dash.accent,
        'cancelled' => AppTheme.red,
        _ => AppTheme.goldDark,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: Dash.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Dash.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 6)
          ]),
      child: ExpansionTile(
        leading: Text(booking.icon, style: const TextStyle(fontSize: 24)),
        title: Text(booking.service,
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Dash.accent,
                letterSpacing: 0.3)),
        subtitle: Text('${booking.clientName}  •  ${booking.date}',
            style: GoogleFonts.inter(
                fontSize: 11,
                color: Dash.textMute,
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
                    color: Dash.accent,
                    onTap: () => _setStatus('complete')),
                if (isAdmin) ...[
                  const Spacer(),
                  IconButton(
                    tooltip: 'Delete booking',
                    icon: const Icon(Icons.delete_outline,
                        color: AppTheme.red, size: 20),
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
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

  // Admin only (also enforced by Firestore rules)
  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete booking?'),
        content: Text(
            '${booking.service} for ${booking.clientName} on ${booking.date} will be '
            'permanently deleted. Export to Excel first if you need a record.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Delete', style: TextStyle(color: AppTheme.red))),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance.collection('bookings').doc(docId).delete();
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 14, color: Dash.textMute),
          const SizedBox(width: 8),
          Text('$label: ',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Dash.textMid,
                  letterSpacing: 0.3)),
          Expanded(
              child: Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Dash.text,
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
          color: Dash.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Dash.border)),
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
                  color: Dash.accent,
                  letterSpacing: 0.3)),
          Text(data['staffRole'] ?? 'Staff',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Dash.textMute,
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
            color: Dash.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Dash.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.request_quote_outlined, size: 22, color: Dash.accent),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(data['clientName'] ?? 'Unknown',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Dash.accent)),
                  Text(data['clientEmail'] ?? '',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Dash.textMute,
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
                      color: Dash.accent,
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
                  color: Dash.textMid,
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
              color: Dash.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Dash.border),
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
                      color: Dash.textMute,
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
            color: Dash.accent.withOpacity(.08),
            borderRadius: BorderRadius.circular(6)),
        child: Text(_label,
            style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Dash.accent,
                letterSpacing: 0.4)),
      );
}
