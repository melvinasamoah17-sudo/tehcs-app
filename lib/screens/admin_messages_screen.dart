import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'admin_chat_thread_screen.dart';

class AdminMessagesScreen extends StatelessWidget {
  const AdminMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.red)));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text('No messages yet.', style: GoogleFonts.nunito(fontSize: 14, color: AppTheme.textMute)),
          );
        }

        // Group by client uid, keeping only the newest message per client
        // (docs already arrive newest-first, so the first occurrence wins).
        final Map<String, QueryDocumentSnapshot> latestByUid = {};
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final uid = data['uid'] as String? ?? '';
          if (uid.isEmpty) continue;
          latestByUid.putIfAbsent(uid, () => doc);
        }
        final conversations = latestByUid.values.toList();

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: conversations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final doc = conversations[i];
            final data = doc.data() as Map<String, dynamic>;
            final uid = data['uid'] as String? ?? '';
            final name = data['name'] as String? ?? 'Unknown';
            final email = data['email'] as String? ?? '';
            final text = data['text'] as String? ?? '';
            final from = data['from'] as String? ?? 'client';

            return Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.navy,
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                ),
                title: Text(name, style: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w800, fontSize: 15)),
                subtitle: Text(
                  from == 'client' ? text : 'You: $text',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(fontSize: 13, color: AppTheme.textMute),
                ),
                trailing: from == 'client'
                    ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppTheme.gold, shape: BoxShape.circle))
                    : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AdminChatThreadScreen(clientUid: uid, clientName: name, clientEmail: email)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}