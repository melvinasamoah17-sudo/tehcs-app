import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/booking.dart';
import 'booking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  String _query = '';

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? user?.email?.split('@').first ?? 'there';
    return name.split(' ').first;
  }

  static const _services = [
    // Healthcare
    {'name': 'Home Health Care',     'icon': '🩺', 'cat': 'Healthcare'},
    {'name': 'Senior Care',          'icon': '👴', 'cat': 'Healthcare'},
    {'name': 'Personal Care',        'icon': '🫶', 'cat': 'Healthcare'},
    {'name': 'Medication Reminders', 'icon': '💊', 'cat': 'Healthcare'},
    {'name': 'Occupational Therapy', 'icon': '🦾', 'cat': 'Healthcare'},
    {'name': 'Companionship',        'icon': '🤝', 'cat': 'Healthcare'},
    // Construction
    {'name': 'Plumbing',             'icon': '🔧', 'cat': 'Construction'},
    {'name': 'Electrical Work',      'icon': '⚡', 'cat': 'Construction'},
    {'name': 'Painting',             'icon': '🖌️', 'cat': 'Construction'},
    {'name': 'Interior Decoration',  'icon': '🛋️', 'cat': 'Construction'},
    {'name': 'Building Construction','icon': '🏛️', 'cat': 'Construction'},
    {'name': 'Gardening',            'icon': '🌿', 'cat': 'Construction'},
    // Non-Medical
    {'name': 'Housekeeping',         'icon': '🏠', 'cat': 'Non-Medical'},
    {'name': 'Cook / Chef',          'icon': '👨‍🍳', 'cat': 'Non-Medical'},
    {'name': 'Nanny / Childcare',    'icon': '👶', 'cat': 'Non-Medical'},
    {'name': 'Driver',               'icon': '🚗', 'cat': 'Non-Medical'},
    {'name': 'Laundry',              'icon': '🧺', 'cat': 'Non-Medical'},
    {'name': 'Office Cleaning',      'icon': '🧹', 'cat': 'Non-Medical'},
  ];

  List<Map<String, String>> get _filtered => _services
      .where((s) => s['name']!.toLowerCase().contains(_query.toLowerCase()))
      .toList()
      .cast<Map<String, String>>();

  void _openBooking(String service, String icon) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => BookingScreen(service: service, icon: icon),
    ));
  }

  Future<void> _call(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsApp() async {
    final uri = Uri.parse('https://wa.me/233240699329');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: CustomScrollView(
        slivers: [
          // ── HERO ──
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.navyDark, AppTheme.navy],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Logo + title
                          Row(children: [
                            Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                color: AppTheme.white,
                                borderRadius: BorderRadius.circular(8),
                                image: const DecorationImage(
                                  image: AssetImage('assets/images/tehcs.jpg'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('TEHCS', style: GoogleFonts.barlowCondensed(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.white, letterSpacing: 1)),
                              Text('Home Care Service', style: GoogleFonts.barlowCondensed(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.gold, letterSpacing: 0.8)),
                            ]),
                          ]),
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined, color: Colors.white70, size: 22),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Greeting
                      Text('$_greeting,', style: GoogleFonts.nunito(fontSize: 13, color: Colors.white60, fontWeight: FontWeight.w300)),
                      Text('Welcome, $_firstName 👋',
                        style: GoogleFonts.barlowCondensed(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.white, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 14),

                      // Search
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.13)),
                        ),
                        child: TextField(
                          controller: _search,
                          style: GoogleFonts.nunito(color: Colors.white, fontSize: 14),
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: 'Search services...',
                            hintStyle: GoogleFonts.nunito(color: Colors.white38, fontSize: 14),
                            prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── STATS ──
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.navyDark,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: StreamBuilder<QuerySnapshot>(
                stream: uid == null ? null : FirebaseFirestore.instance
                    .collection('bookings')
                    .where('uid', isEqualTo: uid)
                    .snapshots(),
                builder: (ctx, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  return Row(children: [
                    _statBox('$count', 'Bookings'),
                    const SizedBox(width: 8),
                    _statBox('3', 'Categories'),
                    const SizedBox(width: 8),
                    _statBox('24/7', 'Support'),
                  ]);
                },
              ),
            ),
          ),

          // ── SERVICES ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('OUR SERVICES', style: GoogleFonts.barlowCondensed(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.navy, letterSpacing: 1)),
                  Text('All', style: GoogleFonts.barlowCondensed(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.goldDark)),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: 132,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                itemCount: _filtered.length,
                itemBuilder: (ctx, i) {
                  final s = _filtered[i];
                  return _ServiceChip(
                    name: s['name']!,
                    icon: s['icon']!,
                    cat:  s['cat']!,
                    onTap: () => _openBooking(s['name']!, s['icon']!),
                  );
                },
              ),
            ),
          ),

          // ── RECENT BOOKINGS ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('RECENT BOOKINGS', style: GoogleFonts.barlowCondensed(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.navy, letterSpacing: 1)),
                  Text('All →', style: GoogleFonts.barlowCondensed(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.goldDark)),
                ],
              ),
            ),
          ),

          if (uid != null)
            SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('bookings')
                    .where('uid', isEqualTo: uid)
                    .orderBy('createdAt', descending: true)
                    .limit(3)
                    .snapshots(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        const Text('📋', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 10),
                        Text('No bookings yet.\nTap a service above to get started!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(fontSize: 13, color: AppTheme.textMute, fontWeight: FontWeight.w300),
                        ),
                      ]),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: docs.map((d) => _BookingCard(booking: Booking.fromFirestore(d))).toList(),
                    ),
                  );
                },
              ),
            ),

          // ── HELP STRIP ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.navyDark, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NEED HELP?', style: GoogleFonts.barlowCondensed(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.white, letterSpacing: 1)),
                        Text('Available 24/7', style: GoogleFonts.nunito(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w300)),
                      ],
                    )),
                    _circleBtn('📞', AppTheme.gold, () => _call('+233240699329')),
                    const SizedBox(width: 8),
                    _circleBtn('💬', const Color(0xFF25D366), _whatsApp),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String n, String l) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(children: [
        Text(n, style: GoogleFonts.barlowCondensed(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.gold, height: 1)),
        const SizedBox(height: 2),
        Text(l, style: GoogleFonts.nunito(fontSize: 10, color: Colors.white38)),
      ]),
    ),
  );

  Widget _circleBtn(String emoji, Color bg, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16))),
    ),
  );
}

// ── SERVICE CHIP ──
class _ServiceChip extends StatelessWidget {
  final String name, icon, cat;
  final VoidCallback onTap;
  const _ServiceChip({required this.name, required this.icon, required this.cat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 5),
          Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.barlowCondensed(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.navy, letterSpacing: 0.3, height: 1.15),
          ),
          const SizedBox(height: 2),
          Text(cat, style: GoogleFonts.nunito(fontSize: 9, color: AppTheme.textMute)),
        ]),
      ),
    );
  }
}

// ── BOOKING CARD ──
class _BookingCard extends StatelessWidget {
  final Booking booking;
  const _BookingCard({required this.booking});

  Color get _statusColor => switch (booking.status) {
    'active'   => AppTheme.green,
    'complete' => AppTheme.navy,
    _          => AppTheme.goldDark,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${booking.icon} ${booking.service}',
                style: GoogleFonts.barlowCondensed(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.navy, letterSpacing: 0.3),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(booking.status.toUpperCase(),
                  style: GoogleFonts.barlowCondensed(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(children: [
            _meta(Icons.calendar_today_outlined, booking.date.isEmpty ? 'TBD' : booking.date),
            const SizedBox(width: 14),
            _meta(Icons.access_time_outlined, booking.time.isEmpty ? 'Flexible' : booking.time),
          ]),
          if (booking.address.isNotEmpty) ...[
            const SizedBox(height: 4),
            _meta(Icons.location_on_outlined, booking.address.length > 30 ? '${booking.address.substring(0, 30)}...' : booking.address),
          ],
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(children: [
    Icon(icon, size: 13, color: AppTheme.textMute),
    const SizedBox(width: 4),
    Text(text, style: GoogleFonts.nunito(fontSize: 12, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
  ]);
}