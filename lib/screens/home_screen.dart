import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/booking.dart';
import 'cleaning/cleaning_home_screen.dart';
import 'homecare/homecare_home_screen.dart';
import 'construction/construction_home_screen.dart';
import 'booking_screen.dart';

IconData _divisionIcon(String id) => switch (id) {
      'cleaning' => Icons.cleaning_services,
      'homecare' => Icons.favorite,
      'construction' => Icons.construction,
      _ => Icons.star,
    };

String _divisionCategory(String id) => switch (id) {
      'cleaning' => 'Cleaning',
      'homecare' => 'Home Care',
      'construction' => 'Construction',
      _ => '',
    };

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String _query = '';

  // ── Animation controllers ──
  late AnimationController _heroCtrl;
  late AnimationController _helpCtrl;

  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _helpFade;
  late Animation<Offset> _helpSlide;

  // Per-card stagger controllers
  final List<AnimationController> _cardCtrls = [];
  final List<Animation<Offset>> _cardSlides = [];
  final List<Animation<double>> _cardFades = [];

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

  // ── 3 Divisions ──
  final _divisions = [
    {
      'id': 'cleaning',
      'emoji': '🧹',
      'title': 'Cleaning Services',
      'subtitle': 'House · Office · Deep Clean · End of Tenancy',
      'color': const Color(0xFF1B4F72),
      'accent': const Color(0xFF2980B9),
      'services': [
        'Regular House Cleaning',
        'Deep Cleaning',
        'Office Cleaning',
        'End of Tenancy',
        'Carpet Cleaning',
        'Window Cleaning'
      ],
    },
    {
      'id': 'homecare',
      'emoji': '❤️',
      'title': 'Home Care',
      'subtitle': 'Personal Care · Senior Care · Live-in · Night Care',
      'color': const Color(0xFF6B1E3C),
      'accent': const Color(0xFFE63329),
      'services': [
        'Personal Care',
        'Senior Care',
        'Companionship',
        'Medication Reminders',
        'Live-in Care',
        'Night Care'
      ],
    },
    {
      'id': 'construction',
      'emoji': '🏗️',
      'title': 'Construction',
      'subtitle': 'Plumbing · Electrical · Building · Renovation',
      'color': const Color(0xFF1A3A1A),
      'accent': const Color(0xFF27AE60),
      'services': [
        'Plumbing',
        'Electrical Work',
        'Painting',
        'Building Work',
        'Carpentry',
        'Landscaping'
      ],
    },
  ];

  @override
  void initState() {
    super.initState();

    // Hero fade + slide
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(begin: const Offset(0, -0.08), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic));

    // Help strip
    _helpCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _helpFade = CurvedAnimation(parent: _helpCtrl, curve: Curves.easeOut);
    _helpSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _helpCtrl, curve: Curves.easeOutCubic));

    // One controller per division card
    for (int i = 0; i < _divisions.length; i++) {
      final ctrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 550));
      _cardCtrls.add(ctrl);
      _cardSlides.add(
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
            .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic)),
      );
      _cardFades.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
    }

    // Stagger the animations
    _heroCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      for (int i = 0; i < _cardCtrls.length; i++) {
        Future.delayed(Duration(milliseconds: i * 120), () {
          if (mounted) _cardCtrls[i].forward();
        });
      }
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _helpCtrl.forward();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _heroCtrl.dispose();
    _helpCtrl.dispose();
    for (final c in _cardCtrls) c.dispose();
    super.dispose();
  }

  void _openDivision(Map<String, dynamic> div) {
    Widget screen;
    switch (div['id']) {
      case 'cleaning':
        screen = const CleaningHomeScreen();
        break;
      case 'homecare':
        screen = const HomecareHomeScreen();
        break;
      case 'construction':
        screen = const ConstructionHomeScreen();
        break;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _call(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsApp() async {
    final uri = Uri.parse('https://wa.me/233240699329');
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: CustomScrollView(
        slivers: [
          // ── HERO / APP BAR ──
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _heroSlide,
              child: FadeTransition(opacity: _heroFade, child: _buildHero()),
            ),
          ),

          // ── STATS ──
          SliverToBoxAdapter(
            child: FadeTransition(opacity: _heroFade, child: _buildStats(uid)),
          ),

          // ── AD CAROUSEL ──
          if (_query.isEmpty) const SliverToBoxAdapter(child: _AdCarousel()),

          // ── SEARCH RESULTS (if searching) ──
          if (_query.isNotEmpty)
            SliverToBoxAdapter(child: _buildSearchResults()),

          // ── 3 DIVISION CARDS ──
          if (_query.isEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'OUR SERVICES',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => SlideTransition(
                  position: _cardSlides[i],
                  child: FadeTransition(
                    opacity: _cardFades[i],
                    child: _DivisionCard(
                      division: _divisions[i],
                      onTap: () => _openDivision(_divisions[i]),
                    ),
                  ),
                ),
                childCount: _divisions.length,
              ),
            ),
          ],

          // ── RECENT BOOKINGS ──
          if (_query.isEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RECENT BOOKINGS',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navy,
                          letterSpacing: 1.5),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: Text(
                        'View all →',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.goldDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (uid != null)
              SliverToBoxAdapter(child: _buildRecentBookings(uid)),
          ],

          // ── HELP STRIP ──
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _helpSlide,
              child:
                  FadeTransition(opacity: _helpFade, child: _buildHelpStrip()),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // HERO
  // ─────────────────────────────────────────
  Widget _buildHero() {
    return Container(
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Top row
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                // Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/tehcs.jpg',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: AppTheme.gold,
                          borderRadius: BorderRadius.circular(8)),
                      child: Center(
                          child: Text('T',
                              style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.navyDark))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TEHCS',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.white,
                          letterSpacing: 1)),
                  Text('Home Care Service',
                      style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.gold,
                          letterSpacing: 0.8)),
                ]),
              ]),
              // Notification bell
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.notifications_outlined,
                    color: Colors.white70, size: 20),
              ),
            ]),
            const SizedBox(height: 22),

            // Greeting
            Text('$_greeting,',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white60,
                    fontWeight: FontWeight.w300)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                _firstName,
                style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.white,
                    letterSpacing: 0.5),
              ),
              const SizedBox(width: 8),
              // Animated waving hand
              _WavingHand(),
            ]),
            const SizedBox(height: 16),

            // Search bar
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.1),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withOpacity(.13)),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search services...',
                  hintStyle:
                      GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.white38, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white38, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // STATS
  // ─────────────────────────────────────────
  Widget _buildStats(String? uid) {
    return Container(
      color: AppTheme.navyDark,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: StreamBuilder<QuerySnapshot>(
        stream: uid == null
            ? null
            : FirebaseFirestore.instance
                .collection('bookings')
                .where('uid', isEqualTo: uid)
                .snapshots(),
        builder: (_, snap) {
          final total = snap.data?.docs.length ?? 0;
          final active = snap.data?.docs
                  .where((d) => (d.data() as Map)['status'] == 'active')
                  .length ??
              0;
          return Row(children: [
            _AnimatedStatBox(value: total, label: 'Bookings'),
            const SizedBox(width: 8),
            _AnimatedStatBox(value: active, label: 'Active'),
            const SizedBox(width: 8),
            _AnimatedStatBox(value: 3, label: 'Services'),
            const SizedBox(width: 8),
            _StatBoxRaw(value: '24/7', label: 'Support'),
          ]);
        },
      ),
    );
  }

  // ─────────────────────────────────────────
  // SEARCH RESULTS
  // ─────────────────────────────────────────
  Widget _buildSearchResults() {
    final allServices = _divisions
        .expand((d) => (d['services'] as List<String>).map((s) => {
              'name': s,
              'division': d['id'],
              'emoji': d['emoji'],
              'icon': _divisionIcon(d['id'] as String),
              'color': d['accent']
            }))
        .where((s) =>
            (s['name'] as String).toLowerCase().contains(_query.toLowerCase()))
        .toList();

    if (allServices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          const Icon(Icons.search_off_rounded,
              size: 40, color: AppTheme.textMute),
          const SizedBox(height: 12),
          Text(
            'No services found for "$_query"',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMute),
          ),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          '${allServices.length} result${allServices.length != 1 ? 's' : ''} for "$_query"',
          style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMute,
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),
        ...allServices.map((s) => _SearchResultTile(
              name: s['name'] as String,
              icon: s['icon'] as IconData,
              color: s['color'] as Color,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingScreen(
                          service: s['name'] as String,
                          icon: s['emoji'] as String,
                          category: _divisionCategory(s['division'] as String)),
                    ));
              },
            )),
      ]),
    );
  }

  // ─────────────────────────────────────────
  // RECENT BOOKINGS
  // ─────────────────────────────────────────
  Widget _buildRecentBookings(String uid) {
    // Use a simple single-field query (no orderBy) to avoid composite index.
    // Sort client-side and take top 3.
    final stream = FirebaseFirestore.instance
        .collection('bookings')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((s) {
      final list = s.docs.map(Booking.fromFirestore).toList();
      list.sort((a, b) {
        final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
      return list.take(3).toList();
    });

    return StreamBuilder<List<Booking>>(
      stream: stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: CircularProgressIndicator(
                    color: AppTheme.navy, strokeWidth: 2)),
          );
        }
        final bookings = snap.data ?? [];
        if (bookings.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(children: [
                const Icon(Icons.assignment_outlined,
                    size: 32, color: AppTheme.textMute),
                const SizedBox(height: 10),
                Text('No bookings yet',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMute)),
                const SizedBox(height: 4),
                Text('Tap a service above to get started',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMute,
                        fontWeight: FontWeight.w300)),
              ]),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: bookings.map((b) => _BookingTile(booking: b)).toList(),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // HELP STRIP
  // ─────────────────────────────────────────
  Widget _buildHelpStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.navyDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('NEED HELP?',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.white,
                        letterSpacing: 1)),
                const SizedBox(height: 2),
                Text('We\'re available 24/7',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white38,
                        fontWeight: FontWeight.w300)),
              ])),
          _PulseCircleBtn(
              icon: Icons.phone,
              color: AppTheme.gold,
              onTap: () => _call('+233240699329')),
          const SizedBox(width: 8),
          _CircleBtn(
              icon: Icons.smartphone,
              color: const Color(0xFF25D366),
              onTap: () => _call('+447448468070')),
          const SizedBox(width: 8),
          _CircleBtn(
              icon: Icons.chat,
              color: const Color(0xFF25D366),
              onTap: _whatsApp),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// WAVING HAND (animated)
// ══════════════════════════════════════════
class _WavingHand extends StatefulWidget {
  @override
  State<_WavingHand> createState() => _WavingHandState();
}

class _WavingHandState extends State<_WavingHand>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _rotation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.35), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.35, end: -0.15), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.15, end: 0.25), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    // Play once after a short delay, then repeat every 4s
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _ctrl.forward().then((_) {
          if (mounted) {
            Timer.periodic(const Duration(seconds: 4), (t) {
              if (!mounted) {
                t.cancel();
                return;
              }
              _ctrl.reset();
              _ctrl.forward();
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _rotation,
        builder: (_, child) => Transform.rotate(
          angle: _rotation.value,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
        child: const Icon(Icons.waving_hand_rounded,
            color: AppTheme.gold, size: 24),
      );
}

// ══════════════════════════════════════════
// DIVISION CARD (with press-scale)
// ══════════════════════════════════════════
class _DivisionCard extends StatefulWidget {
  final Map<String, dynamic> division;
  final VoidCallback onTap;
  const _DivisionCard({required this.division, required this.onTap});
  @override
  State<_DivisionCard> createState() => _DivisionCardState();
}

class _DivisionCardState extends State<_DivisionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.division['color'] as Color;
    final accent = widget.division['accent'] as Color;
    final svcs = widget.division['services'] as List<String>;

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Stack(children: [
            // Background pattern
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: accent.withOpacity(.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: accent.withOpacity(.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(_divisionIcon(widget.division['id'] as String),
                          size: 36, color: Colors.white),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(children: [
                          Text('Book now',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.4)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 14),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    Text(
                      widget.division['title'] as String,
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.division['subtitle'] as String,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white60,
                          fontWeight: FontWeight.w300),
                    ),
                    const SizedBox(height: 16),

                    // Service chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: svcs
                          .take(4)
                          .map((s) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.1),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(.15)),
                                ),
                                child: Text(
                                  s,
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w400),
                                ),
                              ))
                          .toList(),
                    ),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// ANIMATED STAT BOX (count-up)
// ══════════════════════════════════════════
class _AnimatedStatBox extends StatefulWidget {
  final int value;
  final String label;
  const _AnimatedStatBox({required this.value, required this.label});
  @override
  State<_AnimatedStatBox> createState() => _AnimatedStatBoxState();
}

class _AnimatedStatBoxState extends State<_AnimatedStatBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _count;
  int _prevValue = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _count = Tween<double>(begin: 0, end: widget.value.toDouble())
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ctrl.forward();
    });
    _prevValue = widget.value;
  }

  @override
  void didUpdateWidget(_AnimatedStatBox old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _count = Tween<double>(
              begin: _prevValue.toDouble(), end: widget.value.toDouble())
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
      _ctrl.reset();
      _ctrl.forward();
      _prevValue = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(.07)),
          ),
          child: Column(children: [
            AnimatedBuilder(
              animation: _count,
              builder: (_, __) => Text(
                '${_count.value.round()}',
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.gold,
                    height: 1),
              ),
            ),
            const SizedBox(height: 2),
            Text(widget.label,
                style: GoogleFonts.inter(fontSize: 9, color: Colors.white38)),
          ]),
        ),
      );
}

// ══════════════════════════════════════════
// STAT BOX (raw string — for 24/7)
// ══════════════════════════════════════════
class _StatBoxRaw extends StatelessWidget {
  final String value;
  final String label;
  const _StatBoxRaw({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(.07)),
          ),
          child: Column(children: [
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.gold,
                    height: 1)),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.inter(fontSize: 9, color: Colors.white38)),
          ]),
        ),
      );
}

// ══════════════════════════════════════════
// SEARCH RESULT TILE
// ══════════════════════════════════════════
class _SearchResultTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SearchResultTile(
      {required this.name,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withOpacity(.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Center(child: Icon(icon, size: 20, color: color)),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(name,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy,
                        letterSpacing: 0.3))),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppTheme.textMute),
          ]),
        ),
      );
}

// ══════════════════════════════════════════
// BOOKING TILE
// ══════════════════════════════════════════
class _BookingTile extends StatelessWidget {
  final Booking booking;
  const _BookingTile({required this.booking});

  Color get _statusColor => switch (booking.status) {
        'active' => AppTheme.green,
        'complete' => AppTheme.navy,
        _ => AppTheme.goldDark,
      };

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          Text(booking.icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  booking.service,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                      letterSpacing: 0.3),
                ),
                const SizedBox(height: 3),
                Text(
                  '${booking.date}  •  ${booking.time}',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textMute,
                      fontWeight: FontWeight.w300),
                ),
              ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              booking.status.toUpperCase(),
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _statusColor,
                  letterSpacing: 0.5),
            ),
          ),
        ]),
      );
}

// ══════════════════════════════════════════
// AD CAROUSEL
// ══════════════════════════════════════════
class _AdCarousel extends StatefulWidget {
  const _AdCarousel();
  @override
  State<_AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<_AdCarousel> {
  static const _images = [
    'assets/images/ad_1.jpg',
    'assets/images/ad_2.jpg',
    'assets/images/ad_3.jpg',
    'assets/images/ad_4.jpg',
    'assets/images/ad_5.jpg',
    'assets/images/ad_6.jpg',
    'assets/images/ad_7.jpg',
    'assets/images/ad_8.jpg',
  ];

  late final PageController _pageCtrl;
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_current + 1) % _images.length;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(children: [
        // ── Slide area ──
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 190,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: _images.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) => Image.asset(
                _images[i],
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: AppTheme.navyDark,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.image_outlined,
                            color: Colors.white24, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'TEHCS',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.gold,
                              letterSpacing: 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // ── Dot indicator ──
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _images.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _current == i ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: _current == i
                    ? AppTheme.gold
                    : Colors.grey.withOpacity(.35),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// CIRCLE BUTTON (static)
// ══════════════════════════════════════════
class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CircleBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(child: Icon(icon, size: 18, color: Colors.white)),
        ),
      );
}

// ══════════════════════════════════════════
// PULSE CIRCLE BUTTON (for phone — gold)
// ══════════════════════════════════════════
class _PulseCircleBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _PulseCircleBtn(
      {required this.icon, required this.color, required this.onTap});
  @override
  State<_PulseCircleBtn> createState() => _PulseCircleBtnState();
}

class _PulseCircleBtnState extends State<_PulseCircleBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.18)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) =>
              Transform.scale(scale: _pulse.value, child: child),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child:
                Center(child: Icon(widget.icon, size: 18, color: Colors.white)),
          ),
        ),
      );
}
