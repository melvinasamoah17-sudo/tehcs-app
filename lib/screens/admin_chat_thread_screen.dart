import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/dash_theme.dart';
import '../models/chat_message.dart';
import '../services/call_service.dart';
import '../services/chat_service.dart';
import '../services/voice_note_service.dart';
import '../widgets/chat_media.dart';

class AdminChatThreadScreen extends StatefulWidget {
  final String clientUid;
  final String clientName;
  final String clientEmail;
  const AdminChatThreadScreen({
    super.key,
    required this.clientUid,
    required this.clientName,
    required this.clientEmail,
  });

  @override
  State<AdminChatThreadScreen> createState() => _AdminChatThreadScreenState();
}

class _AdminChatThreadScreenState extends State<AdminChatThreadScreen> {
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();
  final _recorder = VoiceRecorder();
  bool _hasText = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _msgCtrl.addListener(() {
      final has = _msgCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  Future<void> _sendVoice(VoiceClip clip) async {
    setState(() => _sending = true);
    try {
      await VoiceNoteService.send(
        clip: clip,
        clientUid: widget.clientUid,
        clientName: widget.clientName,
        clientEmail: widget.clientEmail,
        from: 'staff',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not send voice message.')));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _deleteMessage(ChatMessage m) async {
    if (!await showMessageActions(context,
        copyText: m.hasAudio || m.hasImage ? null : m.text)) {
      return;
    }
    try {
      await ChatService.deleteMessage(m.id, audioUrl: m.audioUrl);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete the message.')));
      }
    }
  }

  // Admin only: remove the whole conversation for everyone.
  Future<void> _deleteChat() async {
    final ok = await confirmDelete(context,
        title: 'Delete chat?',
        message: 'All messages with ${widget.clientName} will be deleted for '
            'you and for the customer. This cannot be undone.');
    if (!ok) return;
    try {
      await ChatService.deleteConversation(widget.clientUid);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete the chat.')));
      }
    }
  }

  // Admin only: call the customer back (rings while their app is open).
  void _call({required bool video}) => CallService.start(
        context,
        video: video,
        toAdmin: false,
        calleeUid: widget.clientUid,
        peerName: widget.clientName,
        clientUid: widget.clientUid,
        clientName: widget.clientName,
        clientEmail: widget.clientEmail,
      );

  void _send() async {
    final text = _msgCtrl.text.trim();
    final staffUser = FirebaseAuth.instance.currentUser;
    if (text.isEmpty || staffUser == null) return;
    _msgCtrl.clear();

    try {
      await FirebaseFirestore.instance.collection('chats').add({
        'uid': widget.clientUid,
        'name': widget.clientName,
        'email': widget.clientEmail,
        'text': text,
        'from': 'staff',
        'repliedBy': staffUser.email ?? staffUser.displayName ?? 'Staff',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scroll.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Dash.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.navyDark,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.clientName, style: GoogleFonts.barlowCondensed(fontSize: 17, fontWeight: FontWeight.w900, color: Dash.card)),
            if (widget.clientEmail.isNotEmpty)
              Text(widget.clientEmail, style: GoogleFonts.nunito(fontSize: 11, color: Colors.white54)),
          ],
        ),
        actions: [
          if (CallService.isAdmin) ...[
            IconButton(
              tooltip: 'Voice call',
              icon: const Icon(Icons.call_rounded, color: Colors.white),
              onPressed: () => _call(video: false),
            ),
            IconButton(
              tooltip: 'Video call',
              icon: const Icon(Icons.videocam_rounded, color: Colors.white),
              onPressed: () => _call(video: true),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              onSelected: (v) {
                if (v == 'delete') _deleteChat();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline_rounded,
                        color: AppTheme.red),
                    title: Text('Delete chat',
                        style: TextStyle(color: AppTheme.red)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('uid', isEqualTo: widget.clientUid)
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
                return ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final m = ChatMessage.fromFirestore(docs[i]);
                    // Admin can delete any message; staff only their replies.
                    final canDelete = CallService.isAdmin || !m.isClient;
                    return GestureDetector(
                      onLongPress: canDelete ? () => _deleteMessage(m) : null,
                      child: _StaffViewBubble(msg: m),
                    );
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
    decoration: BoxDecoration(color: Dash.card, border: Border(top: BorderSide(color: Dash.border))),
    child: ListenableBuilder(
      listenable: _recorder,
      builder: (_, __) => Row(
        children: [
          Expanded(
            child: _recorder.recording
                ? RecordingStrip(recorder: _recorder)
                : Container(
                    decoration: BoxDecoration(
                      color: Dash.field,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Dash.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _msgCtrl,
                      style: GoogleFonts.nunito(
                          fontSize: 14, color: Dash.text),
                      decoration: InputDecoration(
                        hintText: 'Reply to client...',
                        hintStyle: GoogleFonts.nunito(
                            fontSize: 14, color: Dash.textMute),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          if (_sending)
            const SizedBox(
                width: 44,
                height: 44,
                child: Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_hasText)
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: AppTheme.navy, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            )
          else
            HoldToRecordButton(
                recorder: _recorder, onRecorded: _sendVoice, size: 44),
        ],
      ),
    ),
  );
}

class _StaffViewBubble extends StatelessWidget {
  final ChatMessage msg;
  const _StaffViewBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    if (msg.isCallLog) return CallLogChip(msg: msg);
    // From the staff view, flip the alignment: the client's messages sit
    // on the left, staff replies sit on the right.
    final isStaffMsg = !msg.isClient;
    return Align(
      alignment: isStaffMsg ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isStaffMsg ? AppTheme.navy : Dash.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isStaffMsg ? 16 : 4),
            bottomRight: Radius.circular(isStaffMsg ? 4 : 16),
          ),
          border: isStaffMsg ? null : Border.all(color: Dash.border),
          boxShadow: isStaffMsg ? null : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.hasAudio)
              VoiceNotePlayer(url: msg.audioUrl, durationMs: msg.audioMs, onDark: isStaffMsg)
            else
              Text(msg.text, style: GoogleFonts.nunito(fontSize: 14, color: isStaffMsg ? Colors.white : Dash.text, height: 1.45)),
            const SizedBox(height: 4),
            Text(isStaffMsg ? 'You' : 'Client',
              style: GoogleFonts.barlowCondensed(fontSize: 9, fontWeight: FontWeight.w700, color: isStaffMsg ? Colors.white54 : Dash.textMute, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}