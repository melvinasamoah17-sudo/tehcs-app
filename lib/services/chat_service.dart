import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Deleting chat messages and whole conversations ("delete for everyone").
///
/// Messages live in `chats/{id}` with `uid` = the customer whose thread it is.
/// Voice notes also have a file in Storage at `chat_audio/{clientUid}/...`.
class ChatService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get chats =>
      _db.collection('chats');

  /// Deletes one message (and its voice-note file, if any).
  static Future<void> deleteMessage(String messageId, {String audioUrl = ''}) async {
    await chats.doc(messageId).delete();
    await _deleteAudio(audioUrl);
  }

  /// Deletes every message in a customer's thread, plus voice-note files.
  /// Returns how many messages were removed.
  static Future<int> deleteConversation(String clientUid) async {
    var total = 0;
    while (true) {
      // Firestore batches hold up to 500 writes; stay well under.
      final snap =
          await chats.where('uid', isEqualTo: clientUid).limit(300).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      final audio = <String>[];
      for (final d in snap.docs) {
        batch.delete(d.reference);
        final url = d.data()['audioUrl'];
        if (url is String && url.isNotEmpty) audio.add(url);
      }
      await batch.commit();
      total += snap.docs.length;
      await Future.wait(audio.map(_deleteAudio));
    }
    return total;
  }

  /// Removes everything a customer leaves behind when deleting their account:
  /// their chat thread, any leftover voice-note files and their call records.
  static Future<void> deleteAllForAccount(String uid) async {
    await deleteConversation(uid);

    // Any files left in their thread folder.
    try {
      final list =
          await FirebaseStorage.instance.ref('chat_audio/$uid').listAll();
      await Future.wait(list.items.map((r) => r.delete().catchError((_) {})));
    } catch (e) {
      debugPrint('Voice note cleanup: $e');
    }

    // Call records where they were the caller or the person called.
    final calls = _db.collection('calls');
    for (final field in ['callerUid', 'calleeUid']) {
      try {
        final snap = await calls.where(field, isEqualTo: uid).get();
        for (final d in snap.docs) {
          await d.reference.delete().catchError((_) {});
        }
      } catch (e) {
        debugPrint('Call cleanup ($field): $e');
      }
    }
  }

  /// Best-effort: a missing file or no permission must not block deleting
  /// the message itself. Older inline (data:) voice notes have no file.
  static Future<void> _deleteAudio(String url) async {
    if (url.isEmpty || url.startsWith('data:')) return;
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (e) {
      debugPrint('Voice note file not deleted: $e');
    }
  }
}
