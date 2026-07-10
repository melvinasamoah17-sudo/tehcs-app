import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/booking.dart';
import '../services/session_control.dart';
import 'admin_messages_screen.dart';

class AdminPanel extends StatefulWidget {
  final String mode; // 'admin' or 'staff'
  const AdminPanel({super.key, this.mode = 'staff'});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late String currentMode;
  final String primaryAdminEmail = 'twitchempireinfo@gmail.com';
  DateTime? _pausedAt;

  bool get isPrimaryAdmin => FirebaseAuth.instance.currentUser?.email == primaryAdminEmail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // If not primary admin but mode is admin, force staff mode.
    // Resolved ONCE here so it stays in sync with the TabController length.
    currentMode = (!isPrimaryAdmin && widget.mode == 'admin') ? 'staff' : widget.mode;
    _tabController = TabController(length: currentMode == 'admin' ? 3 : 2, vsync: this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null && DateTime.now().difference(pausedAt) >= kAutoSignOutThreshold) {
        performForceSignOut(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If not primary admin but mode is admin, force staff mode
    final currentMode = (!isPrimaryAdmin && widget.mode == 'admin') ? 'staff' : widget.mode;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) handleGuardedBackPress(context);
      },
      child: Scaffold(
        backgroundColor: AppTheme.offWhite,
        appBar: AppBar(
          backgroundColor: AppTheme.navyDark,
          title: Text(currentMode == 'admin' ? 'ADMIN PORTAL' : 'STAFF VIEW',
              style: GoogleFonts.barlowCondensed(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.white, letterSpacing: 1.5)
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Sign Out',
              onPressed: () => performForceSignOut(context),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.gold,
            labelColor: AppTheme.gold,
            unselectedLabelColor: Colors.white60,
            tabs: [
              const Tab(text: 'ALL BOOKINGS'),
              const Tab(text: 'MESSAGES'),
              if (currentMode == 'admin') const Tab(text: 'STAFF MANAGEMENT'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildBookingsTab(),
            const AdminMessagesScreen(),
            if (currentMode == 'admin') _buildStaffTab(),
          ],
        ),
      ),
    );
  }
  Widget _buildBookingsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bookings').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No bookings found.'));
        }

        final bookings = snapshot.data!.docs.map((doc) => Booking.fromFirestore(doc)).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            final docId = snapshot.data!.docs[index].id;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                leading: Text(booking.icon, style: const TextStyle(fontSize: 24)),
                title: Text(booking.service, style: GoogleFonts.barlowCondensed(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('Client: ${booking.clientName}', style: const TextStyle(fontSize: 12)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow(Icons.person, 'Client', booking.clientName),
                        _infoRow(Icons.email, 'Email', booking.clientEmail),
                        _infoRow(Icons.phone, 'Phone', booking.phone),
                        _infoRow(Icons.calendar_today, 'Date', booking.date),
                        _infoRow(Icons.access_time, 'Time', booking.time),
                        _infoRow(Icons.location_on, 'Address', booking.address),
                        if (booking.notes.isNotEmpty) _infoRow(Icons.notes, 'Notes', booking.notes),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Status: ${booking.status.toUpperCase()}',
                                style: TextStyle(color: booking.statusColor, fontWeight: FontWeight.bold, fontSize: 12)
                            ),
                            PopupMenuButton<String>(
                              onSelected: (val) => _updateStatus(docId, val),
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'pending', child: Text('Set Pending')),
                                const PopupMenuItem(value: 'active', child: Text('Set Active')),
                                const PopupMenuItem(value: 'complete', child: Text('Set Complete')),
                              ],
                              child: Chip(
                                label: const Text('Update Status', style: TextStyle(fontSize: 10)),
                                backgroundColor: AppTheme.gold.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppTheme.textMute),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String docId, String status) async {
    try {
      await FirebaseFirestore.instance.collection('bookings').doc(docId).update({'status': status});
    } catch (e) {
      debugPrint('Update status error: $e');
    }
  }

  Widget _buildStaffTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _showAddStaffDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Staff Member'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy, foregroundColor: Colors.white),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('staff').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No staff members yet.'));
              }

              final staff = snapshot.data!.docs;
              return ListView.builder(
                itemCount: staff.length,
                itemBuilder: (context, index) {
                  final data = staff[index].data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'No Name';
                  final email = data['email'] ?? 'No Email';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.navy,
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(name),
                    subtitle: Text(email),
                    trailing: PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'delete') _deleteStaff(staff[index].id, email);
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'delete', child: Text('Remove Staff', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddStaffDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Staff Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
            const SizedBox(height: 8),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && emailCtrl.text.isNotEmpty) {
                _addStaff(nameCtrl.text.trim(), emailCtrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addStaff(String name, String email) async {
    final emailLower = email.trim().toLowerCase();
    try {
      // staff_by_email is the document our security rules (and the app's
      // role-based routing) actually check, keyed by email since a newly
      // added staff member may not have signed up yet.
      await FirebaseFirestore.instance.collection('staff_by_email').doc(emailLower).set({
        'name': name,
        'email': emailLower,
        'role': 'staff',
        'addedAt': FieldValue.serverTimestamp(),
      });
      // staff/ is just the list shown in this admin UI.
      await FirebaseFirestore.instance.collection('staff').add({
        'name': name,
        'email': emailLower,
        'role': 'staff',
        'addedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Add staff error: $e');
    }
  }

  Future<void> _deleteStaff(String id, String email) async {
    try {
      await FirebaseFirestore.instance.collection('staff').doc(id).delete();
      final emailLower = email.trim().toLowerCase();
      if (emailLower.isNotEmpty) {
        await FirebaseFirestore.instance.collection('staff_by_email').doc(emailLower).delete();
      }
    } catch (e) {
      debugPrint('Delete staff error: $e');
    }
  }
}