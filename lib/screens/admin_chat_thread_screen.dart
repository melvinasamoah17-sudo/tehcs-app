import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/chat_message.dart';
import '../services/call_service.dart';
import '../widgets/voice_note.dart';

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
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _recorder.onMaxReached = _stopAndSendVoice;
    _msgCtrl.addListener(() => setState(() {}));
  }

  Future<void> _startRecording() async {
    if (!await _recorder.start()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please allow microphone access to send voice notes.')));
      }
      return;
    }
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _cancelRecording() async {
    await _recorder.cancel();
    if (mounted) setState(() => _recording = false);
  }

  Future<void> _stopAndSendVoice() async {
    if (!_recording) return;
    setState(() => _recording = false);
    final staffUser = FirebaseAuth.instance.currentUser;
    try {
      final note = await _recorder.stop();
      if (note == null || staffUser == null) return;
      await FirebaseFirestore.instance.collection('chats').add({
        'uid': widget.clientUid,
        'name': widget.clientName,
        'email': widget.clientEmail,
        'text': '🎤 Voice note',
        'from': 'staff',
        'repliedBy': staffUser.email ?? staffUser.displayName ?? 'Staff',
        'audioUrl': note.dataUri,
        'audioSeconds': note.seconds,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not send voice note.')));
      }
    }
  }

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
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.navyDark,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.clientName, style: GoogleFonts.barlowCondensed(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.white)),
            if (widget.clientEmail.isNotEmpty)
              Text(widget.clientEmail, style: GoogleFonts.nunito(fontSize: 11, color: Colors.white54)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Voice call',
            icon: const Icon(Icons.call_outlined, color: Colors.white),
            onPressed: () => CallService.callCustomer(context,
                uid: widget.clientUid, name: widget.clientName, video: false),
          ),
          IconButton(
            tooltip: 'Video call',
            icon: const Icon(Icons.videocam_outlined, color: Colors.white),
            onPressed: () => CallService.callCustomer(context,
                uid: widget.clientUid, name: widget.clientName, video: true),
          ),
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
                    return _StaffViewBubble(msg: m);
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
    decoration: const BoxDecoration(color: AppTheme.white, border: Border(top: BorderSide(color: AppTheme.border))),
    child: _recording
      ? RecordingBar(recorder: _recorder, onCancel: _cancelRecording, onSend: _stopAndSendVoice)
      : Row(
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
                hintText: 'Reply to client...',
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
          onTap: _msgCtrl.text.trim().isEmpty ? _startRecording : _send,
          child: Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(color: AppTheme.navy, shape: BoxShape.circle),
            child: Icon(_msgCtrl.text.trim().isEmpty ? Icons.mic_rounded : Icons.send_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ],
    ),
  );
}

class _StaffViewBubble extends StatelessWidget {
  final ChatMessage msg;
  const _StaffViewBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
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
          color: isStaffMsg ? AppTheme.navy : AppTheme.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isStaffMsg ? 16 : 4),
            bottomRight: Radius.circular(isStaffMsg ? 4 : 16),
          ),
          border: isStaffMsg ? null : Border.all(color: AppTheme.border),
          boxShadow: isStaffMsg ? null : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.hasAudio)
              VoiceNotePlayer(dataUri: msg.audioUrl, seconds: msg.audioSeconds, light: isStaffMsg)
            else
              Text(msg.text, style: GoogleFonts.nunito(fontSize: 14, color: isStaffMsg ? Colors.white : AppTheme.navyDark, height: 1.45)),
            const SizedBox(height: 4),
            Text(isStaffMsg ? 'You' : 'Client',
              style: GoogleFonts.barlowCondensed(fontSize: 9, fontWeight: FontWeight.w700, color: isStaffMsg ? Colors.white54 : AppTheme.textMute, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}