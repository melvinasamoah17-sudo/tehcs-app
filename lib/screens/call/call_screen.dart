import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/call_service.dart';
import '../../theme/app_theme.dart';

/// The in-call screen, for both the caller (shows "Ringing…" first) and the
/// person who accepted.
class CallScreen extends StatefulWidget {
  final String callId;
  final bool video;
  final bool isCaller;
  final String peerName;

  const CallScreen({
    super.key,
    required this.callId,
    required this.video,
    required this.isCaller,
    required this.peerName,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RtcEngine? _engine;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;
  Map<String, dynamic> _call = {};
  Timer? _ringTimer;
  Timer? _ticker;

  int? _remoteUid;
  DateTime? _connectedAt;
  String _statusText = '';
  bool _muted = false;
  bool _speaker = false;
  bool _cameraOff = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    CallService.inCall = true;
    _speaker = widget.video;
    _statusText = widget.isCaller ? 'Calling…' : 'Connecting…';

    _docSub = CallService.calls.doc(widget.callId).snapshots().listen(_onDoc);
    if (widget.isCaller) {
      _ringTimer = Timer(CallService.ringTimeout, () {
        if (_connectedAt == null) _close(outcome: 'missed', update: true);
      });
    }
    _start();
  }

  void _onDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data();
    if (d == null) return;
    _call = d;
    final status = d['status'];
    if (status == 'ringing' && widget.isCaller && _connectedAt == null) {
      setState(() => _statusText = 'Ringing…');
    } else if (status == 'accepted' && _connectedAt == null) {
      setState(() => _statusText = 'Connecting…');
    } else if (status == 'declined') {
      _close(outcome: 'declined');
    } else if (status == 'ended' || status == 'missed' || status == 'cancelled') {
      _close(outcome: status);
    }
  }

  Future<void> _start() async {
    // Permissions first.
    final perms = [Permission.microphone, if (widget.video) Permission.camera];
    final results = await perms.request();
    if (results.values.any((s) => !s.isGranted)) {
      _fail(widget.video
          ? 'Allow microphone and camera access in Settings to make video calls.'
          : 'Allow microphone access in Settings to make calls.');
      return;
    }

    try {
      final info = await CallService.joinInfo(widget.callId);
      if (_closing) return;
      final engine = createAgoraRtcEngine();
      _engine = engine;
      await engine.initialize(RtcEngineContext(
        appId: info.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
      engine.registerEventHandler(RtcEngineEventHandler(
        onUserJoined: (conn, remoteUid, _) {
          _ringTimer?.cancel();
          if (!mounted) return;
          setState(() {
            _remoteUid = remoteUid;
            _connectedAt ??= DateTime.now();
          });
          _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() {});
          });
        },
        onUserOffline: (conn, remoteUid, reason) {
          // Other side left (or lost connection for good).
          _close(outcome: 'ended', update: true);
        },
        onError: (err, msg) => debugPrint('Agora error $err: $msg'),
      ));

      if (widget.video) {
        await engine.enableVideo();
        await engine.startPreview();
      }
      await engine.setDefaultAudioRouteToSpeakerphone(widget.video);
      await engine.joinChannel(
        token: info.token,
        channelId: info.channel,
        uid: info.uid,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: widget.video,
          autoSubscribeAudio: true,
          autoSubscribeVideo: widget.video,
        ),
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Call start failed: $e');
      _fail('Could not connect the call. Check your connection.');
    }
  }

  void _fail(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
    _close(
        outcome: widget.isCaller ? 'cancelled' : 'ended',
        update: true,
        log: false);
  }

  /// Hang-up button.
  void _hangUp() {
    final outcome =
        _connectedAt == null && widget.isCaller ? 'cancelled' : 'ended';
    _close(outcome: outcome, update: true);
  }

  Future<void> _close({
    required String outcome,
    bool update = false,
    bool log = true,
  }) async {
    if (_closing) return;
    _closing = true;
    _ringTimer?.cancel();
    _ticker?.cancel();
    final talked = _connectedAt == null
        ? null
        : DateTime.now().difference(_connectedAt!);

    if (update) {
      try {
        await CallService.setStatus(widget.callId, outcome);
      } catch (_) {}
    }
    if (widget.isCaller && log && _call.isNotEmpty) {
      await CallService.logToChat(_call, outcome, talked);
    }
    await _releaseEngine();
    CallService.inCall = false;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _releaseEngine() async {
    final e = _engine;
    _engine = null;
    if (e == null) return;
    try {
      await e.leaveChannel();
      await e.release();
    } catch (_) {}
  }

  @override
  void dispose() {
    _docSub?.cancel();
    _ringTimer?.cancel();
    _ticker?.cancel();
    if (!_closing) {
      // Screen removed some other way — still end the call cleanly.
      _closing = true;
      CallService.setStatus(widget.callId, 'ended').catchError((_) {});
      _releaseEngine();
      CallService.inCall = false;
    }
    super.dispose();
  }

  // ── Controls ──
  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    await _engine?.muteLocalAudioStream(_muted);
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _speaker = !_speaker);
    await _engine?.setEnableSpeakerphone(_speaker);
  }

  Future<void> _toggleCamera() async {
    setState(() => _cameraOff = !_cameraOff);
    await _engine?.muteLocalVideoStream(_cameraOff);
    await _engine?.enableLocalVideo(!_cameraOff);
  }

  Future<void> _switchCamera() async => _engine?.switchCamera();

  String get _label {
    if (_connectedAt == null) return _statusText;
    final d = DateTime.now().difference(_connectedAt!);
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── UI ──
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.navyDark,
        body: Stack(children: [
          if (widget.video) _videoLayer() else _voiceBackdrop(),
          SafeArea(
            child: Column(children: [
              const SizedBox(height: 24),
              if (!widget.video || _remoteUid == null) ...[
                if (widget.video) const SizedBox(height: 40),
                _header(),
              ] else
                _compactHeader(),
              const Spacer(),
              _controls(),
              const SizedBox(height: 40),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _header() => Column(children: [
        if (!widget.video) ...[
          const SizedBox(height: 60),
          CircleAvatar(
            radius: 52,
            backgroundColor: AppTheme.gold,
            child: Text(
              widget.peerName.isNotEmpty
                  ? widget.peerName[0].toUpperCase()
                  : '?',
              style: GoogleFonts.poppins(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.navyDark),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text(widget.peerName,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                shadows: const [Shadow(blurRadius: 8, color: Colors.black45)])),
        const SizedBox(height: 6),
        Text(_label,
            style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.white70,
                shadows: const [Shadow(blurRadius: 8, color: Colors.black45)])),
      ]);

  Widget _compactHeader() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Expanded(
            child: Text(widget.peerName,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: const [
                      Shadow(blurRadius: 8, color: Colors.black54)
                    ])),
          ),
          Text(_label,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white,
                  shadows: const [
                    Shadow(blurRadius: 8, color: Colors.black54)
                  ])),
        ]),
      );

  Widget _voiceBackdrop() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.navy, AppTheme.navyDark],
          ),
        ),
      );

  Widget _videoLayer() {
    final engine = _engine;
    if (engine == null) return _voiceBackdrop();
    final local = _cameraOff
        ? Container(color: Colors.black87)
        : AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: engine,
              canvas: const VideoCanvas(uid: 0),
            ),
          );

    if (_remoteUid == null) {
      // Before the other side joins, show yourself full screen.
      return Positioned.fill(child: local);
    }
    return Stack(children: [
      Positioned.fill(
        child: AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: engine,
            canvas: VideoCanvas(uid: _remoteUid),
            connection: RtcConnection(channelId: widget.callId),
          ),
        ),
      ),
      Positioned(
        right: 16,
        top: MediaQuery.of(context).padding.top + 60,
        width: 110,
        height: 160,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: local,
        ),
      ),
    ]);
  }

  Widget _controls() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            CallRoundButton(
              icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
              color: _muted ? Colors.white : Colors.white24,
              iconColor: _muted ? AppTheme.navyDark : Colors.white,
              onTap: _toggleMute,
              small: true,
            ),
            if (widget.video) ...[
              CallRoundButton(
                icon: _cameraOff
                    ? Icons.videocam_off_rounded
                    : Icons.videocam_rounded,
                color: _cameraOff ? Colors.white : Colors.white24,
                iconColor: _cameraOff ? AppTheme.navyDark : Colors.white,
                onTap: _toggleCamera,
                small: true,
              ),
              CallRoundButton(
                icon: Icons.cameraswitch_rounded,
                color: Colors.white24,
                onTap: _switchCamera,
                small: true,
              ),
            ] else
              CallRoundButton(
                icon: _speaker
                    ? Icons.volume_up_rounded
                    : Icons.volume_down_rounded,
                color: _speaker ? Colors.white : Colors.white24,
                iconColor: _speaker ? AppTheme.navyDark : Colors.white,
                onTap: _toggleSpeaker,
                small: true,
              ),
            CallRoundButton(
              icon: Icons.call_end_rounded,
              color: AppTheme.red,
              onTap: _hangUp,
            ),
          ],
        ),
      );
}

/// Round call control button.
class CallRoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;
  final String? label;
  final bool small;

  const CallRoundButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.iconColor = Colors.white,
    this.label,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = small ? 58.0 : 70.0;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: iconColor, size: small ? 26 : 32),
          ),
        ),
      ),
      if (label != null) ...[
        const SizedBox(height: 8),
        Text(label!,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
      ],
    ]);
  }
}
