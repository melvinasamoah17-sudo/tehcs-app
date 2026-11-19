import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/call_service.dart';
import '../../theme/app_theme.dart';
import 'call_screen.dart';

/// Full-screen "X is calling…" with Accept / Decline.
class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final bool video;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    required this.video,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  StreamSubscription<DocumentSnapshot>? _sub;
  Timer? _buzz;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    CallService.inCall = true;
    _buzz = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    });
    // Caller hung up / timed out → close.
    _sub = CallService.calls.doc(widget.callId).snapshots().listen((s) {
      final status = s.data()?['status'];
      if (!_acting && status != 'ringing' && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _buzz?.cancel();
    if (!_acting) CallService.inCall = false;
    super.dispose();
  }

  Future<void> _decline() async {
    if (_acting) return;
    _acting = true;
    _buzz?.cancel();
    try {
      await CallService.setStatus(widget.callId, 'declined');
    } catch (_) {}
    CallService.inCall = false;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _accept() async {
    if (_acting) return;
    _acting = true;
    _buzz?.cancel();
    try {
      await CallService.setStatus(widget.callId, 'accepted');
    } catch (_) {
      CallService.inCall = false;
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CallScreen(
        callId: widget.callId,
        video: widget.video,
        isCaller: false,
        peerName: widget.callerName,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.navyDark,
        body: SafeArea(
          child: Column(children: [
            const SizedBox(height: 80),
            CircleAvatar(
              radius: 52,
              backgroundColor: AppTheme.gold,
              child: Text(
                widget.callerName.isNotEmpty
                    ? widget.callerName[0].toUpperCase()
                    : '?',
                style: GoogleFonts.poppins(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.navyDark),
              ),
            ),
            const SizedBox(height: 24),
            Text(widget.callerName,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text(
                widget.video
                    ? 'Incoming video call…'
                    : 'Incoming voice call…',
                style: GoogleFonts.inter(fontSize: 15, color: Colors.white70)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 0, 48, 56),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CallRoundButton(
                    icon: Icons.call_end_rounded,
                    color: AppTheme.red,
                    label: 'Decline',
                    onTap: _decline,
                  ),
                  CallRoundButton(
                    icon: widget.video
                        ? Icons.videocam_rounded
                        : Icons.call_rounded,
                    color: AppTheme.green,
                    label: 'Accept',
                    onTap: _accept,
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
