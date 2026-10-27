import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'admin_notify.dart';
import 'auth_routing.dart' show kPrimaryAdminEmail;

// ─────────────────────────────────────────
// ZEGOCLOUD in-app voice / video calls
// Console: https://console.zegocloud.com → your project → AppID + AppSign
// Supplied at build time: --dart-define-from-file=secrets.json
//   "ZEGO_APP_ID": "123456789", "ZEGO_APP_SIGN": "..."
// ─────────────────────────────────────────
const _zegoAppId   = int.fromEnvironment('ZEGO_APP_ID');
const _zegoAppSign = String.fromEnvironment('ZEGO_APP_SIGN');

/// Customers call TEHCS Support (the admin account); the admin can call a
/// customer back from their chat thread.
class CallService {
  /// Fixed call ID for the admin, so customers can reach support without
  /// knowing the admin's account ID.
  static const supportId   = 'tehcs_support';
  static const supportName = 'TEHCS Support';

  static bool get configured => _zegoAppId != 0 && _zegoAppSign.isNotEmpty;

  static String? _signedInAs;

  /// Sign this phone in to the call service (after app sign-in).
  static Future<void> start(User user) async {
    if (!configured) return;
    final isAdmin = user.email?.toLowerCase() == kPrimaryAdminEmail;
    final id = isAdmin ? supportId : user.uid;
    if (_signedInAs == id) return;
    if (_signedInAs != null) await stop();
    _signedInAs = id;
    final name = isAdmin
        ? supportName
        : ((user.displayName?.isNotEmpty ?? false)
            ? user.displayName!
            : (user.email?.split('@').first ?? 'Customer'));
    try {
      await ZegoUIKitPrebuiltCallInvitationService().init(
        appID: _zegoAppId,
        appSign: _zegoAppSign,
        userID: id,
        userName: name,
        plugins: [ZegoUIKitSignalingPlugin()],
        config: ZegoCallInvitationConfig(
          // Don't ask customers for "display over other apps"
          permissions: ZegoCallInvitationPermissions.withoutSystemAlertWindow,
        ),
        requireConfig: (data) => data.type == ZegoCallInvitationType.videoCall
            ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
            : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall(),
      );
    } catch (e) {
      debugPrint('Call service init failed: $e');
      _signedInAs = null;
    }
  }

  /// Sign out of the call service (on app sign-out).
  static Future<void> stop() async {
    if (_signedInAs == null) return;
    _signedInAs = null;
    try {
      await ZegoUIKitPrebuiltCallInvitationService().uninit();
    } catch (_) {}
  }

  /// Customer → TEHCS Support. Also logs the call in the chat and pushes a
  /// notification to the admin's phone in case the app is closed.
  static Future<bool> callSupport(BuildContext context, {required bool video}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (!_ready(context) || user == null) return false;
    final name = (user.displayName?.isNotEmpty ?? false)
        ? user.displayName!
        : (user.email?.split('@').first ?? 'A customer');
    final kind = video ? 'video call' : 'voice call';

    final ok = await ZegoUIKitPrebuiltCallInvitationService().send(
      invitees: [ZegoCallUser(supportId, supportName)],
      isVideoCall: video,
      notificationTitle: 'TEHCS: incoming $kind',
      notificationMessage: '$name is calling support',
      timeoutSeconds: 60,
    );

    try {
      await FirebaseFirestore.instance.collection('chats').add({
        'uid': user.uid,
        'name': name,
        'email': user.email ?? '',
        'text': video ? '🎥 Video call to support' : '📞 Voice call to support',
        'from': 'client',
        'imageUrl': '',
        'callType': video ? 'video' : 'voice',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    await notifyAdmin(
      type: 'customer_call',
      title: video ? '🎥 Incoming video call' : '📞 Incoming voice call',
      body: '$name is calling TEHCS Support. Missed it? Call them back from Support → their chat.',
      extra: {'clientUid': user.uid},
    );
    return ok;
  }

  /// Admin → customer (from the support chat thread).
  static Future<bool> callCustomer(BuildContext context,
      {required String uid, required String name, required bool video}) async {
    if (!_ready(context)) return false;
    return ZegoUIKitPrebuiltCallInvitationService().send(
      invitees: [ZegoCallUser(uid, name.isEmpty ? 'Customer' : name)],
      isVideoCall: video,
      notificationTitle: 'TEHCS Support is calling',
      notificationMessage: video ? 'Incoming video call' : 'Incoming voice call',
      timeoutSeconds: 60,
    );
  }

  static bool _ready(BuildContext context) {
    if (configured && _signedInAs != null) return true;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('In-app calls are not available right now. Please use phone or WhatsApp.'),
      behavior: SnackBarBehavior.floating,
    ));
    return false;
  }
}
