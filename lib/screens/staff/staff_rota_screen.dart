import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class StaffRotaScreen extends StatefulWidget {
  const StaffRotaScreen({super.key});
  @override
  State<StaffRotaScreen> createState() => _StaffRotaScreenState();
}

class _StaffRotaScreenState extends State<StaffRotaScreen> {
  final _uid       = FirebaseAuth.instance.currentUser?.uid;
  DateTime _weekStart = _getWeekStart(DateTime.now());
  DateTime _selected  = DateTime.now();

  static DateTime _getWeekStart(DateTime d) {
    return d.subtract(Duration(days: d.weekday - 1));
  }

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  void _prevWeek() => setState(() {
    _weekStart = _weekStart.subtract(const Duration(days: 7));
    _selected  = _weekStart;
  });

  void _nextWeek() => setState(() {
    _weekStart = _weekStart.add(const Duration(days: 7));
    _selected  = _weekStart;
  });

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isSelected(DateTime d) =>
      d.year == _selected.year && d.month == _selected.month && d.day == _selected.day;

  String _dayLabel(DateTime d) => DateFormat('d MMM yyyy').format(d);
  String _dayOfWeek(DateTime d) => DateFormat('EEE').format(d).toUpperCase();
  String _dayNum(DateTime d)    => DateFormat('d').format(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(children: [
        // ── HEADER ──
        _buildHeader(),
        // ── WEEK STRIP ──
        _buildWeekStrip(),
        // ── SELECTED DAY JOBS ──
        Expanded(child: _buildDayJobs()),
      ]),
    );
  }

  // ─────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────
  Widget _buildHeader() {
    final monthRange =
        '${DateFormat('d MMM').format(_weekStart)} – ${DateFormat('d MMM yyyy').format(_weekStart.add(const Duration(days: 6)))}';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppTheme.navyDark, AppTheme.navy]),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('MY ROTA', style: GoogleFonts.poppins(
                fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
              // Today button
              GestureDetector(
                onTap: () => setState(() {
                  _weekStart = _getWeekStart(DateTime.now());
                  _selected  = DateTime.now();
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withOpacity(.2),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppTheme.gold.withOpacity(.4)),
                  ),
                  child: Text('TODAY', style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.gold, letterSpacing: 1)),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            // Week navigator
            Row(children: [
              GestureDetector(
                onTap: _prevWeek,
                child: const Icon(Icons.chevron_left, color: Colors.white54, size: 22)),
              const SizedBox(width: 6),
              Text(monthRange, style: GoogleFonts.inter(
                fontSize: 13, color: Colors.white60, fontWeight: FontWeight.w300)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _nextWeek,
                child: const Icon(Icons.chevron_right, color: Colors.white54, size: 22)),
            ]),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // WEEK STRIP
  // ─────────────────────────────────────────
  Widget _buildWeekStrip() {
    return Container(
      color: AppTheme.navyDark,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Row(
        children: _weekDays.map((day) {
          final today    = _isToday(day);
          final selected = _isSelected(day);
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selected = day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                    ? AppTheme.gold
                    : today
                      ? Colors.white.withOpacity(.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: today && !selected
                    ? Border.all(color: AppTheme.gold.withOpacity(.4))
                    : null,
                ),
                child: Column(children: [
                  Text(_dayOfWeek(day), style: GoogleFonts.poppins(
                    fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5,
                    color: selected ? AppTheme.navyDark : today ? AppTheme.gold : Colors.white38)),
                  const SizedBox(height: 4),
                  Text(_dayNum(day), style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w900,
                    color: selected ? AppTheme.navyDark : today ? Colors.white : Colors.white60)),
                  // Dot indicator (has jobs)
                  _buildDotIndicator(day, selected),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDotIndicator(DateTime day, bool selected) {
    if (_uid == null) return const SizedBox(height: 6);
    final dateStr = DateFormat('dd/MM/yyyy').format(day);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bookings')
        .where('assignedStaffId', isEqualTo: _uid)
        .where('date', isEqualTo: dateStr)
        .snapshots(),
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;
        return SizedBox(
          height: 6,
          child: count > 0
            ? Row(mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(count.clamp(0, 3), (_) => Container(
                  width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.navyDark.withOpacity(.5) : AppTheme.gold,
                    shape: BoxShape.circle,
                  ),
                )))
            : const SizedBox.shrink(),
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // DAY JOBS
  // ─────────────────────────────────────────
  Widget _buildDayJobs() {
    if (_uid == null) return const Center(child: Text('Not signed in'));
    final dateStr = DateFormat('dd/MM/yyyy').format(_selected);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bookings')
        .where('assignedStaffId', isEqualTo: _uid)
        .where('date', isEqualTo: dateStr)
        .orderBy('time')
        .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2));
        }
        final docs = snap.data?.docs ?? [];

        return Column(children: [
          // Day summary bar
          Container(
            color: AppTheme.light,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(children: [
              Text(_dayLabel(_selected),
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.navy, letterSpacing: 0.3)),
              const Spacer(),
              Text('${docs.length} job${docs.length != 1 ? 's' : ''}',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMute, letterSpacing: 0.3)),
            ]),
          ),

          if (docs.isEmpty)
            Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.calendar_month_outlined, size: 48, color: AppTheme.textMute),
              const SizedBox(height: 14),
              Text('No shifts on this day', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMute)),
              const SizedBox(height: 6),
              Text('Select another day to view your schedule', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
            ])))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  return _RotaJobCard(data: data, docId: docs[i].id, index: i);
                },
              ),
            ),

          // Leave request button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showLeaveRequest(context),
                icon: const Icon(Icons.event_busy_outlined, size: 18),
                label: Text('Request Leave / Day Off',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.navy,
                  side: const BorderSide(color: AppTheme.border, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }

  void _showLeaveRequest(BuildContext context) {
    final reasonCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('REQUEST LEAVE', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text('Date: ${_dayLabel(_selected)}', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
            const SizedBox(height: 16),
            Text('REASON', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMute, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Briefly describe the reason...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMute, fontWeight: FontWeight.w300),
                filled: true, fillColor: AppTheme.offWhite,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.navy, width: 1.5)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (_uid == null) return;
                  await FirebaseFirestore.instance.collection('leave_requests').add({
                    'uid':    _uid,
                    'date':   DateFormat('dd/MM/yyyy').format(_selected),
                    'reason': reasonCtrl.text.trim(),
                    'status': 'pending',
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Leave request submitted ✓'),
                    backgroundColor: AppTheme.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navy, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(), elevation: 0,
                ),
                child: Text('Submit Request', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// ROTA JOB CARD
// ══════════════════════════════════════════
class _RotaJobCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final int index;
  const _RotaJobCard({required this.data, required this.docId, required this.index});

  Color get _statusColor => switch (data['status'] as String? ?? '') {
    'active'    => AppTheme.green,
    'complete'  => AppTheme.navy,
    'cancelled' => AppTheme.red,
    _           => AppTheme.goldDark,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Time column
          SizedBox(width: 60,
            child: Column(children: [
              Text(data['time'] ?? '--:--', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.navy)),
              const SizedBox(height: 4),
              Expanded(child: Container(width: 2, color: _statusColor.withOpacity(.3))),
            ]),
          ),
          const SizedBox(width: 10),
          // Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _statusColor.withOpacity(.25), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 6)],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(data['icon'] ?? '📋', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(data['service'] ?? '', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 0.3)),
                    Text(data['clientName'] ?? '', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: _statusColor.withOpacity(.1), borderRadius: BorderRadius.circular(100)),
                    child: Text((data['status'] ?? 'pending').toString().toUpperCase(),
                      style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: _statusColor, letterSpacing: 0.5)),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.schedule_outlined, size: 12, color: AppTheme.textMute),
                  const SizedBox(width: 4),
                  Text('${data['hours'] ?? 0} hour${(data['hours'] ?? 0) != 1 ? 's' : ''}',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
                  const SizedBox(width: 12),
                  if ((data['address'] ?? '').toString().isNotEmpty) ...[
                    Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textMute),
                    const SizedBox(width: 4),
                    Expanded(child: Text(data['address'],
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMute, fontWeight: FontWeight.w300),
                      overflow: TextOverflow.ellipsis)),
                  ],
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
