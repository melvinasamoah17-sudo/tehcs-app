import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/booking.dart';
import 'booking_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _filters = ['All', 'Pending', 'Active', 'Complete'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _filters.length, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Stream<List<Booking>> _stream(String filter) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    var q = FirebaseFirestore.instance
        .collection('bookings')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true);
    if (filter != 'All') {
      q = q.where('status', isEqualTo: filter.toLowerCase());
    }
    return q.snapshots().map((s) => s.docs.map(Booking.fromFirestore).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.navyDark,
        automaticallyImplyLeading: false,
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
            Text('MY BOOKINGS', style: GoogleFonts.barlowCondensed(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.white, letterSpacing: 1.5)),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppTheme.gold,
          unselectedLabelColor: Colors.white54,
          indicatorColor: AppTheme.gold,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.barlowCondensed(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          unselectedLabelStyle: GoogleFonts.barlowCondensed(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: _filters.map((f) => Tab(text: f)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: _filters.map((filter) => _BookingList(stream: _stream(filter))).toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.white,
        icon: const Icon(Icons.add),
        label: Text('New Booking', style: GoogleFonts.barlowCondensed(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        onPressed: () => _showServicePicker(context),
      ),
    );
  }

  void _showServicePicker(BuildContext context) {
    final services = [
      {'name': 'Home Health Care', 'icon': '🩺'},
      {'name': 'Senior Care',      'icon': '👴'},
      {'name': 'Personal Care',    'icon': '🫶'},
      {'name': 'Plumbing',         'icon': '🔧'},
      {'name': 'Electrical Work',  'icon': '⚡'},
      {'name': 'Housekeeping',     'icon': '🏠'},
      {'name': 'Cook / Chef',      'icon': '👨‍🍳'},
      {'name': 'Driver',           'icon': '🚗'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16), decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
            Text('SELECT SERVICE', style: GoogleFonts.barlowCondensed(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 1)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: services.length,
                itemBuilder: (ctx, i) {
                  final s = services[i];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BookingScreen(service: s['name']!, icon: s['icon']!)));
                    },
                    child: Container(
                      decoration: BoxDecoration(color: AppTheme.offWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(s['icon']!, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 6),
                        Text(s['name']!, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.barlowCondensed(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.navy, height: 1.2),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final Stream<List<Booking>> stream;
  const _BookingList({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.navy));
        }
        final bookings = snap.data ?? [];
        if (bookings.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('📋', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text('No bookings here yet.', style: GoogleFonts.barlowCondensed(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMute)),
              const SizedBox(height: 6),
              Text('Tap + New Booking to get started.', style: GoogleFonts.nunito(fontSize: 13, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
            ]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (ctx, i) => _BookingDetailCard(booking: bookings[i]),
        );
      },
    );
  }
}

class _BookingDetailCard extends StatelessWidget {
  final Booking booking;
  const _BookingDetailCard({required this.booking});

  Color get _color => switch (booking.status) {
    'active'   => AppTheme.green,
    'complete' => AppTheme.navy,
    _          => AppTheme.goldDark,
  };

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
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.navy.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(booking.icon, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.service,
                      style: GoogleFonts.barlowCondensed(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 0.3),
                    ),
                    Text('Booked by ${booking.clientName}',
                      style: GoogleFonts.nunito(fontSize: 11, color: AppTheme.textMute, fontWeight: FontWeight.w300),
                    ),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(100)),
                  child: Text(booking.status.toUpperCase(),
                    style: GoogleFonts.barlowCondensed(fontSize: 10, fontWeight: FontWeight.w800, color: _color, letterSpacing: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _row(Icons.calendar_today_outlined, 'Date',    booking.date.isEmpty ? 'TBD' : booking.date),
                _row(Icons.access_time_outlined,    'Time',    booking.time.isEmpty ? 'Flexible' : booking.time),
                _row(Icons.location_on_outlined,    'Address', booking.address),
                _row(Icons.phone_outlined,          'Phone',   booking.phone),
                if (booking.notes.isNotEmpty)
                  _row(Icons.notes_outlined, 'Notes', booking.notes),
              ],
            ),
          ),

          // Progress bar for active
          if (booking.status == 'active') ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('IN PROGRESS', style: GoogleFonts.barlowCondensed(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.green, letterSpacing: 0.8)),
                    Text('60%', style: GoogleFonts.barlowCondensed(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.green)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.6,
                      backgroundColor: AppTheme.light,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.green),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppTheme.textMute),
        const SizedBox(width: 8),
        Text('$label: ', style: GoogleFonts.barlowCondensed(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMid, letterSpacing: 0.3)),
        Expanded(child: Text(value, style: GoogleFonts.nunito(fontSize: 12, color: AppTheme.textMid, fontWeight: FontWeight.w300))),
      ],
    ),
  );
}