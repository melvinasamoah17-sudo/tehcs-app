import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../booking_screen.dart';

IconData _cleaningServiceIcon(String name) => switch (name) {
  'Regular House Cleaning'  => Icons.cleaning_services_outlined,
  'Deep Cleaning'           => Icons.auto_awesome_outlined,
  'Office Cleaning'         => Icons.business_outlined,
  'End of Tenancy Cleaning' => Icons.vpn_key_outlined,
  'Carpet Cleaning'         => Icons.weekend_outlined,
  'Window Cleaning'         => Icons.window_outlined,
  'After-Builders Cleaning' => Icons.construction_outlined,
  _                         => Icons.cleaning_services_outlined,
};

class CleaningHomeScreen extends StatelessWidget {
  const CleaningHomeScreen({super.key});

  static const _services = [
    {'icon': '🧹', 'name': 'Regular House Cleaning',  'desc': 'Weekly or fortnightly home cleaning by vetted professionals.',          'duration': '2–4 hrs'},
    {'icon': '✨', 'name': 'Deep Cleaning',             'desc': 'Top-to-bottom intensive clean including appliances and skirting boards.', 'duration': '4–8 hrs'},
    {'icon': '🏢', 'name': 'Office Cleaning',           'desc': 'Commercial cleaning scheduled daily, weekly or on-demand.',             'duration': 'Flexible'},
    {'icon': '🔑', 'name': 'End of Tenancy Cleaning',   'desc': 'Guaranteed clean to meet landlord and letting agent requirements.',     'duration': '4–10 hrs'},
    {'icon': '🛋️', 'name': 'Carpet Cleaning',           'desc': 'Steam and dry cleaning to remove stains, allergens and odours.',       'duration': '2–4 hrs'},
    {'icon': '🪟', 'name': 'Window Cleaning',            'desc': 'Interior and exterior window cleaning for homes and offices.',          'duration': '1–3 hrs'},
    {'icon': '🏗️', 'name': 'After-Builders Cleaning',   'desc': 'Post-construction clean removing dust, debris and builder residue.',    'duration': '4–8 hrs'},
  ];

  static const _steps = [
    {'icon': Icons.smartphone, 'title': 'Book Online',      'desc': 'Select your service and preferred date'},
    {'icon': Icons.check_circle, 'title': 'We Confirm',        'desc': 'We match you with a vetted cleaner'},
    {'icon': Icons.cleaning_services, 'title': 'We Clean',          'desc': 'Professional service at your location'},
    {'icon': Icons.star, 'title': 'Leave a Review',    'desc': 'Rate your experience after the visit'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: CustomScrollView(
        slivers: [
          // ── HEADER ──
          SliverToBoxAdapter(child: _buildHeader(context)),

          // ── WHY TEHCS ──
          SliverToBoxAdapter(child: _buildFeatures()),

          // ── SERVICES ──
          SliverToBoxAdapter(child: _sectionLabel('OUR CLEANING SERVICES')),
          SliverList(delegate: SliverChildBuilderDelegate(
            (_, i) => _ServiceCard(s: _services[i], color: const Color(0xFF2980B9),
              onBook: () => _book(context, _services[i])),
            childCount: _services.length,
          )),

          // ── HOW IT WORKS ──
          SliverToBoxAdapter(child: _buildHowItWorks()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1B4F72), Color(0xFF2980B9)]),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context)),
            const Spacer(),
          ]),
          const Icon(Icons.cleaning_services, size: 48, color: Colors.white),
          const SizedBox(height: 10),
          Text('Cleaning Services', style: GoogleFonts.poppins(
            fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text('Professional cleaning for homes, offices and commercial spaces.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w300, height: 1.6)),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _book(context, _services[0]),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1B4F72), padding: const EdgeInsets.symmetric(vertical: 13),
                shape: const StadiumBorder(), elevation: 0),
              child: Text('Book a Cleaning Now', style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            ),
          ),
        ]),
      )),
    );
  }

  Widget _buildFeatures() {
    final items = [
      {'icon': Icons.verified_user_outlined, 'text': 'Fully vetted & insured staff'},
      {'icon': Icons.schedule, 'text': 'Flexible scheduling'},
      {'icon': Icons.credit_card, 'text': 'Easy online payment'},
      {'icon': Icons.star, 'text': 'Satisfaction guaranteed'},
    ];
    return Container(
      color: const Color(0xFF1B4F72),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Row(children: items.map((f) => Expanded(
        child: Column(children: [
          Icon(f['icon'] as IconData, size: 20, color: Colors.white),
          const SizedBox(height: 4),
          Text(f['text'] as String, textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 9, color: Colors.white60, fontWeight: FontWeight.w300, height: 1.4)),
        ]),
      )).toList()),
    );
  }

  Widget _buildHowItWorks() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabelInline('HOW IT WORKS'),
        const SizedBox(height: 12),
        ...List.generate(_steps.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFF2980B9).withOpacity(.1),
                borderRadius: BorderRadius.circular(10)),
              child: Center(child: Icon(_steps[i]['icon'] as IconData, size: 20, color: const Color(0xFF2980B9)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i + 1}. ${_steps[i]['title']}', style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.navy, letterSpacing: 0.3)),
              Text(_steps[i]['desc'] as String, style: GoogleFonts.inter(
                fontSize: 12, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
            ])),
          ]),
        )),
      ]),
    );
  }

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(t, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.navy, letterSpacing: 1.5)),
  );

  Widget _sectionLabelInline(String t) =>
    Text(t, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.navy, letterSpacing: 1.5));

  void _book(BuildContext context, Map<String, dynamic> s) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => BookingScreen(service: s['name'] as String, icon: s['icon'] as String, category: 'Cleaning')));
  }
}

// ══════════════════════════════════════════
// SHARED SERVICE CARD
// ══════════════════════════════════════════
class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> s;
  final Color color;
  final VoidCallback onBook;
  const _ServiceCard({required this.s, required this.color, required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Container(height: 4, decoration: BoxDecoration(
          color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(16)))),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 48, height: 48,
              decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Icon(_cleaningServiceIcon(s['name'] as String), size: 24, color: color))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s['name'] as String, style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 0.3)),
              const SizedBox(height: 4),
              Text(s['desc'] as String, style: GoogleFonts.inter(
                fontSize: 12, color: AppTheme.textMid, fontWeight: FontWeight.w300, height: 1.5)),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.schedule_outlined, size: 12, color: AppTheme.textMute),
                const SizedBox(width: 4),
                Text(s['duration'] as String, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
                const Spacer(),
                GestureDetector(
                  onTap: onBook,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(100)),
                    child: Text('Book', style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                  ),
                ),
              ]),
            ])),
          ]),
        ),
      ]),
    );
  }
}
