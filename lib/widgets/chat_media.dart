import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/chat_message.dart';
import '../services/voice_note_service.dart';
import '../theme/app_theme.dart';

String formatClock(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

// ══════════════════════════════════════════
// VOICE NOTE PLAYER (inside a chat bubble)
// ══════════════════════════════════════════
class VoiceNotePlayer extends StatefulWidget {
  final String url;
  final int durationMs;

  /// True when the bubble background is dark (navy), so we use light colours.
  final bool onDark;

  const VoiceNotePlayer({
    super.key,
    required this.url,
    required this.durationMs,
    required this.onDark,
  });

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  // Only one voice note plays at a time, like WhatsApp.
  static _VoiceNotePlayerState? _active;

  final _player = AudioPlayer();
  final _subs = <StreamSubscription>[];
  PlayerState _state = PlayerState.stopped;
  Duration _pos = Duration.zero;
  late Duration _dur = Duration(milliseconds: widget.durationMs);
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _subs.addAll([
      _player.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _state = s);
      }),
      _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _pos = p);
      }),
      _player.onDurationChanged.listen((d) {
        if (mounted && d > Duration.zero) setState(() => _dur = d);
      }),
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _pos = Duration.zero);
      }),
    ]);
  }

  @override
  void dispose() {
    if (_active == this) _active = null;
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (_active != null && _active != this) {
      await _active!._player.pause();
    }
    _active = this;
    if (_state == PlayerState.paused) {
      await _player.resume();
      return;
    }
    setState(() => _loading = true);
    try {
      await _player.play(await _source());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not play voice message.')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Storage URLs stream directly. Older notes were saved inline as
  /// data:audio/...;base64 URIs; write those to a temp file and play that.
  Future<Source> _source() async {
    final url = widget.url;
    if (!url.startsWith('data:')) return UrlSource(url);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/vn_${url.hashCode.toUnsigned(32)}.m4a');
    if (!await file.exists()) {
      final comma = url.indexOf(',');
      await file.writeAsBytes(base64Decode(url.substring(comma + 1)));
    }
    return DeviceFileSource(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.onDark ? Colors.white : AppTheme.navy;
    final track = widget.onDark ? Colors.white24 : AppTheme.border;
    final playing = _state == PlayerState.playing;
    final total = _dur.inMilliseconds <= 0 ? 1 : _dur.inMilliseconds;
    final value = (_pos.inMilliseconds / total).clamp(0.0, 1.0);
    final label = (playing || _pos > Duration.zero) ? _pos : _dur;

    return SizedBox(
      width: 230,
      child: Row(children: [
        GestureDetector(
          onTap: _loading ? null : _toggle,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: widget.onDark ? Colors.white : AppTheme.navy,
              shape: BoxShape.circle,
            ),
            child: _loading
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.onDark ? AppTheme.navy : Colors.white))
                : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: widget.onDark ? AppTheme.navy : Colors.white,
                    size: 24),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: fg,
              inactiveTrackColor: track,
              thumbColor: fg,
            ),
            child: Slider(
              value: value,
              onChanged: (v) => _player.seek(
                  Duration(milliseconds: (v * total).round())),
            ),
          ),
        ),
        Text(formatClock(label),
            style: GoogleFonts.inter(
                fontSize: 11,
                color: widget.onDark ? Colors.white70 : AppTheme.textMid)),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// CALL LOG ENTRY (centered pill in the thread)
// ══════════════════════════════════════════
class CallLogChip extends StatelessWidget {
  final ChatMessage msg;
  const CallLogChip({super.key, required this.msg});

  @override
  Widget build(BuildContext context) {
    final missed = msg.text.toLowerCase().contains('missed') ||
        msg.text.toLowerCase().contains('declined');
    final time =
        msg.createdAt != null ? DateFormat('HH:mm').format(msg.createdAt!) : '';
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            msg.callVideo ? Icons.videocam_rounded : Icons.call_rounded,
            size: 16,
            color: missed ? AppTheme.red : AppTheme.green,
          ),
          const SizedBox(width: 8),
          Text(msg.text,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.navyDark)),
          if (time.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(time,
                style:
                    GoogleFonts.inter(fontSize: 11, color: AppTheme.textMute)),
          ],
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// HOLD-TO-RECORD MIC BUTTON
// ══════════════════════════════════════════
/// Hold to record, release to send, slide left to cancel.
class HoldToRecordButton extends StatefulWidget {
  final VoiceRecorder recorder;
  final Future<void> Function(VoiceClip clip) onRecorded;
  final double size;

  const HoldToRecordButton({
    super.key,
    required this.recorder,
    required this.onRecorded,
    this.size = 42,
  });

  @override
  State<HoldToRecordButton> createState() => _HoldToRecordButtonState();
}

class _HoldToRecordButtonState extends State<HoldToRecordButton> {
  static const _cancelDistance = 90.0;
  bool _cancelled = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    // Auto-send when the max length is reached.
    widget.recorder.onLimitReached = _finish;
  }

  @override
  void dispose() {
    if (widget.recorder.onLimitReached == _finish) {
      widget.recorder.onLimitReached = null;
    }
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _begin() async {
    _cancelled = false;
    _starting = true;
    HapticFeedback.mediumImpact();
    final ok = await widget.recorder.start();
    _starting = false;
    if (!ok && mounted) {
      _toast('Allow microphone access in Settings to send voice messages.');
    }
  }

  Future<void> _finish() async {
    if (!widget.recorder.recording) return;
    final clip = await widget.recorder.stop();
    if (clip == null) {
      if (mounted) _toast('Hold the mic to record a voice message.');
      return;
    }
    await widget.onRecorded(clip);
  }

  Future<void> _abort() async {
    _cancelled = true;
    HapticFeedback.lightImpact();
    await widget.recorder.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _toast('Hold to record, release to send.'),
      onLongPressStart: (_) => _begin(),
      onLongPressMoveUpdate: (d) {
        if (!_cancelled &&
            widget.recorder.recording &&
            d.offsetFromOrigin.dx < -_cancelDistance) {
          _abort();
        }
      },
      onLongPressEnd: (_) async {
        // If the press ended while start() was still running, wait for it.
        while (_starting) {
          await Future.delayed(const Duration(milliseconds: 30));
        }
        if (!_cancelled) await _finish();
      },
      child: ListenableBuilder(
        listenable: widget.recorder,
        builder: (_, __) {
          final rec = widget.recorder.recording;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: rec ? widget.size + 14 : widget.size,
            height: rec ? widget.size + 14 : widget.size,
            decoration: BoxDecoration(
              color: rec ? AppTheme.red : AppTheme.navy,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
          );
        },
      ),
    );
  }
}

/// Shown in place of the text field while recording.
class RecordingStrip extends StatelessWidget {
  final VoiceRecorder recorder;
  const RecordingStrip({super.key, required this.recorder});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: recorder,
      builder: (_, __) => Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.offWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          const _BlinkingDot(),
          const SizedBox(width: 8),
          Text(formatClock(recorder.elapsed),
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.navyDark)),
          const Spacer(),
          const Icon(Icons.chevron_left_rounded,
              size: 18, color: AppTheme.textMute),
          Text('Slide to cancel',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMute)),
        ]),
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _c,
        child: Container(
          width: 10,
          height: 10,
          decoration:
              const BoxDecoration(color: AppTheme.red, shape: BoxShape.circle),
        ),
      );
}

// ══════════════════════════════════════════
// DELETE HELPERS
// ══════════════════════════════════════════
/// "Are you sure?" dialog with a red Delete button. Returns true to delete.
Future<bool> confirmDelete(BuildContext context,
    {required String title, required String message}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 19, fontWeight: FontWeight.w800, color: AppTheme.navyDark)),
      content: Text(message,
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMid)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, color: AppTheme.textMute))),
        ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.red,
                shape: const StadiumBorder(),
                elevation: 0),
            child: Text('Delete',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800, color: Colors.white))),
      ],
    ),
  );
  return ok == true;
}

/// Long-press menu for a chat message. Returns true if "Delete" was chosen.
Future<bool> showMessageActions(BuildContext context, {String? copyText}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        if (copyText != null && copyText.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.copy_rounded, color: AppTheme.navy),
            title: const Text('Copy'),
            onTap: () => Navigator.pop(ctx, 'copy'),
          ),
        ListTile(
          leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.red),
          title: const Text('Delete for everyone',
              style: TextStyle(color: AppTheme.red)),
          onTap: () => Navigator.pop(ctx, 'delete'),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (choice == 'copy' && copyText != null) {
    await Clipboard.setData(ClipboardData(text: copyText));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Copied'), duration: Duration(seconds: 1)));
    }
    return false;
  }
  if (choice != 'delete' || !context.mounted) return false;
  return confirmDelete(context,
      title: 'Delete message?',
      message: 'This message will be removed for everyone in this chat.');
}
