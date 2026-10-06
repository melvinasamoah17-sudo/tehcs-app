import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../booking_screen.dart';

IconData _constructionServiceIcon(String name) => switch (name) {
  'Plumbing'                 => Icons.plumbing_outlined,
  'Electrical Work'          => Icons.electrical_services_outlined,
  'Painting & Decorating'    => Icons.format_paint_outlined,
  'General Building Work'    => Icons.foundation_outlined,
  'Carpentry'                => Icons.carpenter_outlined,
  'Plastering'               => Icons.home_outlined,
  'Roofing'                  => Icons.roofing_outlined,
  'Flooring'                 => Icons.grid_view_outlined,
  'Landscaping'               => Icons.grass_outlined,
  'Kitchen Fitting'          => Icons.kitchen_outlined,
  'Bathroom Installation'    => Icons.bathtub_outlined,
  'Handyman Services'        => Icons.handyman_outlined,
  'Interior Decoration'      => Icons.weekend_outlined,
  _                          => Icons.construction_outlined,
};

class ConstructionHomeScreen extends StatefulWidget {
  const ConstructionHomeScreen({super.key});
  @override
  State<ConstructionHomeScreen> createState() => _ConstructionHomeScreenState();
}

class _ConstructionHomeScreenState extends State<ConstructionHomeScreen> {
  static const _services = [
    {'icon': '🔧', 'name': 'Plumbing',              'desc': 'Licensed plumbers for repairs, installations and emergency leaks.', 'duration': 'Flexible'},
    {'icon': '⚡', 'name': 'Electrical Work',        'desc': 'Certified electricians for safe wiring and compliance work.',       'duration': 'Flexible'},
    {'icon': '🖌️','name': 'Painting & Decorating',  'desc': 'Interior and exterior painting using premium finishes.',             'duration': '1–5 days'},
    {'icon': '🏛️','name': 'General Building Work',  'desc': 'Full building and renovation managed end-to-end by our team.',     'duration': 'Project'},
    {'icon': '🪚', 'name': 'Carpentry',              'desc': 'Custom carpentry for furniture, fittings and bespoke woodwork.',    'duration': 'Flexible'},
    {'icon': '🏠', 'name': 'Plastering',             'desc': 'Skim, patch and full-room plastering for smooth wall finishes.',    'duration': '1–3 days'},
    {'icon': '🏚️','name': 'Roofing',                'desc': 'Roof repairs, replacement and inspection by specialists.',           'duration': 'Flexible'},
    {'icon': '⬛', 'name': 'Flooring',               'desc': 'Supply and fitting of laminate, hardwood, vinyl and tile.',         'duration': '1–3 days'},
    {'icon': '🌿', 'name': 'Landscaping',            'desc': 'Garden design, lawn care, pruning and outdoor maintenance.',        'duration': 'Flexible'},
    {'icon': '🍽️','name': 'Kitchen Fitting',        'desc': 'Full kitchen installation including units, worktops and plumbing.',  'duration': '3–7 days'},
    {'icon': '🚿', 'name': 'Bathroom Installation',  'desc': 'Complete bathroom fitting — tiling, plumbing and fixtures.',        'duration': '3–5 days'},
    {'icon': '🔨', 'name': 'Handyman Services',      'desc': 'Odd jobs, small repairs and home maintenance tasks.',               'duration': '1–4 hrs'},
    {'icon': '🛋️','name': 'Interior Decoration',    'desc': 'Styling, colour consultation and finishing touches for your space.', 'duration': 'Flexible'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildQuoteCard(context)),
          SliverToBoxAdapter(child: _buildFeatures()),
          SliverToBoxAdapter(child: _sectionLabel('OUR SERVICES')),
          SliverList(delegate: SliverChildBuilderDelegate(
            (_, i) => _ServiceCard(s: _services[i], color: const Color(0xFF27AE60),
              onBook: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => BookingScreen(service: _services[i]['name'] as String, icon: _services[i]['icon'] as String, category: 'Construction')))),
            childCount: _services.length,
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1A3A1A), Color(0xFF27AE60)]),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context)),
            const Spacer(),
          ]),
          const Icon(Icons.construction, size: 48, color: Colors.white),
          const SizedBox(height: 10),
          Text('Construction Services', style: GoogleFonts.poppins(
            fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text('Building, renovating and maintaining properties across the UK and beyond.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w300, height: 1.6)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: ElevatedButton(
              onPressed: () => _showQuoteSheet(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1A3A1A),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: const StadiumBorder(), elevation: 0),
              child: Text('Get Free Quote', style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            )),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const BookingScreen(service: 'Handyman Services', icon: '🔨', category: 'Construction'))),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 12), shape: const StadiumBorder()),
              child: Text('Book a Job', style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            )),
          ]),
        ]),
      )),
    );
  }

  Widget _buildQuoteCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _showQuoteSheet(context),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF27AE60).withOpacity(.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF27AE60).withOpacity(.25)),
        ),
        child: Row(children: [
          const Icon(Icons.assignment_outlined, size: 32, color: Color(0xFF27AE60)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Request a Free Quote', style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 0.3)),
            const SizedBox(height: 4),
            Text('Describe your project, upload photos and we\'ll get back to you within 24 hours.',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMid, fontWeight: FontWeight.w300, height: 1.5)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.textMute),
        ]),
      ),
    );
  }

  Widget _buildFeatures() {
    final items = [
      {'icon': Icons.verified_user_outlined, 'text': 'Licensed tradespeople'},
      {'icon': Icons.shield_outlined, 'text': 'Fully insured'},
      {'icon': Icons.star, 'text': 'Quality guaranteed'},
      {'icon': Icons.credit_card, 'text': 'Stage payments'},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: items.asMap().entries.map((e) => Expanded(
        child: Container(
          margin: EdgeInsets.only(right: e.key < items.length - 1 ? 8 : 0),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border)),
          child: Column(children: [
            Icon(e.value['icon'] as IconData, size: 22, color: const Color(0xFF27AE60)),
            const SizedBox(height: 6),
            Text(e.value['text'] as String, textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textMute, fontWeight: FontWeight.w300, height: 1.4)),
          ]),
        ),
      )).toList()),
    );
  }

  void _showQuoteSheet(BuildContext context) {
    final descCtrl    = TextEditingController();
    final addressCtrl = TextEditingController();
    final budgetCtrl  = TextEditingController();
    List<File> photos = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: const EdgeInsets.all(22),
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              Text('REQUEST A QUOTE', style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 1)),
              const SizedBox(height: 16),

              _label('Describe the Job'),
              TextField(controller: descCtrl, maxLines: 4,
                decoration: _deco('What work needs to be done?...')),
              const SizedBox(height: 12),

              _label('Property Address'),
              TextField(controller: addressCtrl,
                decoration: _deco('Full address including postcode')),
              const SizedBox(height: 12),

              _label('Budget (optional)'),
              TextField(controller: budgetCtrl, keyboardType: TextInputType.number,
                decoration: _deco('e.g. £500–£1000')),
              const SizedBox(height: 14),

              _label('Upload Photos (optional)'),
              GestureDetector(
                onTap: () async {
                  final picked = await ImagePicker().pickMultiImage(imageQuality: 70);
                  setSheet(() => photos = picked.map((x) => File(x.path)).toList());
                },
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppTheme.offWhite, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border, style: BorderStyle.solid)),
                  child: Column(children: [
                    const Icon(Icons.add_photo_alternate_outlined, color: AppTheme.textMute, size: 28),
                    const SizedBox(height: 6),
                    Text(photos.isEmpty ? 'Tap to add photos' : '${photos.length} photo${photos.length != 1 ? 's' : ''} selected',
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMute)),
                  ]),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null || descCtrl.text.isEmpty) return;
                    await FirebaseFirestore.instance.collection('quote_requests').add({
                      'uid':         user.uid,
                      'clientName':  user.displayName ?? '',
                      'clientEmail': user.email ?? '',
                      'description': descCtrl.text.trim(),
                      'address':     addressCtrl.text.trim(),
                      'budget':      budgetCtrl.text.trim(),
                      'photoCount':  photos.length,
                      'status':      'pending',
                      'createdAt':   FieldValue.serverTimestamp(),
                    });
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Quote request sent! We\'ll contact you within 24 hours.'),
                      backgroundColor: AppTheme.green, behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27AE60), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(), elevation: 0),
                  child: Text('Submit Quote Request', style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                ),
              ),
            ])),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(t.toUpperCase(), style: GoogleFonts.poppins(
      fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMute, letterSpacing: 1.2)),
  );

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMute, fontWeight: FontWeight.w300),
    filled: true, fillColor: AppTheme.offWhite,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.navy, width: 1.5)),
    contentPadding: const EdgeInsets.all(13),
  );

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
              child: Center(child: Icon(_constructionServiceIcon(s['name'] as String), size: 24, color: color))),
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
