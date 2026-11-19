import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/call/call_screen.dart';
import '../screens/call/incoming_call_screen.dart';
import 'auth_routing.dart';

/// Voice/video calls between customers and the TEHCS admin, over Agora.
///
/// A call is a `calls/{id}` document:
///   callerUid, callerName, calleeUid ('' when calling the admin), toAdmin,
///   video, status (ringing → accepted → ended | declined | missed | cancelled),
///   clientUid/clientName/clientEmail (whose chat thread gets the call log),
///   createdAt, answeredAt, endedAt.
/// The Agora channel name is the document id.
class CallService {
  static const ringTimeout = Duration(seconds: 45);

  static GlobalKey<NavigatorState>? _nav;
  static StreamSubscription<User?>? _authSub;
  static StreamSubscription<QuerySnapshot>? _incomingSub;
  static final Set<String> _handled = {};

  /// True while a call (incoming, outgoing or active) is on screen.
  static bool inCall = false;

  static CollectionReference<Map<String, dynamic>> get calls =>
      FirebaseFirestore.instance.collection('calls');

  static bool get isAdmin =>
      (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase() ==
      kPrimaryAdminEmail;

  /// Call once from the app root. Starts listening for incoming calls
  /// whenever someone is signed in.
  static void init(GlobalKey<NavigatorState> nav) {
    _nav = nav;
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen(_listenFor);
  }

  static void _listenFor(User? user) {
    _incomingSub?.cancel();
    _incomingSub = null;
    if (user == null) return;

    final admin = (user.email ?? '').toLowerCase() == kPrimaryAdminEmail;
    Query<Map<String, dynamic>> q = admin
        ? calls.where('toAdmin', isEqualTo: true)
        : calls.where('calleeUid', isEqualTo: user.uid);
    q = q.where('status', isEqualTo: 'ringing');

    _incomingSub = q.snapshots().listen((snap) {
      for (final doc in snap.docs) {
        final d = doc.data();
        if (d['callerUid'] == user.uid) continue;
        if (_handled.contains(doc.id)) continue;
        final created = (d['createdAt'] as Timestamp?)?.toDate();
        if (created != null &&
            DateTime.now().difference(created) > ringTimeout) {
          continue; // stale
        }
        _handled.add(doc.id);
        if (inCall) continue; // busy: caller will time out → missed call
        _nav?.currentState?.push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => IncomingCallScreen(
            callId: doc.id,
            callerName: d['callerName'] ?? 'Caller',
            video: d['video'] == true,
          ),
        ));
      }
    }, onError: (e) => debugPrint('Incoming call listener: $e'));
  }

  /// Starts a call. Customers call the admin ([toAdmin] = true);
  /// the admin calls a customer back by passing their uid as [calleeUid].
  static Future<void> start(
    BuildContext context, {
    required bool video,
    required bool toAdmin,
    String calleeUid = '',
    required String peerName,
    required String clientUid,
    required String clientName,
    required String clientEmail,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || inCall) return;
    final myName = isAdmin
        ? 'TEHCS Support'
        : (me.displayName?.isNotEmpty == true
            ? me.displayName!
            : (me.email?.split('@').first ?? 'Customer'));

    final ref = calls.doc();
    try {
      await ref.set({
        'callerUid': me.uid,
        'callerName': myName,
        'calleeUid': toAdmin ? '' : calleeUid,
        'toAdmin': toAdmin,
        'video': video,
        'status': 'ringing',
        'clientUid': clientUid,
        'clientName': clientName,
        'clientEmail': clientEmail,
        'callerIsClient': !isAdmin,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not start the call.')));
      }
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CallScreen(
        callId: ref.id,
        video: video,
        isCaller: true,
        peerName: peerName,
      ),
    ));
  }

  static Future<void> setStatus(String callId, String status) async {
    final now = FieldValue.serverTimestamp();
    await calls.doc(callId).update({
      'status': status,
      if (status == 'accepted') 'answeredAt': now,
      if (status != 'accepted') 'endedAt': now,
    });
  }

  /// Asks the Cloud Function for an Agora token for this call.
  static Future<AgoraJoinInfo> joinInfo(String callId) async {
    final res = await FirebaseFunctions.instance
        .httpsCallable('getAgoraToken')
        .call({'callId': callId});
    final d = Map<String, dynamic>.from(res.data as Map);
    return AgoraJoinInfo(
      appId: d['appId'] as String,
      token: d['token'] as String,
      uid: (d['uid'] as num).toInt(),
      channel: d['channel'] as String,
    );
  }

  /// Adds a "Voice call · 2:31" / "Missed video call" entry to the
  /// customer's chat thread. Only the caller writes it, so it appears once.
  static Future<void> logToChat(
      Map<String, dynamic> call, String outcome, Duration? talked) async {
    final video = call['video'] == true;
    final kind = video ? 'video call' : 'voice call';
    final text = switch (outcome) {
      'ended' when talked != null =>
        '${video ? 'Video' : 'Voice'} call · ${_fmt(talked)}',
      'declined' => 'Declined $kind',
      _ => 'Missed $kind',
    };
    try {
      await FirebaseFirestore.instance.collection('chats').add({
        'uid': call['clientUid'] ?? '',
        'name': call['clientName'] ?? '',
        'email': call['clientEmail'] ?? '',
        'text': text,
        'from': call['callerIsClient'] == true ? 'client' : 'staff',
        'imageUrl': '',
        'type': 'call',
        'callVideo': video,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Call log failed: $e');
    }
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }
}

class AgoraJoinInfo {
  final String appId;
  final String token;
  final int uid;
  final String channel;
  const AgoraJoinInfo(
      {required this.appId,
      required this.token,
      required this.uid,
      required this.channel});
}
