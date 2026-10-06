import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'booking_screen.dart';
import '../widgets/animations.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _query = '';

  static const _categories = ['All', 'Cleaning', 'Home Care', 'Non-Medical', 'Construction'];

  static const _services = [
    // ── CLEANING ──
    _Service(name: 'Domestic Cleaning',           icon: '🧹', cat: 'Cleaning',     desc: 'Regular cleaning of houses, flats and apartments.', duration: '2–4 hrs'),
    _Service(name: 'Deep Cleaning',               icon: '✨', cat: 'Cleaning',     desc: 'Intensive cleaning of kitchens, bathrooms, bedrooms and living areas.', duration: '4–8 hrs'),
    _Service(name: 'End-of-Tenancy Cleaning',     icon: '🔑', cat: 'Cleaning',     desc: 'Detailed cleaning before a property is handed back to a landlord or letting agent.', duration: '4–10 hrs'),
    _Service(name: 'Move-In / Move-Out Cleaning', icon: '📦', cat: 'Cleaning',     desc: 'Preparing a property for a new occupant or after someone moves out.', duration: '3–6 hrs'),
    _Service(name: 'Office Cleaning',             icon: '🏢', cat: 'Cleaning',     desc: 'Cleaning offices, meeting rooms, kitchens, toilets and shared areas.', duration: 'Flexible'),
    _Service(name: 'Commercial Cleaning',         icon: '🏪', cat: 'Cleaning',     desc: 'Cleaning shops, businesses and commercial premises.', duration: 'Flexible'),
    _Service(name: 'Hotel & Hospitality Cleaning', icon: '🛎️', cat: 'Cleaning',   desc: 'Guest rooms, corridors, reception areas and other hotel spaces.', duration: 'Flexible'),
    _Service(name: 'Communal Area Cleaning',      icon: '🏗️', cat: 'Cleaning',    desc: 'Staircases, hallways, lifts, shared kitchens and other communal spaces.', duration: 'Flexible'),
    _Service(name: 'After-Builders Cleaning',     icon: '🔨', cat: 'Cleaning',     desc: 'Removing dust, dirt and construction residue after building or renovation work.', duration: '4–8 hrs'),
    _Service(name: 'Event Cleaning',              icon: '🎉', cat: 'Cleaning',     desc: 'Cleaning before, during or after events.', duration: 'Flexible'),
    _Service(name: 'Regular Contract Cleaning',   icon: '📋', cat: 'Cleaning',     desc: 'Scheduled cleaning services for homes, offices, businesses and other premises.', duration: 'Contract'),
    _Service(name: 'Laundry & Ironing',           icon: '👕', cat: 'Cleaning',     desc: 'Washing, drying, folding and ironing clothes, towels and bedding.', duration: '2–4 hrs'),

    // ── HOME CARE ──
    _Service(name: 'Personal Care',             icon: '🫶', cat: 'Home Care',    desc: 'Dignified assistance with bathing, dressing, grooming and daily hygiene.', duration: '1–4 hrs'),
    _Service(name: 'Senior Care',               icon: '👴', cat: 'Home Care',    desc: 'Specialist support for elderly clients focused on comfort, safety and wellbeing.', duration: 'Flexible'),
    _Service(name: 'Companionship',             icon: '🤝', cat: 'Home Care',    desc: 'Caring companions providing social engagement and emotional support at home.', duration: 'Flexible'),
    _Service(name: 'Medication Reminders',      icon: '💊', cat: 'Home Care',    desc: 'Scheduled reminders and guidance ensuring correct medication management.', duration: 'Daily'),
    _Service(name: 'Meal Preparation',          icon: '🍳', cat: 'Home Care',    desc: 'Nutritious home-cooked meals tailored to dietary needs and preferences.', duration: '1–2 hrs'),
    _Service(name: 'Shopping Assistance',       icon: '🛒', cat: 'Home Care',    desc: 'We shop for your essentials so you never run out of what you need.', duration: '1–2 hrs'),
    _Service(name: 'Live-in Care',              icon: '🏡', cat: 'Home Care',    desc: 'Full-time live-in carer providing round-the-clock support and companionship.', duration: '24/7'),
    _Service(name: 'Night Care',                icon: '🌙', cat: 'Home Care',    desc: 'Overnight care providing peace of mind and support during night-time hours.', duration: 'Overnight'),
    _Service(name: 'Respite Care',              icon: '💆', cat: 'Home Care',    desc: 'Temporary relief care giving regular carers a well-deserved break.', duration: 'Flexible'),
    _Service(name: 'Occupational Therapy',      icon: '🦾', cat: 'Home Care',    desc: 'Qualified therapists helping clients regain independence and daily living skills.', duration: '1–2 hrs'),

    // ── CONSTRUCTION ──
    _Service(name: 'Plumbing',                  icon: '🔧', cat: 'Construction', desc: 'Licensed plumbers for repairs, installations, emergency leaks and upgrades.', duration: 'Flexible'),
    _Service(name: 'Electrical Work',           icon: '⚡', cat: 'Construction', desc: 'Certified electricians for safe wiring, installations and compliance work.', duration: 'Flexible'),
    _Service(name: 'Painting & Decorating',     icon: '🖌️', cat: 'Construction', desc: 'Interior and exterior painting using premium finishes and thorough prep.', duration: '1–5 days'),
    _Service(name: 'Interior Decoration',       icon: '🛋️', cat: 'Construction', desc: 'Expert styling, colour consultation and finishing touches for your space.', duration: 'Flexible'),
    _Service(name: 'General Building Work',     icon: '🏛️', cat: 'Construction', desc: 'Full building and renovation construction managed end-to-end by our team.', duration: 'Project-based'),
    _Service(name: 'Carpentry',                 icon: '🪚', cat: 'Construction', desc: 'Custom carpentry for furniture, fittings and bespoke woodwork to your spec.', duration: 'Flexible'),
    _Service(name: 'Plastering',                icon: '🏠', cat: 'Construction', desc: 'Skim, patch and full-room plastering for smooth and durable wall finishes.', duration: '1–3 days'),
    _Service(name: 'Roofing',                   icon: '🏚️', cat: 'Construction', desc: 'Roof repairs, replacement and inspection by experienced roofing specialists.', duration: 'Flexible'),
    _Service(name: 'Flooring',                  icon: '⬛', cat: 'Construction', desc: 'Supply and fitting of laminate, hardwood, vinyl and tile flooring.', duration: '1–3 days'),
    _Service(name: 'Landscaping',               icon: '🌿', cat: 'Construction', desc: 'Garden design, lawn care, pruning and full outdoor maintenance.', duration: 'Flexible'),
    _Service(name: 'Kitchen Fitting',           icon: '🍽️', cat: 'Construction', desc: 'Full kitchen installation including units, worktops, plumbing and electrics.', duration: '3–7 days'),
    _Service(name: 'Bathroom Installation',     icon: '🚿', cat: 'Construction', desc: 'Complete bathroom fitting — tiling, plumbing, fixtures and finishes.', duration: '3–5 days'),
    _Service(name: 'Handyman Services',         icon: '🔨', cat: 'Construction', desc: 'Odd jobs, small repairs and home maintenance tasks handled quickly.', duration: '1–4 hrs'),
  ];

  // ── NON-MEDICAL categories with subcategories ──────────────────────────────
  static const _nonMedicalCategories = [
    _NMCategory(
      name: 'Childcare & Family Support',
      emoji: '👶',
      color: Color(0xFFE91E8C),
      description: 'Babysitting, nannies, school runs and holiday childcare.',
      subs: [
        _NMSub('Babysitting Services',        '🍼', 'Short-term childcare while parents attend appointments or go out.',        'Flexible'),
        _NMSub('Nanny Services',              '👧', 'Regular childcare including supervision, activities and meal prep.',        'Daily'),
        _NMSub('After-School Support',        '🎒', 'Collecting children from school and supervising until parents return.',    '2–5 hrs'),
        _NMSub('School Run Services',         '🚌', 'Transporting children between home, school and approved activities.',      'Daily'),
        _NMSub('Holiday Childcare',           '🌞', 'Childcare support during school holidays.',                                'Flexible'),
      ],
    ),
    _NMCategory(
      name: 'Shopping & Errands',
      emoji: '🛒',
      color: Color(0xFF7B2FBE),
      description: 'Grocery runs, personal shopping, prescriptions and parcels.',
      subs: [
        _NMSub('Grocery Shopping',            '🥦', 'Purchasing groceries and household essentials to your list.',              '1–2 hrs'),
        _NMSub('Personal Shopping',           '🛍️', 'Helping clients purchase clothing, gifts and everyday products.',          'Flexible'),
        _NMSub('Errand Services',             '📬', 'Collecting or delivering items and completing agreed tasks.',              'Flexible'),
        _NMSub('Prescription Collection',     '💊', 'Collecting prescriptions on your behalf where legally permitted.',         'Same day'),
        _NMSub('Parcel Collection & Drop-Off','📦', 'Collecting or dropping off parcels and permitted items.',                 'Same day'),
      ],
    ),
    _NMCategory(
      name: 'Delivery & Transport',
      emoji: '🚗',
      color: Color(0xFF0077B6),
      description: 'Local and business deliveries, driver assistance.',
      subs: [
        _NMSub('Local Delivery',              '🏘️', 'Delivering food, groceries, documents and packages locally.',             'Same day'),
        _NMSub('Business Delivery',           '🏪', 'Scheduled deliveries for shops and small businesses.',                    'Scheduled'),
        _NMSub('Collection & Delivery',       '🔄', 'Collecting items from one location and delivering to another.',           'Flexible'),
        _NMSub('Driver/Delivery Assistant',   '🧑‍✈️', 'Personnel to assist businesses with deliveries.',                       'Flexible'),
        _NMSub('Personal Errand Driver',      '🗺️', 'Transportation for approved everyday errands.',                           'Flexible'),
      ],
    ),
    _NMCategory(
      name: 'Retail & Business Staffing',
      emoji: '🏪',
      color: Color(0xFFD4541A),
      description: 'Shop assistants, receptionists, admin and personal assistants.',
      subs: [
        _NMSub('Shop Assistants',             '🛒', 'Helping customers, arranging merchandise and restocking shelves.',         'Flexible'),
        _NMSub('Retail Assistants',           '🏷️', 'Customer service, stock support and general retail duties.',              'Flexible'),
        _NMSub('Cashier/Till Assistants',     '💳', 'Operating tills and assisting customers with purchases.',                  'Flexible'),
        _NMSub('Stock Assistants',            '📦', 'Receiving, organising and checking stock.',                                'Flexible'),
        _NMSub('Receptionists',               '📞', 'Greeting visitors, answering calls and handling admin duties.',            'Flexible'),
        _NMSub('Administrative Assistants',   '📁', 'Filing, scheduling, data entry and general administration.',              'Flexible'),
        _NMSub('Personal Assistants',         '🗂️', 'Supporting individuals or businesses with organisational tasks.',          'Flexible'),
      ],
    ),
    _NMCategory(
      name: 'Hospitality & Events',
      emoji: '🍽️',
      color: Color(0xFF2E7D32),
      description: 'Waitstaff, event crew, catering assistants and ushers.',
      subs: [
        _NMSub('Waiters & Waitresses',        '🍷', 'Serving customers, taking orders and providing table service.',           'Flexible'),
        _NMSub('Event Staff',                 '🎪', 'Guest reception, registration and general event operations.',             'Flexible'),
        _NMSub('Catering Assistants',         '🥗', 'Supporting catering teams with food-service operations.',                 'Flexible'),
        _NMSub('Front-of-House Staff',        '🤵', 'Welcoming guests and assisting customers at events and venues.',          'Flexible'),
        _NMSub('Bar/Service Staff',           '🍸', 'Customer-service and hospitality support.',                               'Flexible'),
        _NMSub('Ushering Services',           '🎟️', 'Directing and assisting guests at events and venues.',                    'Flexible'),
      ],
    ),
    _NMCategory(
      name: 'Home & Lifestyle',
      emoji: '🏠',
      color: Color(0xFF00838F),
      description: 'Companionship, pet sitting, house sitting and lifestyle help.',
      subs: [
        _NMSub('Stay-at-Home Support',        '🛋️', 'Present at home for agreed periods to provide non-medical assistance.',  'Flexible'),
        _NMSub('Companionship Services',      '💬', 'Conversation, social interaction and recreational activities.',           'Flexible'),
        _NMSub('Home Sitting',                '🔒', 'Remaining at a property while the owner is away.',                        'Flexible'),
        _NMSub('Pet Sitting',                 '🐾', 'Caring for pets while their owners are away.',                            'Flexible'),
        _NMSub('House Sitting',               '🏡', 'Providing a presence at a property while the owner is travelling.',       'Flexible'),
        _NMSub('Lifestyle Assistance',        '🗓️', 'Helping clients organise everyday non-medical activities.',               'Flexible'),
      ],
    ),
    _NMCategory(
      name: 'Moving & Assistance',
      emoji: '📦',
      color: Color(0xFF6D4C41),
      description: 'Packing, unpacking, moving-day help and concierge services.',
      subs: [
        _NMSub('Packing Assistance',          '📦', 'Helping clients pack belongings when moving or preparing for storage.',   '2–6 hrs'),
        _NMSub('Unpacking Assistance',        '🗃️', 'Helping organise belongings after moving.',                               '2–4 hrs'),
        _NMSub('Moving-Day Assistance',       '🚛', 'Practical assistance during a house or office move.',                    'Full day'),
        _NMSub('Event Set-Up Assistance',     '🎈', 'Preparing venues, tables, chairs and guest areas.',                      'Flexible'),
        _NMSub('Personal Concierge',          '🎩', 'Arranging everyday tasks, bookings, shopping and agreed services.',      'Flexible'),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _categories.length, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Groups each flat category into slider cards, reusing the service data above.
  static const _groupSpecs = <String, List<List<Object>>>{
    'Cleaning': [
      ['Home Cleaning', '🏠', 0xFF2980B9, 'Everyday and one-off cleaning for homes and flats.',
        'Domestic Cleaning|Deep Cleaning|End-of-Tenancy Cleaning|Move-In / Move-Out Cleaning|Laundry & Ironing'],
      ['Commercial & Hospitality', '🏢', 0xFF16A085, 'Offices, shops, hotels and shared spaces.',
        'Office Cleaning|Commercial Cleaning|Hotel & Hospitality Cleaning|Communal Area Cleaning'],
      ['Specialist & Contract', '✨', 0xFF5B4FCF, 'Post-build, event and scheduled contract cleaning.',
        'After-Builders Cleaning|Event Cleaning|Regular Contract Cleaning'],
    ],
    'Home Care': [
      ['Personal & Senior Care', '🫶', 0xFFE63329, 'Dignified, hands-on support for you or a loved one.',
        'Personal Care|Senior Care|Respite Care|Occupational Therapy'],
      ['Round-the-Clock Care', '🌙', 0xFF6B1E3C, 'Live-in and overnight care for constant peace of mind.',
        'Live-in Care|Night Care'],
      ['Daily Living Support', '🤝', 0xFFC2410C, 'Company, meals, medication and shopping help at home.',
        'Companionship|Medication Reminders|Meal Preparation|Shopping Assistance'],
    ],
    'Construction': [
      ['Plumbing & Electrical', '🔧', 0xFF1E8449, 'Qualified trades for repairs, installs and upgrades.',
        'Plumbing|Electrical Work|Handyman Services'],
      ['Building & Outdoor', '🏛️', 0xFFB9770E, 'Structural work, joinery, roofing and landscaping.',
        'General Building Work|Carpentry|Plastering|Roofing|Landscaping'],
      ['Interior & Finishes', '🖌️', 0xFF8E44AD, 'Painting, flooring, kitchens and bathrooms.',
        'Painting & Decorating|Interior Decoration|Flooring|Kitchen Fitting|Bathroom Installation'],
    ],
  };

  List<_NMCategory> _groupsFor(String cat) {
    final byName = {for (final s in _services) s.name: s};
    return (_groupSpecs[cat] ?? const []).map((g) {
      final subs = (g[4] as String)
          .split('|')
          .map((n) => byName[n])
          .whereType<_Service>()
          .map((s) => _NMSub(s.name, s.icon, s.desc, s.duration))
          .toList();
      return _NMCategory(
        name: g[0] as String,
        emoji: g[1] as String,
        color: Color(g[2] as int),
        description: g[3] as String,
        subs: subs,
      );
    }).toList();
  }

  List<_Service> _filtered(String cat) {
    return _services.where((s) {
      final matchCat   = cat == 'All' || s.cat == cat;
      final matchQuery = _query.isEmpty || s.name.toLowerCase().contains(_query.toLowerCase());
      return matchCat && matchQuery;
    }).toList();
  }

  Color _catColor(String cat) => switch (cat) {
    'Cleaning'     => const Color(0xFF2980B9),
    'Home Care'    => AppTheme.red,
    'Construction' => const Color(0xFF27AE60),
    _              => AppTheme.navy,
  };

  IconData _catIcon(String cat) => switch (cat) {
    'Cleaning'     => Icons.cleaning_services,
    'Home Care'    => Icons.favorite,
    'Construction' => Icons.construction,
    _              => Icons.star,
  };

  IconData _serviceIcon(String name) => switch (name) {
    'Domestic Cleaning'           => Icons.cleaning_services_outlined,
    'Deep Cleaning'               => Icons.auto_awesome_outlined,
    'End-of-Tenancy Cleaning'     => Icons.vpn_key_outlined,
    'Move-In / Move-Out Cleaning' => Icons.move_to_inbox_outlined,
    'Office Cleaning'             => Icons.business_outlined,
    'Commercial Cleaning'         => Icons.store_outlined,
    'Hotel & Hospitality Cleaning'=> Icons.hotel_outlined,
    'Communal Area Cleaning'      => Icons.apartment_outlined,
    'After-Builders Cleaning'     => Icons.construction_outlined,
    'Event Cleaning'              => Icons.celebration_outlined,
    'Regular Contract Cleaning'   => Icons.assignment_outlined,
    'Laundry & Ironing'           => Icons.local_laundry_service_outlined,
    'Personal Care'               => Icons.favorite,
    'Senior Care'                 => Icons.elderly,
    'Companionship'               => Icons.people_outline,
    'Medication Reminders'        => Icons.medication_outlined,
    'Meal Preparation'            => Icons.restaurant_outlined,
    'Shopping Assistance'         => Icons.shopping_cart_outlined,
    'Live-in Care'                => Icons.home_outlined,
    'Night Care'                  => Icons.nightlight_outlined,
    'Respite Care'                => Icons.spa_outlined,
    'Occupational Therapy'        => Icons.accessibility_new_outlined,
    'Plumbing'                    => Icons.plumbing_outlined,
    'Electrical Work'             => Icons.electrical_services_outlined,
    'Painting & Decorating'       => Icons.format_paint_outlined,
    'Interior Decoration'         => Icons.weekend_outlined,
    'General Building Work'       => Icons.foundation_outlined,
    'Carpentry'                   => Icons.carpenter_outlined,
    'Plastering'                  => Icons.home_outlined,
    'Roofing'                     => Icons.roofing_outlined,
    'Flooring'                    => Icons.grid_view_outlined,
    'Landscaping'                 => Icons.grass_outlined,
    'Kitchen Fitting'             => Icons.kitchen_outlined,
    'Bathroom Installation'       => Icons.bathtub_outlined,
    'Handyman Services'           => Icons.handyman_outlined,
    _                             => Icons.star_outline,
  };

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
            expandedHeight: 130,
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('SERVICES', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.white, letterSpacing: 1.5)),
                    const SizedBox(height: 10),
                    // Search
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.1),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: Colors.white.withOpacity(.12)),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search all services...',
                          hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                          suffixIcon: _query.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.close, color: Colors.white38, size: 16),
                                onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); })
                            : null,
                          border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
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
              tabs: _categories.map((c) => Tab(text: c)).toList(),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: _categories.map((cat) {
            // Animated card slider for each service category.
            // While searching, fall back to the flat results list.
            if (cat == 'Non-Medical') {
              return _NonMedicalView(
                title: 'Non-Medical Services',
                bookingCategory: 'Non-Medical',
                categories: _nonMedicalCategories,
              );
            }
            if (_query.isEmpty && (cat == 'Cleaning' || cat == 'Home Care' || cat == 'Construction')) {
              return _NonMedicalView(
                title: '$cat Services',
                bookingCategory: cat,
                categories: _groupsFor(cat),
              );
            }

            final items = _filtered(cat);
            if (items.isEmpty) {
              return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.search_off_rounded, size: 40, color: AppTheme.textMute),
                const SizedBox(height: 12),
                Text('No services found', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMute)),
              ]));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: items.length,
              itemBuilder: (_, i) => FadeSlideIn(
                index: i,
                child: PressScale(child: _ServiceCard(
                service:  items[i],
                icon: _serviceIcon(items[i].name),
                catColor: _catColor(items[i].cat),
                catIcon: _catIcon(items[i].cat),
                onBook: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => BookingScreen(service: items[i].name, icon: items[i].icon, category: items[i].cat),
                )),
              ))),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// NON-MEDICAL — ANIMATED CARD SLIDER VIEW
// ══════════════════════════════════════════
class _NonMedicalView extends StatefulWidget {
  final String title;
  final String bookingCategory;
  final List<_NMCategory> categories;
  const _NonMedicalView({required this.title, required this.bookingCategory, required this.categories});

  @override
  State<_NonMedicalView> createState() => _NonMedicalViewState();
}

class _NonMedicalViewState extends State<_NonMedicalView> {
  int _topIndex = 0;

  void _nextCard() {
    setState(() => _topIndex = (_topIndex + 1) % widget.categories.length);
  }

  void _prevCard() {
    setState(() => _topIndex = (_topIndex - 1 + widget.categories.length) % widget.categories.length);
  }

  void _openSubcategories(_NMCategory cat) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _SubcategoryScreen(category: cat, bookingCategory: widget.bookingCategory),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories;
    final count = cats.length;

    return Column(children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.title, style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.navyDark)),
            Text('Tap a card to explore — swipe or use arrows to browse',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
          ])),
          // Dot indicators
          Row(children: List.generate(count, (i) {
            final active = i == _topIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(left: 4),
              width: active ? 18 : 6, height: 6,
              decoration: BoxDecoration(
                color: active ? cats[_topIndex].color : AppTheme.border,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          })),
        ]),
      ),

      // Card stack
      Expanded(
        child: GestureDetector(
          onHorizontalDragEnd: (d) {
            if (d.primaryVelocity != null) {
              if (d.primaryVelocity! < -200) _nextCard();
              if (d.primaryVelocity! > 200)  _prevCard();
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (int offset = 3; offset >= 1; offset--)
                _buildStackedCard(cats, count, offset),
              _buildFrontCard(cats[_topIndex]),
            ],
          ),
        ),
      ),

      // Arrow navigation
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _ArrowBtn(icon: Icons.arrow_back_ios_rounded, onTap: _prevCard),
          Text('${_topIndex + 1} / $count',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMute)),
          _ArrowBtn(icon: Icons.arrow_forward_ios_rounded, onTap: _nextCard),
        ]),
      ),
    ]);
  }

  Widget _buildStackedCard(List<_NMCategory> cats, int count, int offset) {
    final idx = (_topIndex + offset) % count;
    final cat = cats[idx];
    final translateY = offset * 10.0;
    final scale = 1.0 - offset * 0.04;
    final rotateZ = offset % 2 == 0 ? -0.025 * offset : 0.025 * offset;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translate(0.0, translateY)
        ..scale(scale)
        ..rotateZ(rotateZ),
      child: _CardShell(color: cat.color, opacity: 0.6 - offset * 0.1),
    );
  }

  Widget _buildFrontCard(_NMCategory cat) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      child: GestureDetector(
        key: ValueKey(_topIndex),
        onTap: () => _openSubcategories(cat),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [cat.color, cat.color.withOpacity(.75)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: cat.color.withOpacity(.45), blurRadius: 28, offset: const Offset(0, 12)),
            ],
          ),
          child: Stack(children: [
            Positioned(top: -30, right: -30,
              child: Container(width: 140, height: 140,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Colors.white.withOpacity(.08)))),
            Positioned(bottom: -40, left: -20,
              child: Container(width: 180, height: 180,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Colors.white.withOpacity(.05)))),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('0${_topIndex + 1}',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
                ),
                const SizedBox(height: 20),
                Text(cat.emoji, style: const TextStyle(fontSize: 52)),
                const SizedBox(height: 16),
                Text(cat.name, style: GoogleFonts.poppins(
                  fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15)),
                const SizedBox(height: 10),
                Text(cat.description, style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w300, height: 1.6)),
                const Spacer(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${cat.subs.length} services',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// Shell for background stacked cards
class _CardShell extends StatelessWidget {
  final Color color;
  final double opacity;
  const _CardShell({required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: double.infinity,
      decoration: BoxDecoration(
        color: color.withOpacity(opacity.clamp(0.0, 1.0)),
        borderRadius: BorderRadius.circular(28),
      ),
    );
  }
}

// Arrow button
class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: AppTheme.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Icon(icon, size: 18, color: AppTheme.navy),
      ),
    );
  }
}

// ══════════════════════════════════════════
// SUBCATEGORY SCREEN
// ══════════════════════════════════════════
class _SubcategoryScreen extends StatelessWidget {
  final _NMCategory category;
  final String bookingCategory;
  const _SubcategoryScreen({required this.category, required this.bookingCategory});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: category.color,
          iconTheme: const IconThemeData(color: Colors.white),
          expandedHeight: 160,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(children: [
              Positioned(top: -20, right: -20,
                child: Container(width: 160, height: 160,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(.08)))),
              SafeArea(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(category.emoji, style: const TextStyle(fontSize: 40)),
                  const SizedBox(height: 6),
                  Text(category.name, style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                  Text(category.description, style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w300)),
                  const SizedBox(height: 14),
                ]),
              )),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(14),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final sub = category.subs[i];
                return _SubCard(
                  sub: sub,
                  color: category.color,
                  onBook: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BookingScreen(service: sub.name, icon: sub.emoji, category: bookingCategory),
                  )),
                );
              },
              childCount: category.subs.length,
            ),
          ),
        ),
      ]),
    );
  }
}

// Subcategory card
class _SubCard extends StatelessWidget {
  final _NMSub sub;
  final Color color;
  final VoidCallback onBook;
  const _SubCard({required this.sub, required this.color, required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Container(height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(sub.emoji, style: const TextStyle(fontSize: 26))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sub.name, style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 0.3)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.schedule_outlined, size: 12, color: AppTheme.textMute),
                  const SizedBox(width: 4),
                  Text(sub.duration, style: GoogleFonts.inter(
                    fontSize: 11, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
                ]),
              ])),
            ]),
            const SizedBox(height: 10),
            Text(sub.desc, style: GoogleFonts.inter(
              fontSize: 13, color: AppTheme.textMid, fontWeight: FontWeight.w300, height: 1.55)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: Text('Book This Service',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// MODELS
// ══════════════════════════════════════════
class _Service {
  final String name;
  final String icon;
  final String cat;
  final String desc;
  final String duration;
  const _Service({required this.name, required this.icon, required this.cat, required this.desc, required this.duration});
}

class _NMCategory {
  final String name;
  final String emoji;
  final Color  color;
  final String description;
  final List<_NMSub> subs;
  const _NMCategory({required this.name, required this.emoji, required this.color, required this.description, required this.subs});
}

class _NMSub {
  final String name;
  final String emoji;
  final String desc;
  final String duration;
  const _NMSub(this.name, this.emoji, this.desc, this.duration);
}

// ══════════════════════════════════════════
// SERVICE CARD (Cleaning / Home Care / Construction)
// ══════════════════════════════════════════
class _ServiceCard extends StatelessWidget {
  final _Service    service;
  final IconData    icon;
  final Color       catColor;
  final IconData    catIcon;
  final VoidCallback onBook;

  const _ServiceCard({required this.service, required this.icon, required this.catColor, required this.catIcon, required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Colour top accent
        Container(height: 4,
          decoration: BoxDecoration(
            color: catColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Icon box
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: catColor.withOpacity(.08), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Icon(icon, size: 26, color: catColor)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Category tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(bottom: 5),
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(catIcon, size: 10, color: catColor),
                    const SizedBox(width: 4),
                    Text(service.cat.toUpperCase(),
                      style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: catColor, letterSpacing: 0.8),
                    ),
                  ]),
                ),
                Text(service.name,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 0.3),
                ),
                const SizedBox(height: 4),
                // Duration badge
                Row(children: [
                  Icon(Icons.schedule_outlined, size: 12, color: AppTheme.textMute),
                  const SizedBox(width: 4),
                  Text(service.duration,
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMute, fontWeight: FontWeight.w300),
                  ),
                ]),
              ])),
            ]),
            const SizedBox(height: 10),
            Text(service.desc,
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMid, fontWeight: FontWeight.w300, height: 1.55),
            ),
          ]),
        ),
        // Book button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: catColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: Text('Book This Service',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.8),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
