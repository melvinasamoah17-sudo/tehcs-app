import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// Bell with an unread badge for the admin portal. Opens a list of recent
/// staff activity and pops a snackbar when a new one arrives live.
class AdminNotificationBell extends StatefulWidget {
  const AdminNotificationBell({super.key});
  @override
  State<AdminNotificationBell> createState() => _AdminNotificationBellState();
}

class _AdminNotificationBellState extends State<AdminNotificationBell> {
  late final Stream<QuerySnapshot> _stream;
  String? _lastTopId;
  bool _first = true;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  IconData _icon(String type) => switch (type) {
        'job_accepted' => Icons.check_circle_outline,
        'clock_in'     => Icons.login_rounded,
        _              => Icons.notifications_none,
      };

  Color _color(String type) => switch (type) {
        'job_accepted' => AppTheme.green,
        'clock_in'     => AppTheme.gold,
        _              => AppTheme.navy,
      };

  void _maybeToast(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return;
    final top = docs.first;
    final d = top.data() as Map<String, dynamic>;
    final isNew = !_first && top.id != _lastTopId && d['read'] == false;
    _first = false;
    _lastTopId = top.id;
    if (!isNew) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${d['title'] ?? 'Update'} — ${d['body'] ?? ''}'),
        backgroundColor: AppTheme.navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    });
  }

  Future<void> _markAllRead(List<QueryDocumentSnapshot> docs) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final d in docs) {
      if ((d.data() as Map)['read'] == false) {
        batch.update(d.reference, {'read': true});
      }
    }
    try { await batch.commit(); } catch (_) {}
  }

  void _open(List<QueryDocumentSnapshot> docs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: .7,
        minChildSize: .4,
        maxChildSize: .92,
        expand: false,
        builder: (_, scroll) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(children: [
            const SizedBox(height: 10),
            Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
              child: Row(children: [
                Expanded(child: Text('STAFF ACTIVITY', style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.navy, letterSpacing: 1))),
                TextButton(
                  onPressed: () { _markAllRead(docs); Navigator.pop(ctx); },
                  child: Text('Mark all read', style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.goldDark)),
                ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: docs.isEmpty
                  ? Center(child: Text('No activity yet', style: GoogleFonts.inter(color: AppTheme.textMute)))
                  : ListView.separated(
                      controller: scroll,
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        final type = d['type'] as String? ?? '';
                        final unread = d['read'] == false;
                        final at = (d['createdAt'] as Timestamp?)?.toDate();
                        return ListTile(
                          onTap: () { if (unread) docs[i].reference.update({'read': true}); },
                          tileColor: unread ? _color(type).withOpacity(.06) : null,
                          leading: CircleAvatar(
                            backgroundColor: _color(type).withOpacity(.12),
                            child: Icon(_icon(type), color: _color(type), size: 20),
                          ),
                          title: Text(d['title'] ?? '', style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: unread ? FontWeight.w800 : FontWeight.w600, color: AppTheme.navy)),
                          subtitle: Text(
                            '${d['body'] ?? ''}${at != null ? '\n${DateFormat('d MMM, HH:mm').format(at)}' : ''}',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMid, height: 1.4)),
                          isThreeLine: at != null,
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        _maybeToast(docs);
        final unread = docs.where((d) => (d.data() as Map)['read'] == false).length;
        return IconButton(
          onPressed: () => _open(docs),
          icon: Stack(clipBehavior: Clip.none, children: [
            const Icon(Icons.notifications_none_rounded, color: Colors.white70, size: 24),
            if (unread > 0)
              Positioned(
                right: -4, top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: AppTheme.red, borderRadius: BorderRadius.circular(10)),
                  child: Text(unread > 9 ? '9+' : '$unread',
                    style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
          ]),
        );
      },
    );
  }
}
