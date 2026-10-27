import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../theme/app_theme.dart';

/// A recorded voice note, ready to save in a chat message.
class VoiceNoteData {
  final String dataUri; // data:audio/mp4;base64,...
  final int seconds;
  const VoiceNoteData(this.dataUri, this.seconds);
}

/// Records short voice notes. Kept small (mono AAC, 32 kbps, max 90 s) so a
/// note fits inside a Firestore chat message, like chat photos do.
class VoiceRecorder {
  static const maxSeconds = 90;

  final _rec = AudioRecorder();
  final elapsed = ValueNotifier<int>(0);
  Timer? _timer;
  String? _path;
  void Function()? onMaxReached;

  bool get isRecording => _timer != null;

  /// Returns false if the microphone permission was refused.
  Future<bool> start() async {
    if (!await _rec.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 22050,
        numChannels: 1,
      ),
      path: _path!,
    );
    elapsed.value = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsed.value++;
      if (elapsed.value >= maxSeconds) onMaxReached?.call();
    });
    return true;
  }

  /// Stops and returns the note, or null if it was too short.
  Future<VoiceNoteData?> stop() async {
    _timer?.cancel();
    _timer = null;
    final path = await _rec.stop() ?? _path;
    final secs = elapsed.value;
    if (path == null || secs < 1) return null;
    final file = File(path);
    final bytes = await file.readAsBytes();
    unawaited(file.delete().catchError((_) => file));
    return VoiceNoteData('data:audio/mp4;base64,${base64Encode(bytes)}', secs);
  }

  Future<void> cancel() async {
    _timer?.cancel();
    _timer = null;
    await _rec.cancel();
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _rec.dispose();
    elapsed.dispose();
  }
}

String formatSeconds(int s) =>
    '${(s ~/ 60).toString().padLeft(1, '0')}:${(s % 60).toString().padLeft(2, '0')}';

/// Bar shown in place of the text box while recording.
class RecordingBar extends StatelessWidget {
  final VoiceRecorder recorder;
  final VoidCallback onCancel;
  final VoidCallback onSend;
  const RecordingBar(
      {super.key, required this.recorder, required this.onCancel, required this.onSend});

  @override
  Widget build(BuildContext context) => Row(children: [
        IconButton(
          tooltip: 'Delete recording',
          onPressed: onCancel,
          icon: const Icon(Icons.delete_outline, color: AppTheme.red),
        ),
        const Icon(Icons.fiber_manual_record, color: AppTheme.red, size: 14),
        const SizedBox(width: 6),
        ValueListenableBuilder<int>(
          valueListenable: recorder.elapsed,
          builder: (_, s, __) => Text(
              'Recording  ${formatSeconds(s)} / ${formatSeconds(VoiceRecorder.maxSeconds)}',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.navyDark)),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onSend,
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(color: AppTheme.navy, shape: BoxShape.circle),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]);
}

/// Play/pause bubble content for a voice note stored as a data URI.
class VoiceNotePlayer extends StatefulWidget {
  final String dataUri;
  final int seconds;
  final bool light; // light text on a dark bubble
  const VoiceNotePlayer(
      {super.key, required this.dataUri, required this.seconds, this.light = false});

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  final _player = AudioPlayer();
  String? _file;
  bool _playing = false;
  Duration _pos = Duration.zero;
  late final List<StreamSubscription> _subs;

  @override
  void initState() {
    super.initState();
    _subs = [
      _player.onPositionChanged.listen((p) => setState(() => _pos = p)),
      _player.onPlayerComplete.listen((_) =>
          setState(() { _playing = false; _pos = Duration.zero; })),
      _player.onPlayerStateChanged.listen(
          (s) => setState(() => _playing = s == PlayerState.playing)),
    ];
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<String> _ensureFile() async {
    if (_file != null) return _file!;
    final comma = widget.dataUri.indexOf(',');
    final bytes = base64Decode(widget.dataUri.substring(comma + 1));
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/vn_${widget.dataUri.hashCode}.m4a');
    if (!await f.exists()) await f.writeAsBytes(bytes, flush: true);
    return _file = f.path;
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
      } else if (_pos > Duration.zero) {
        await _player.resume();
      } else {
        await _player.play(DeviceFileSource(await _ensureFile()));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not play this voice note.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.light ? Colors.white : AppTheme.navy;
    final total = widget.seconds <= 0 ? 1 : widget.seconds;
    final progress = (_pos.inMilliseconds / (total * 1000)).clamp(0.0, 1.0);
    final shown = _playing || _pos > Duration.zero ? _pos.inSeconds : widget.seconds;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: _toggle,
        child: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
            size: 38, color: fg),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 120,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            color: fg,
            backgroundColor: fg.withOpacity(.25),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(formatSeconds(shown),
          style: GoogleFonts.inter(
              fontSize: 12, color: widget.light ? Colors.white70 : AppTheme.textMid)),
    ]);
  }
}
