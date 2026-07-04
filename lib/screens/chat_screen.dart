import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();

  User? get _user => FirebaseAuth.instance.currentUser;

  void _send() async {
    final user = _user;
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || user == null) return;

    final name = user.displayName ?? user.email?.split('@').first ?? 'User';
    final email = user.email ?? '';
    final uid = user.uid;

    _msgCtrl.clear();

    try {
      debugPrint('Attempting to send chat message for UID: $uid');
      await FirebaseFirestore.instance.collection('chats').add({
        'uid': uid,
        'name': name,
        'email': email,
        'text': text,
        'from': 'client',
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Chat message sent successfully');
      
      // Auto-scroll to top (since reverse: true)
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      debugPrint('Chat error: $e');
      String msg = e.toString();
      if (msg.contains('permission-denied')) {
        msg = 'Permission denied. Please check your Firestore rules.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chat error: $msg')),
        );
      }
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to chat.')),
      );
    }

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TEHCS SUPPORT', 
                    style: GoogleFonts.barlowCondensed(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.white, letterSpacing: 1.2)
                  ),
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.green, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('Always available', 
                        style: GoogleFonts.nunito(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w400)
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('uid', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.red)));
                }

                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.navy));
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💬', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 16),
                          Text('How can we help you?', 
                            style: GoogleFonts.barlowCondensed(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.navy)
                          ),
                          const SizedBox(height: 8),
                          Text('Send a message to start a conversation with our care team.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(fontSize: 14, color: AppTheme.textMute, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final m = ChatMessage.fromFirestore(docs[i]);
                    return _ChatBubble(msg: m);
                  },
                );
              },
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    decoration: const BoxDecoration(
      color: AppTheme.white,
      border: Border(top: BorderSide(color: AppTheme.border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.offWhite,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _msgCtrl,
              style: GoogleFonts.nunito(fontSize: 14, color: AppTheme.navyDark),
              decoration: InputDecoration(
                hintText: 'Type your message...',
                hintStyle: GoogleFonts.nunito(fontSize: 14, color: AppTheme.textMute),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _send,
          child: Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(color: AppTheme.navy, shape: BoxShape.circle),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
    ),
  );
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isClient;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.navy : AppTheme.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: AppTheme.border),
          boxShadow: isMe ? null : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.text,
              style: GoogleFonts.nunito(fontSize: 14, color: isMe ? Colors.white : AppTheme.navyDark, height: 1.45),
            ),
            const SizedBox(height: 4),
            Text(isMe ? 'Sent' : 'TEHCS Agent',
              style: GoogleFonts.barlowCondensed(fontSize: 9, fontWeight: FontWeight.w700, color: isMe ? Colors.white54 : AppTheme.textMute, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
