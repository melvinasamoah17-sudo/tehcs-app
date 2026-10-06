import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class StaffChatScreen extends StatefulWidget {
  const StaffChatScreen({super.key});
  @override
  State<StaffChatScreen> createState() => _StaffChatScreenState();
}

class _StaffChatScreenState extends State<StaffChatScreen> {
  final _user       = FirebaseAuth.instance.currentUser;
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending     = false;

  String get _uid  => _user?.uid ?? '';
  String get _name => _user?.displayName ?? _user?.email?.split('@').first ?? 'Staff';
  String get _roomId => 'staff_office_$_uid';

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({String? text}) async {
    final content = text?.trim() ?? '';
    if (content.isEmpty) return;
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance
          .collection('staff_chats').doc(_roomId)
          .collection('messages').add({
        'senderId':   _uid,
        'senderName': _name,
        'senderRole': 'staff',
        'text':       content,
        'imageUrl':   '',
        'timestamp':  FieldValue.serverTimestamp(),
        'read':       false,
      });
      await FirebaseFirestore.instance
          .collection('staff_chats').doc(_roomId)
          .set({
        'staffId':     _uid,
        'staffName':   _name,
        'lastMessage': content,
        'lastAt':      FieldValue.serverTimestamp(),
        'unreadAdmin': FieldValue.increment(1),
      }, SetOptions(merge: true));
      _msgCtrl.clear();
      _scrollToBottom();
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    await _sendMessage(text: '📷 [Image: ${picked.name}]');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  bool _differentDay(Timestamp? a, Timestamp? b) {
    if (a == null || b == null) return false;
    final da = a.toDate(); final db = b.toDate();
    return da.year != db.year || da.month != db.month || da.day != db.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(children: [
        _buildHeader(),
        Expanded(child: _buildMessages()),
        _buildInput(),
      ]),
    );
  }

  // ── HEADER ──
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppTheme.navyDark, AppTheme.navy]),
      ),
      child: SafeArea(bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(color: AppTheme.gold, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text('T', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.navyDark))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TEHCS Office', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3)),
              Row(children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppTheme.green, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('Support team', style: GoogleFonts.inter(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w300)),
              ]),
            ])),
            GestureDetector(
              onTap: () async {
                final uri = Uri.parse('tel:+233240699329');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
              child: Container(width: 38, height: 38,
                decoration: BoxDecoration(color: Colors.white.withOpacity(.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.phone_outlined, color: Colors.white70, size: 18)),
            ),
          ]),
        ),
      ),
    );
  }

  // ── MESSAGES ──
  Widget _buildMessages() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('staff_chats').doc(_roomId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.navy, strokeWidth: 2));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppTheme.textMute),
            const SizedBox(height: 14),
            Text('No messages yet', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMute)),
            const SizedBox(height: 6),
            Text('Send a message to the TEHCS office team',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
          ]));
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d    = docs[i].data() as Map<String, dynamic>;
            final isMe = d['senderId'] == _uid;
            final showDate = i == 0 || _differentDay(
              (docs[i - 1].data() as Map)['timestamp'] as Timestamp?,
              d['timestamp'] as Timestamp?,
            );
            return Column(children: [
              if (showDate) _DateDivider(ts: d['timestamp'] as Timestamp?),
              _Bubble(data: d, isMe: isMe),
            ]);
          },
        );
      },
    );
  }

  // ── INPUT ──
  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(width: 40, height: 40,
            decoration: BoxDecoration(color: AppTheme.offWhite, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
            child: const Icon(Icons.image_outlined, color: AppTheme.textMute, size: 20)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: AppTheme.offWhite, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppTheme.border)),
            child: TextField(
              controller: _msgCtrl,
              maxLines: 4, minLines: 1,
              textInputAction: TextInputAction.newline,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.navyDark),
              decoration: InputDecoration(
                hintText: 'Message the office...',
                hintStyle: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMute, fontWeight: FontWeight.w300),
                border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _sending ? null : () => _sendMessage(text: _msgCtrl.text),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _sending ? AppTheme.navy.withOpacity(.5) : AppTheme.navy,
              shape: BoxShape.circle,
            ),
            child: _sending
              ? const Padding(padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// CHAT BUBBLE
// ══════════════════════════════════════════
class _Bubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMe;
  const _Bubble({required this.data, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final text = data['text'] as String? ?? '';
    final ts   = data['timestamp'] as Timestamp?;
    final time = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(width: 30, height: 30, margin: const EdgeInsets.only(right: 6, bottom: 2),
              decoration: BoxDecoration(color: AppTheme.navy, shape: BoxShape.circle),
              child: Center(child: Text('O', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white))),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .72),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.navy : AppTheme.white,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(18),
                  topRight:    const Radius.circular(18),
                  bottomLeft:  Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 6, offset: const Offset(0, 2))],
                border: isMe ? null : Border.all(color: AppTheme.border),
              ),
              child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                if (!isMe) ...[
                  Text(data['senderName'] ?? 'Office',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.goldDark, letterSpacing: 0.3)),
                  const SizedBox(height: 3),
                ],
                Text(text, style: GoogleFonts.inter(fontSize: 14,
                  color: isMe ? Colors.white : AppTheme.navyDark, fontWeight: FontWeight.w400, height: 1.4)),
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(time, style: GoogleFonts.inter(fontSize: 10,
                    color: isMe ? Colors.white54 : AppTheme.textMute, fontWeight: FontWeight.w300)),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.done_all_rounded, size: 13, color: AppTheme.green),
                  ],
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// DATE DIVIDER
// ══════════════════════════════════════════
class _DateDivider extends StatelessWidget {
  final Timestamp? ts;
  const _DateDivider({required this.ts});

  @override
  Widget build(BuildContext context) {
    if (ts == null) return const SizedBox.shrink();
    final d   = ts!.toDate();
    final now = DateTime.now();
    String label;
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      label = 'Today';
    } else if (d.year == now.year && d.month == now.month && d.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat('d MMM yyyy').format(d);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(100), border: Border.all(color: AppTheme.border)),
            child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMute, fontWeight: FontWeight.w300)),
          ),
        ),
        const Expanded(child: Divider()),
      ]),
    );
  }
}
