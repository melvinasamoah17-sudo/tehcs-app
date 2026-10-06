import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/booking.dart';
import 'booking_screen.dart';
import '../widgets/animations.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _filters = ['All', 'Pending', 'Active', 'Complete', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _filters.length, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<Booking>> _stream(String filter) {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    // Single-field queries only — avoids composite index requirement.
    // Sorting is done client-side after the snapshot arrives.
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('bookings')
        .where('uid', isEqualTo: uid);

    if (filter != 'All') {
      q = q.where('status', isEqualTo: filter.toLowerCase());
    }

    return q.snapshots().map((s) {
      final list = s.docs.map(Booking.fromFirestore).toList();
      // Sort newest first client-side
      list.sort((a, b) {
        final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.navyDark,
            automaticallyImplyLeading: false,
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MY BOOKINGS',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Live booking count
                      StreamBuilder<QuerySnapshot>(
                        stream: _uid == null
                            ? null
                            : FirebaseFirestore.instance
                                .collection('bookings')
                                .where('uid', isEqualTo: _uid)
                                .snapshots(),
                        builder: (_, snap) {
                          final count = snap.data?.docs.length ?? 0;
                          final active = snap.data?.docs
                                  .where((d) =>
                                      (d.data() as Map)['status'] == 'active')
                                  .length ??
                              0;
                          return Text(
                            '$count total  •  $active active',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white38,
                              fontWeight: FontWeight.w300,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
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
              labelStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8),
              unselectedLabelStyle: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600),
              tabs: _filters.map((f) => Tab(text: f)).toList(),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: _filters
              .map((f) => _BookingList(
                    stream: _stream(f),
                    filter: f,
                  ))
              .toList(),
        ),
      ),
      // FAB — new booking
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.white,
        icon: const Icon(Icons.add),
        label: Text(
          'New Booking',
          style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        onPressed: () => _showServicePicker(context),
      ),
    );
  }

  IconData _categoryIcon(String cat) => switch (cat) {
        'Cleaning' => Icons.cleaning_services,
        'Home Care' => Icons.favorite,
        'Construction' => Icons.construction,
        _ => Icons.star,
      };

  void _showServicePicker(BuildContext context) {
    final services = [
      {'name': 'Regular House Cleaning', 'icon': '🧹', 'cat': 'Cleaning'},
      {'name': 'Deep Cleaning', 'icon': '✨', 'cat': 'Cleaning'},
      {'name': 'Office Cleaning', 'icon': '🏢', 'cat': 'Cleaning'},
      {'name': 'Personal Care', 'icon': '🫶', 'cat': 'Home Care'},
      {'name': 'Senior Care', 'icon': '👴', 'cat': 'Home Care'},
      {'name': 'Companionship', 'icon': '🤝', 'cat': 'Home Care'},
      {'name': 'Medication Reminders', 'icon': '💊', 'cat': 'Home Care'},
      {'name': 'Live-in Care', 'icon': '🏡', 'cat': 'Home Care'},
      {'name': 'Plumbing', 'icon': '🔧', 'cat': 'Construction'},
      {'name': 'Electrical Work', 'icon': '⚡', 'cat': 'Construction'},
      {'name': 'Painting', 'icon': '🖌️', 'cat': 'Construction'},
      {'name': 'Handyman Services', 'icon': '🔨', 'cat': 'Construction'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Row(children: [
                Text(
                  'SELECT SERVICE',
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.navy,
                      letterSpacing: 1),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textMute),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: services.length,
                itemBuilder: (_, i) {
                  final s = services[i];
                  // Show category header
                  final showHeader =
                      i == 0 || services[i - 1]['cat'] != s['cat'];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHeader) ...[
                        if (i > 0) const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 4),
                          child: Text(
                            s['cat']!.toUpperCase(),
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMute,
                                letterSpacing: 1.2),
                          ),
                        ),
                      ],
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookingScreen(
                                  service: s['name']!,
                                  icon: s['icon']!,
                                  category: s['cat'] ?? '',
                                ),
                              ));
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.offWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(children: [
                            Icon(_categoryIcon(s['cat']!),
                                size: 24, color: AppTheme.navy),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(
                              s['name']!,
                              style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.navy,
                                  letterSpacing: 0.3),
                            )),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 14, color: AppTheme.textMute),
                          ]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// BOOKING LIST
// ══════════════════════════════════════════
class _BookingList extends StatelessWidget {
  final Stream<List<Booking>> stream;
  final String filter;
  const _BookingList({required this.stream, required this.filter});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(color: AppTheme.navy, strokeWidth: 2),
          );
        }
        if (snap.hasError) {
          return _EmptyState(
            icon: Icons.warning_amber_rounded,
            title: 'Something went wrong',
            subtitle: 'Pull down to refresh',
          );
        }
        final bookings = snap.data ?? [];
        if (bookings.isEmpty) {
          return _EmptyState(
            icon: filter == 'All'
                ? Icons.assignment_outlined
                : _filterIcon(filter),
            title: filter == 'All' ? 'No bookings yet' : 'No $filter bookings',
            subtitle: filter == 'All'
                ? 'Tap + New Booking to get started'
                : 'Your $filter bookings will appear here',
          );
        }
        return RefreshIndicator(
          color: AppTheme.navy,
          onRefresh: () async {},
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
            itemCount: bookings.length,
            itemBuilder: (_, i) => FadeSlideIn(index: i, child: _BookingCard(booking: bookings[i])),
          ),
        );
      },
    );
  }

  IconData _filterIcon(String f) => switch (f) {
        'Pending' => Icons.schedule,
        'Active' => Icons.check_circle,
        'Complete' => Icons.flag,
        'Cancelled' => Icons.cancel,
        _ => Icons.assignment_outlined,
      };
}

// ══════════════════════════════════════════
// BOOKING CARD
// ══════════════════════════════════════════
class _BookingCard extends StatelessWidget {
  final Booking booking;
  const _BookingCard({required this.booking});

  Color get _statusColor => switch (booking.status) {
        'active' => AppTheme.green,
        'complete' => AppTheme.navy,
        'cancelled' => AppTheme.red,
        _ => AppTheme.goldDark,
      };

  IconData get _statusIcon => switch (booking.status) {
        'active' => Icons.circle,
        'complete' => Icons.check_circle,
        'cancelled' => Icons.cancel,
        _ => Icons.circle,
      };

  double get _progress => switch (booking.status) {
        'pending' => 0.2,
        'active' => 0.6,
        'complete' => 1.0,
        _ => 0.0,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(children: [
        // ── Status colour bar ──
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: _statusColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Top row ──
            Row(children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                    child: Text(booking.icon,
                        style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                      booking.service,
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.navy,
                          letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(_statusIcon, size: 10, color: _statusColor),
                      const SizedBox(width: 4),
                      Text(
                        booking.status.toUpperCase(),
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _statusColor,
                            letterSpacing: 0.6),
                      ),
                    ]),
                  ])),
              // Actions menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    color: AppTheme.textMute, size: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (val) => _handleAction(context, val),
                itemBuilder: (_) => [
                  _menuItem('call', Icons.phone_outlined, 'Call TEHCS'),
                  _menuItem('whatsapp', Icons.chat_outlined, 'WhatsApp'),
                  _menuItem('cancel', Icons.cancel_outlined, 'Cancel Booking',
                      color: AppTheme.red,
                      enabled: booking.status == 'pending'),
                ],
              ),
            ]),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Details grid ──
            Row(children: [
              Expanded(
                  child: _DetailItem(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value: booking.date.isEmpty ? 'TBD' : booking.date,
              )),
              Expanded(
                  child: _DetailItem(
                icon: Icons.access_time_outlined,
                label: 'Time',
                value: booking.time.isEmpty ? 'TBD' : booking.time,
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _DetailItem(
                icon: Icons.schedule_outlined,
                label: 'Duration',
                value: booking.hours > 0
                    ? '${booking.hours} hr${booking.hours != 1 ? "s" : ""}'
                    : 'TBD',
              )),
              Expanded(
                  child: _DetailItem(
                icon: Icons.payment_outlined,
                label: 'Payment',
                value: _payLabel(booking.payMethod),
              )),
            ]),

            if (booking.address.isNotEmpty) ...[
              const SizedBox(height: 10),
              _DetailItem(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: booking.address,
                fullWidth: true,
              ),
            ],

            if (booking.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              _DetailItem(
                icon: Icons.notes_outlined,
                label: 'Notes',
                value: booking.notes,
                fullWidth: true,
              ),
            ],

            // ── Progress bar (not cancelled) ──
            if (booking.status != 'cancelled') ...[
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(
                  _progressLabel,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _statusColor,
                      letterSpacing: 0.5),
                ),
                Text(
                  '${(_progress * 100).round()}%',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _statusColor),
                ),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: AppTheme.light,
                  valueColor: AlwaysStoppedAnimation(_statusColor),
                  minHeight: 5,
                ),
              ),
            ],

            // ── Booking date ──
            if (booking.createdAt != null) ...[
              const SizedBox(height: 10),
              Text(
                'Booked on ${DateFormat('d MMM yyyy, HH:mm').format(booking.createdAt!)}',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textMute,
                    fontWeight: FontWeight.w300),
              ),
            ],
          ]),
        ),

        // ── Action buttons ──
        if (booking.status == 'pending' || booking.status == 'active')
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                onPressed: () => _callTehcs(),
                icon: const Icon(Icons.phone_outlined, size: 16),
                label: Text('Call',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.navy,
                  side: const BorderSide(color: AppTheme.border),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: ElevatedButton.icon(
                onPressed: () => _whatsApp(),
                icon: const Icon(Icons.chat, size: 14, color: Colors.white),
                label: Text('WhatsApp',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                ),
              )),
            ]),
          ),
      ]),
    );
  }

  String get _progressLabel => switch (booking.status) {
        'pending' => 'Awaiting confirmation',
        'active' => 'Service in progress',
        'complete' => 'Completed',
        _ => '',
      };

  String _payLabel(String? m) => switch (m) {
        'pay_later' => 'Invoice',
        'bank' => 'Bank Transfer',
        'card' => 'Card',
        'apple_pay' => 'Apple Pay',
        'google_pay' => 'Google Pay',
        _ => 'TBD',
      };

  PopupMenuItem<String> _menuItem(String val, IconData icon, String label,
      {Color? color, bool enabled = true}) {
    return PopupMenuItem(
      value: val,
      enabled: enabled,
      child: Row(children: [
        Icon(icon, size: 18, color: color ?? AppTheme.textMid),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: color ?? AppTheme.navyDark,
            fontWeight: FontWeight.w500,
          ),
        ),
      ]),
    );
  }

  void _handleAction(BuildContext context, String val) {
    switch (val) {
      case 'call':
        _callTehcs();
        break;
      case 'whatsapp':
        _whatsApp();
        break;
      case 'cancel':
        _showCancelDialog(context);
        break;
    }
  }

  Future<void> _callTehcs() async {
    final uri = Uri.parse('tel:+233240699329');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsApp() async {
    final msg = Uri.encodeComponent(
        'Hello TEHCS, I need help with my booking for ${booking.service} on ${booking.date}.');
    final uri = Uri.parse('https://wa.me/233240699329?text=$msg');
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Cancel Booking',
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.navy)),
        content: Text(
          'Are you sure you want to cancel your ${booking.service} booking?',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep it',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMute)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection('bookings')
                  .doc(booking.id)
                  .update({'status': 'cancelled'});
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.red,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                elevation: 0),
            child: Text('Cancel Booking',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// DETAIL ITEM
// ══════════════════════════════════════════
class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool fullWidth;
  const _DetailItem(
      {required this.icon,
      required this.label,
      required this.value,
      this.fullWidth = false});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppTheme.textMute),
          const SizedBox(width: 6),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMute,
                      letterSpacing: 0.8),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.navyDark,
                      fontWeight: FontWeight.w500),
                  maxLines: fullWidth ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ])),
        ],
      );
}

// ══════════════════════════════════════════
// EMPTY STATE
// ══════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 52, color: AppTheme.textMute),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMute),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textMute,
                fontWeight: FontWeight.w300),
            textAlign: TextAlign.center,
          ),
        ]),
      );
}
