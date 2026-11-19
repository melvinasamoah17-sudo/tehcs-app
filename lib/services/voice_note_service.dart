import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// A finished recording waiting to be sent.
class VoiceClip {
  final File file;
  final Duration duration;
  const VoiceClip(this.file, this.duration);
}

/// Records voice notes (hold-to-record, WhatsApp style).
/// Listen to it to show the timer while recording.
class VoiceRecorder extends ChangeNotifier {
  static const maxLength = Duration(minutes: 5);
  static const minLength = Duration(milliseconds: 800);

  final _rec = AudioRecorder();
  Timer? _ticker;
  DateTime? _startedAt;

  bool recording = false;
  Duration elapsed = Duration.zero;

  /// Called when [maxLength] is reached; the owner should call [stop].
  VoidCallback? onLimitReached;

  /// Returns false if the microphone permission was refused.
  Future<bool> start() async {
    if (recording) return true;
    if (!await _rec.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );
    recording = true;
    _startedAt = DateTime.now();
    elapsed = Duration.zero;
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      elapsed = DateTime.now().difference(_startedAt!);
      notifyListeners();
      if (elapsed >= maxLength) onLimitReached?.call();
    });
    notifyListeners();
    return true;
  }

  /// Stops and returns the clip, or null if it was too short to keep.
  Future<VoiceClip?> stop() async {
    if (!recording) return null;
    _ticker?.cancel();
    final path = await _rec.stop();
    final length = DateTime.now().difference(_startedAt!);
    _reset();
    if (path == null) return null;
    final file = File(path);
    if (length < minLength) {
      await _deleteQuietly(file);
      return null;
    }
    return VoiceClip(file, length);
  }

  Future<void> cancel() async {
    if (!recording) return;
    _ticker?.cancel();
    await _rec.cancel();
    _reset();
  }

  void _reset() {
    recording = false;
    elapsed = Duration.zero;
    _startedAt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _rec.dispose();
    super.dispose();
  }
}

class VoiceNoteService {
  /// Uploads [clip] to Storage and posts it in the client's chat thread.
  /// [clientUid]/[clientName]/[clientEmail] identify the conversation;
  /// [from] is 'client' or 'staff'.
  static Future<void> send({
    required VoiceClip clip,
    required String clientUid,
    required String clientName,
    required String clientEmail,
    required String from,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw StateError('Not signed in');

    final ref = FirebaseStorage.instance.ref(
        'chat_audio/${me.uid}/${DateTime.now().millisecondsSinceEpoch}.m4a');
    await ref.putFile(clip.file, SettableMetadata(contentType: 'audio/mp4'));
    final url = await ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('chats').add({
      'uid': clientUid,
      'name': clientName,
      'email': clientEmail,
      'text': '🎤 Voice message',
      'from': from,
      if (from != 'client')
        'repliedBy': me.email ?? me.displayName ?? 'Staff',
      'imageUrl': '',
      'audioUrl': url,
      'audioMs': clip.duration.inMilliseconds,
      'type': 'voice',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _deleteQuietly(clip.file);
  }
}

Future<void> _deleteQuietly(File f) async {
  try {
    await f.delete();
  } catch (_) {}
}
