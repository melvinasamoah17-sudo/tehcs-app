import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Drops a notification for the admin into Firestore. The admin portal shows
/// these live (bell + unread count). Failures are swallowed on purpose: a
/// notification problem must never block a staff member's real action.
Future<void> notifyAdmin({
  required String type,
  required String title,
  required String body,
  Map<String, dynamic> extra = const {},
}) async {
  try {
    await FirebaseFirestore.instance.collection('notifications').add({
      'forAdmin':  true,
      'type':      type,
      'title':     title,
      'body':      body,
      'read':      false,
      'staffId':   FirebaseAuth.instance.currentUser?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      ...extra,
    });
  } catch (_) {}
}
