import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Registers this phone for push notifications. Call once after sign-in
/// (admin and staff). The token is stored in `device_tokens/{uid}` and the
/// Cloud Functions use it to send notifications.
class PushService {
  static bool _started = false;

  static Future<void> init() async {
    if (kIsWeb || _started) return; // phones only
    _started = true;
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        _started = false;
        return;
      }
      final fm = FirebaseMessaging.instance;
      final settings =
          await fm.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await fm.getToken();
      if (token != null) await _save(token);
      fm.onTokenRefresh.listen(_save);
    } catch (_) {
      // Push is a bonus; it must never break sign-in.
      _started = false;
    }
  }

  static Future<void> _save(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('device_tokens').doc(user.uid).set({
      'email': (user.email ?? '').toLowerCase(),
      'tokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
