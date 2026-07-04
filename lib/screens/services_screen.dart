import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'booking_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _search = TextEditingController();
  String _query = '';

  static const _categories = ['All', 'Healthcare', 'Construction', 'Non-Medical'];

  static const _services = [
    // Healthcare
    {'name': 'Professional Doctors',  'icon': '👨‍⚕️', 'cat': 'Healthcare',    'desc': 'Qualified doctors providing home visits, assessments and ongoing health monitoring.'},
    {'name': 'Personal Care',         'icon': '🫶',   'cat': 'Healthcare',    'desc': 'Dignified assistance with bathing, dressing, grooming and daily hygiene routines.'},
    {'name': 'Senior Care',           'icon': '👴',   'cat': 'Healthcare',    'desc': 'Specialized support for elderly clients focused on comfort, safety and quality of life.'},
    {'name': 'Occupational Therapy',  'icon': '🦾',   'cat': 'Healthcare',    'desc': 'Therapists helping clients regain daily living skills and improve mobility.'},
    {'name': 'Warm Companionship',    'icon': '🤝',   'cat': 'Healthcare',    'desc': 'Caring companions providing social engagement and emotional support at home.'},
    {'name': 'Medication Reminders',  'icon': '💊',   'cat': 'Healthcare',    'desc': 'Scheduled reminders and pharmacist guidance ensuring proper medication management.'},
    // Construction
    {'name': 'Plumbing',              'icon': '🔧',   'cat': 'Construction',  'desc': 'Licensed plumbers for repairs, installations, emergency leaks and upgrades.'},
    {'name': 'Electrical Work',       'icon': '⚡',   'cat': 'Construction',  'desc': 'Certified electricians for safe wiring, installations and compliance work.'},
    {'name': 'Painting',              'icon': '🖌️',  'cat': 'Construction',  'desc': 'Interior and exterior painting using premium finishes and meticulous prep work.'},
    {'name': 'Interior Decoration',   'icon': '🛋️',  'cat': 'Construction',  'desc': 'Expert styling, colour consultation and finishing touches for your living space.'},
    {'name': 'Building Construction', 'icon': '🏛️',  'cat': 'Construction',  'desc': 'Full building and renovation construction managed end-to-end by our expert team.'},
    {'name': 'Gardening',             'icon': '🌿',   'cat': 'Construction',  'desc': 'Lawn care, landscaping, pruning and outdoor maintenance year-round.'},
    {'name': 'Carpentry Works',       'icon': '🪚',   'cat': 'Construction',  'desc': 'Custom carpentry for furniture, fittings and bespoke woodwork to your spec.'},
    // Non-Medical
    {'name': 'Housekeeping',          'icon': '🏠',   'cat': 'Non-Medical',   'desc': 'Thorough home cleaning and household management by background-checked staff.'},
    {'name': 'Hotel Keeping',         'icon': '🏨',   'cat': 'Non-Medical',   'desc': 'Trained hospitality staff to manage guest services and hotel operations.'},
    {'name': 'Nanny / Childcare',     'icon': '👶',   'cat': 'Non-Medical',   'desc': 'Experienced, caring nannies providing safe, loving childcare at home.'},
    {'name': 'Cook / Chef',           'icon': '👨‍🍳','cat': 'Non-Medical',   'desc': 'Skilled cooks preparing nutritious or gourmet meals to your dietary needs.'},
    {'name': 'Laundry Services',      'icon': '🧺',   'cat': 'Non-Medical',   'desc': 'Professional laundry, ironing and garment care with attention and discretion.'},
    {'name': 'Grocery Shopping',      'icon': '🛒',   'cat': 'Non-Medical',   'desc': 'We shop for your essentials so you never run out of what you need.'},
    {'name': 'Drivers & Ushers',      'icon': '🚗',   'cat': 'Non-Medical',   'desc': 'Reliable drivers and ushers for appointments, events and daily transport.'},
    {'name': 'Office Cleaning',       'icon': '🧹',   'cat': 'Non-Medical',   'desc': 'Professional commercial cleaning scheduled daily, weekly or on-demand.'},
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _categories.length, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _tabs.dispose(); _search.dispose(); super.dispose(); }

  List<Map<String, String>> _filtered(String cat) {
    return _services.where((s) {
      final matchCat   = cat == 'All' || s['cat'] == cat;
      final matchQuery = _query.isEmpty || s['name']!.toLowerCase().contains(_query.toLowerCase());
      return matchCat && matchQuery;
    }).toList().cast<Map<String, String>>();
  }

  Color _catColor(String cat) => switch (cat) {
    'Healthcare'   => AppTheme.goldDark,
    'Construction' => AppTheme.navy,
    _              => AppTheme.red,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.navyDark,
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                image: const DecorationImage(image: AssetImage('assets/images/tehcs.jpg'), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
            Text('SERVICES', style: GoogleFonts.barlowCondensed(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.white, letterSpacing: 1.5)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(children: [
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Container(
                height: 40,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.13))),
                child: TextField(
                  controller: _search,
                  style: GoogleFonts.nunito(color: Colors.white, fontSize: 13),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search services...',
                    hintStyle: GoogleFonts.nunito(color: Colors.white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                    border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            // Tabs
            TabBar(
              controller: _tabs,
              isScrollable: true,
              labelColor: AppTheme.gold,
              unselectedLabelColor: Colors.white54,
              indicatorColor: AppTheme.gold,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.barlowCondensed(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.8),
              unselectedLabelStyle: GoogleFonts.barlowCondensed(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: _categories.map((c) => Tab(text: c)).toList(),
            ),
          ]),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: _categories.map((cat) {
          final items = _filtered(cat);
          if (items.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('🔍', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text('No services found.', style: GoogleFonts.barlowCondensed(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMute)),
              ]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final s = items[i];
              return _ServiceCard(
                name: s['name']!,
                icon: s['icon']!,
                cat:  s['cat']!,
                desc: s['desc']!,
                catColor: _catColor(s['cat']!),
                onBook: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => BookingScreen(service: s['name']!, icon: s['icon']!),
                )),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String name, icon, cat, desc;
  final Color catColor;
  final VoidCallback onBook;
  const _ServiceCard({required this.name, required this.icon, required this.cat, required this.desc, required this.catColor, required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Top accent line
          Container(height: 4, decoration: BoxDecoration(color: catColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(16)))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon box
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(color: catColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(icon, style: const TextStyle(fontSize: 28))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(color: catColor.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                        child: Text(cat.toUpperCase(),
                          style: GoogleFonts.barlowCondensed(fontSize: 9, fontWeight: FontWeight.w800, color: catColor, letterSpacing: 0.8),
                        ),
                      ),
                      Text(name,
                        style: GoogleFonts.barlowCondensed(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 6),
                      Text(desc,
                        style: GoogleFonts.nunito(fontSize: 12, color: AppTheme.textMid, fontWeight: FontWeight.w300, height: 1.55),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Book button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: const StadiumBorder(),
                ),
                child: Text('Book This Service',
                  style: GoogleFonts.barlowCondensed(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}