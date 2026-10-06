import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
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
  bool _sending = false;
  bool _showChips = true;

  User? get _user => FirebaseAuth.instance.currentUser;

  static const _quickReplies = [
    'I need to book a service 📅',
    'Where is my carer? 📍',
    'I need to cancel a booking ❌',
    'I have a question about my invoice 💳',
    'I need urgent help 🆘',
  ];

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ─── Send text message ───────────────────────────────────────────────────
  Future<void> _send({String? text}) async {
    final user = _user;
    final content = (text ?? _msgCtrl.text).trim();
    if (content.isEmpty || user == null) return;

    setState(() {
      _sending = true;
      _showChips = false;
    });
    _msgCtrl.clear();

    try {
      await FirebaseFirestore.instance.collection('chats').add({
        'uid': user.uid,
        'name': user.displayName ?? user.email?.split('@').first ?? 'User',
        'email': user.email ?? '',
        'text': content,
        'from': 'client',
        'imageUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      _showError('Could not send message.');
    }
    if (mounted) setState(() => _sending = false);
  }

  // ─── Camera / Gallery picker ─────────────────────────────────────────────
  Future<void> _showImageOptions() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) return;
    await _sendImage(File(picked.path));
  }

  // ─── Encode image as Base64 then save to Firestore ──────────────────────
  Future<void> _sendImage(File file) async {
    final user = _user;
    if (user == null) return;
    setState(() {
      _sending = true;
      _showChips = false;
    });

    try {
      // Read bytes and encode to Base64 data URI (kept small by imageQuality:75)
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      final dataUri = 'data:image/jpeg;base64,$b64';

      // Firestore 1 MB doc limit — warn if too large
      if (bytes.lengthInBytes > 900 * 1024) {
        if (!mounted) return;
        _showError('Photo is too large. Please try a smaller one.');
        setState(() => _sending = false);
        return;
      }

      await FirebaseFirestore.instance.collection('chats').add({
        'uid': user.uid,
        'name': user.displayName ?? user.email?.split('@').first ?? 'User',
        'email': user.email ?? '',
        'text': '📷 Photo',
        'from': 'client',
        'imageUrl': dataUri,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      _showError('Could not send photo. Check your connection.');
    }
    if (mounted) setState(() => _sending = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  bool _differentDay(Timestamp? a, Timestamp? b) {
    if (a == null || b == null) return false;
    final da = a.toDate();
    final db = b.toDate();
    return da.year != db.year || da.month != db.month || da.day != db.day;
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return const Scaffold(
          body: Center(child: Text('Please log in to chat.')));
    }

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(children: [
        _buildHeader(),
        Expanded(child: _buildMessages(user)),
        if (_showChips) _buildQuickChips(),
        _buildInput(),
      ]),
    );
  }

  // ─────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.navyDark, AppTheme.navy]),
      ),
      child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/tehcs.jpg',
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        color: AppTheme.gold,
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(
                        child: Text('T',
                            style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.navyDark))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('TEHCS Support',
                        style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.3)),
                    Row(children: [
                      Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: AppTheme.green, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text('Typically replies within minutes',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white54,
                              fontWeight: FontWeight.w300)),
                    ]),
                  ])),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse('tel:+233240699329');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.phone_outlined,
                        color: Colors.white70, size: 18)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse('https://wa.me/233240699329');
                  if (await canLaunchUrl(uri))
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withOpacity(.2),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Center(
                        child: Icon(Icons.chat_bubble_rounded,
                            size: 18, color: Color(0xFF25D366)))),
              ),
            ]),
          )),
    );
  }

  // ─────────────────────────────────────────
  // MESSAGES
  // ─────────────────────────────────────────
  Widget _buildMessages(User user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('uid', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.navy, strokeWidth: 2));
        }
        if (snap.hasError) {
          return Center(
              child: Text('Error: ${snap.error}',
                  style: GoogleFonts.inter(color: AppTheme.red, fontSize: 13)));
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
              child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.chat_bubble_outline_rounded,
                  size: 52, color: AppTheme.navy),
              const SizedBox(height: 16),
              Text('How can we help you?',
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.navy)),
              const SizedBox(height: 8),
              Text(
                  'Send us a message or use a quick reply below.\nOur team is ready to help.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textMute,
                      fontWeight: FontWeight.w300,
                      height: 1.6)),
            ]),
          ));
        }

        return ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final m = ChatMessage.fromFirestore(docs[i]);
            final showDate = i == docs.length - 1 ||
                _differentDay(
                  (docs[i].data() as Map)['createdAt'] as Timestamp?,
                  (docs[i + 1].data() as Map)['createdAt'] as Timestamp?,
                );
            return Column(children: [
              if (showDate)
                _DateDivider(
                    ts: (docs[i].data() as Map)['createdAt'] as Timestamp?),
              _ChatBubble(msg: m),
            ]);
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // QUICK CHIPS
  // ─────────────────────────────────────────
  Widget _buildQuickChips() {
    return Container(
      color: AppTheme.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('QUICK REPLIES',
            style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMute,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              children: _quickReplies
                  .map((q) => GestureDetector(
                        onTap: () => _send(text: q),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.navy.withOpacity(.06),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                                color: AppTheme.navy.withOpacity(.15)),
                          ),
                          child: Text(q,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.navy,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ))
                  .toList()),
        ),
        const SizedBox(height: 4),
      ]),
    );
  }

  // ─────────────────────────────────────────
  // INPUT BAR
  // ─────────────────────────────────────────
  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(children: [
        // Camera / Gallery button
        GestureDetector(
          onTap: _sending ? null : _showImageOptions,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.navy.withOpacity(.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.navy.withOpacity(.15)),
            ),
            child: _sending
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.navy))
                : const Icon(Icons.camera_alt_rounded,
                    color: AppTheme.navy, size: 22),
          ),
        ),
        const SizedBox(width: 8),
        // Text field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
                color: AppTheme.offWhite,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.border)),
            child: TextField(
              controller: _msgCtrl,
              maxLines: 4,
              minLines: 1,
              onTap: () => setState(() => _showChips = false),
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.navyDark),
              decoration: InputDecoration(
                hintText: 'Type your message...',
                hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textMute,
                    fontWeight: FontWeight.w300),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Send button
        GestureDetector(
          onTap: _sending ? null : () => _send(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _sending ? AppTheme.navy.withOpacity(.5) : AppTheme.navy,
              shape: BoxShape.circle,
            ),
            child: _sending
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// IMAGE SOURCE BOTTOM SHEET
// ══════════════════════════════════════════
class _ImageSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Text('Send a Photo',
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppTheme.navyDark)),
        const SizedBox(height: 6),
        Text(
            'Take a photo of what you need — shopping list,\nlocation, or anything for your carer.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13, color: AppTheme.textMute, height: 1.5)),
        const SizedBox(height: 24),
        Row(children: [
          // Camera option
          Expanded(
              child: GestureDetector(
            onTap: () => Navigator.pop(context, ImageSource.camera),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: AppTheme.navy,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 34),
                const SizedBox(height: 10),
                Text('Camera',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text('Take a photo now',
                    style:
                        GoogleFonts.inter(fontSize: 11, color: Colors.white60)),
              ]),
            ),
          )),
          const SizedBox(width: 12),
          // Gallery option
          Expanded(
              child: GestureDetector(
            onTap: () => Navigator.pop(context, ImageSource.gallery),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: AppTheme.offWhite,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.photo_library_rounded,
                    color: AppTheme.navy, size: 34),
                const SizedBox(height: 10),
                Text('Gallery',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navyDark)),
                const SizedBox(height: 2),
                Text('Choose from photos',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppTheme.textMute)),
              ]),
            ),
          )),
        ]),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text('Cancel',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textMute,
                  fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// CHAT BUBBLE
// ══════════════════════════════════════════
class _ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isClient;
    final time =
        msg.createdAt != null ? DateFormat('HH:mm').format(msg.createdAt!) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(right: 6, bottom: 2),
                decoration:
                    BoxDecoration(color: AppTheme.navy, shape: BoxShape.circle),
                child: Center(
                    child: Text('T',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)))),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * .72),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.navy : AppTheme.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border: isMe ? null : Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: msg.hasImage
                  ? _buildImageBubble(context, isMe, time)
                  : _buildTextBubble(isMe, time),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextBubble(bool isMe, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Text('TEHCS Agent',
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.goldDark,
                      letterSpacing: 0.3)),
              const SizedBox(height: 3),
            ],
            Text(msg.text,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isMe ? Colors.white : AppTheme.navyDark,
                    fontWeight: FontWeight.w400,
                    height: 1.4)),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(time,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isMe ? Colors.white54 : AppTheme.textMute,
                      fontWeight: FontWeight.w300)),
              if (isMe) ...[
                const SizedBox(width: 4),
                const Icon(Icons.done_all_rounded,
                    size: 13, color: AppTheme.green),
              ],
            ]),
          ]),
    );
  }

  Widget _buildImageBubble(BuildContext context, bool isMe, String time) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft: Radius.circular(isMe ? 18 : 4),
        bottomRight: Radius.circular(isMe ? 4 : 18),
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The image (Base64 data URI stored in Firestore)
          GestureDetector(
            onTap: () => _openFullImage(context, msg.imageUrl),
            child: _Base64Image(
              dataUri: msg.imageUrl,
              isMe: isMe,
            ),
          ),
          // Caption + time
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(time,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isMe ? Colors.white54 : AppTheme.textMute,
                      fontWeight: FontWeight.w300)),
              if (isMe) ...[
                const SizedBox(width: 4),
                const Icon(Icons.done_all_rounded,
                    size: 13, color: AppTheme.green),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  void _openFullImage(BuildContext context, String dataUri) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => _FullImageView(dataUri: dataUri)));
  }
}

// ══════════════════════════════════════════
// BASE64 IMAGE WIDGET
// ══════════════════════════════════════════
class _Base64Image extends StatelessWidget {
  final String dataUri;
  final bool isMe;
  const _Base64Image({required this.dataUri, required this.isMe});

  @override
  Widget build(BuildContext context) {
    try {
      final comma = dataUri.indexOf(',');
      final bytes = base64Decode(dataUri.substring(comma + 1));
      return Image.memory(bytes,
          width: 220,
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder());
    } catch (_) {
      return _placeholder();
    }
  }

  Widget _placeholder() => Container(
      width: 220,
      height: 80,
      color: isMe ? AppTheme.navyDark : AppTheme.offWhite,
      child: Center(
          child: Icon(Icons.broken_image_outlined,
              color: isMe ? Colors.white38 : AppTheme.textMute)));
}

// ══════════════════════════════════════════
// FULL-SCREEN IMAGE VIEWER
// ══════════════════════════════════════════
class _FullImageView extends StatelessWidget {
  final String dataUri;
  const _FullImageView({required this.dataUri});

  @override
  Widget build(BuildContext context) {
    late final Widget image;
    try {
      final comma = dataUri.indexOf(',');
      final bytes = base64Decode(dataUri.substring(comma + 1));
      image = Image.memory(bytes, fit: BoxFit.contain);
    } catch (_) {
      image = const Icon(Icons.broken_image_outlined,
          color: Colors.white54, size: 64);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(child: image),
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
    final d = ts!.toDate();
    final now = DateTime.now();
    String label;
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      label = 'Today';
    } else if (d.year == now.year &&
        d.month == now.month &&
        d.day == now.day - 1) {
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
            decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppTheme.border)),
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textMute,
                    fontWeight: FontWeight.w300)),
          ),
        ),
        const Expanded(child: Divider()),
      ]),
    );
  }
}
