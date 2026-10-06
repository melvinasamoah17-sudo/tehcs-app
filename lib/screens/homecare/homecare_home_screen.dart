import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../booking_screen.dart';

IconData _serviceIcon(String name) => switch (name) {
  'Personal Care'          => Icons.favorite,
  'Senior Care'            => Icons.elderly,
  'Companionship'          => Icons.people_outline,
  'Medication Reminders'   => Icons.medication_outlined,
  'Meal Preparation'       => Icons.restaurant_outlined,
  'Shopping Assistance'    => Icons.shopping_cart_outlined,
  'Live-in Care'           => Icons.home_outlined,
  'Night Care'             => Icons.nightlight_outlined,
  'Respite Care'           => Icons.spa_outlined,
  'Occupational Therapy'   => Icons.accessibility_new_outlined,
  _                        => Icons.favorite_border,
};

class HomecareHomeScreen extends StatefulWidget {
  const HomecareHomeScreen({super.key});
  @override
  State<HomecareHomeScreen> createState() => _HomecareHomeScreenState();
}

class _HomecareHomeScreenState extends State<HomecareHomeScreen> {
  bool _sosPressed = false;

  static const _services = [
    {'icon': '🫶', 'name': 'Personal Care',        'desc': 'Dignified assistance with bathing, dressing, grooming and hygiene.',            'duration': '1–4 hrs',   'urgent': false},
    {'icon': '👴', 'name': 'Senior Care',           'desc': 'Specialist support for elderly clients focused on safety and wellbeing.',        'duration': 'Flexible',  'urgent': false},
    {'icon': '🤝', 'name': 'Companionship',         'desc': 'Caring companions providing social engagement and emotional support at home.',   'duration': 'Flexible',  'urgent': false},
    {'icon': '💊', 'name': 'Medication Reminders',  'desc': 'Scheduled reminders and guidance for correct medication management.',           'duration': 'Daily',     'urgent': false},
    {'icon': '🍳', 'name': 'Meal Preparation',      'desc': 'Nutritious home-cooked meals tailored to dietary needs and preferences.',       'duration': '1–2 hrs',   'urgent': false},
    {'icon': '🛒', 'name': 'Shopping Assistance',   'desc': 'We shop for your essentials so you never run out of what you need.',            'duration': '1–2 hrs',   'urgent': false},
    {'icon': '🏡', 'name': 'Live-in Care',          'desc': 'Full-time live-in carer providing round-the-clock support and companionship.',  'duration': '24/7',      'urgent': false},
    {'icon': '🌙', 'name': 'Night Care',            'desc': 'Overnight care providing peace of mind and support during night hours.',         'duration': 'Overnight', 'urgent': false},
    {'icon': '💆', 'name': 'Respite Care',          'desc': 'Temporary relief care giving regular carers a well-deserved break.',            'duration': 'Flexible',  'urgent': false},
    {'icon': '🦾', 'name': 'Occupational Therapy',  'desc': 'Qualified therapists helping clients regain independence and daily living skills.','duration': '1–2 hrs', 'urgent': false},
  ];

  Future<void> _triggerSOS() async {
    setState(() => _sosPressed = true);
    // Call emergency line
    final uri = Uri.parse('tel:+233240699329');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _sosPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildSOS()),
          SliverToBoxAdapter(child: _buildCareFeatures()),
          SliverToBoxAdapter(child: _sectionLabel('HOME CARE SERVICES')),
          SliverList(delegate: SliverChildBuilderDelegate(
            (_, i) => _ServiceCard(s: _services[i], color: AppTheme.red,
              onBook: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => BookingScreen(service: _services[i]['name'] as String, icon: _services[i]['icon'] as String, category: 'Home Care')))),
            childCount: _services.length,
          )),
          SliverToBoxAdapter(child: _buildCarePromise()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF6B1E3C), Color(0xFFE63329)]),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context)),
            const Spacer(),
          ]),
          const Icon(Icons.favorite, size: 48, color: Colors.white),
          const SizedBox(height: 10),
          Text('Home Care Services', style: GoogleFonts.poppins(
            fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text('Compassionate, professional care delivered to your door — 24 hours a day, 7 days a week.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w300, height: 1.6)),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const BookingScreen(service: 'Personal Care', icon: '🫶', category: 'Home Care'))),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6B1E3C),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: const StadiumBorder(), elevation: 0),
              child: Text('Book Care Now', style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            ),
          ),
        ]),
      )),
    );
  }

  Widget _buildSOS() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.red.withOpacity(.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.red.withOpacity(.25), width: 1.5),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('EMERGENCY SOS', style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.red, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text('Press if you or your loved one needs immediate assistance.',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMid, fontWeight: FontWeight.w300, height: 1.5)),
        ])),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: _triggerSOS,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _sosPressed ? AppTheme.red.withOpacity(.8) : AppTheme.red,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppTheme.red.withOpacity(.4), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Center(child: Icon(_sosPressed ? Icons.phone : Icons.sos,
              size: 26, color: Colors.white)),
          ),
        ),
      ]),
    );
  }

  Widget _buildCareFeatures() {
    final items = [
      {'icon': Icons.verified_user_outlined, 'text': 'DBS-checked carers'},
      {'icon': Icons.schedule, 'text': '24/7 available'},
      {'icon': Icons.favorite, 'text': 'Person-centred care'},
      {'icon': Icons.assignment_outlined, 'text': 'Care plans & records'},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: items.map((f) => Expanded(
        child: Container(
          margin: EdgeInsets.only(right: f == items.last ? 0.0 : 8.0),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border)),
          child: Column(children: [
            Icon(f['icon'] as IconData, size: 22, color: AppTheme.navy),
            const SizedBox(height: 6),
            Text(f['text'] as String, textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textMute, fontWeight: FontWeight.w300, height: 1.4)),
          ]),
        ),
      )).toList()),
    );
  }

  Widget _buildCarePromise() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6B1E3C), Color(0xFFE63329)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('OUR CARE PROMISE', style: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
        const SizedBox(height: 10),
        ...['Every carer is DBS-checked and fully insured.',
            'We match you with the right carer for your needs.',
            'Care plans are created with you and your family.',
            'Regular welfare checks and family updates.',
            '24/7 emergency support line always available.']
          .map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('✓ ', style: TextStyle(color: Colors.white, fontSize: 13)),
              Expanded(child: Text(t, style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(.8),
                fontWeight: FontWeight.w300, height: 1.5))),
            ]),
          )),
      ]),
    );
  }

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(t, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800,
      color: AppTheme.navy, letterSpacing: 1.5)),
  );
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
              child: Center(child: Icon(_serviceIcon(s['name'] as String), size: 24, color: color))),
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
