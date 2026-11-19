import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String uid;
  final String name;
  final String email;
  final String text;
  final String from; // 'client' or 'agent'/'staff'
  final String imageUrl; // '' when no image
  final String audioUrl; // '' when not a voice note
  final int audioMs; // voice note length
  final String type; // 'text' | 'voice' | 'call'
  final bool callVideo; // for type == 'call'
  final DateTime? createdAt;

  ChatMessage({
    required this.id,
    required this.uid,
    required this.name,
    required this.email,
    required this.text,
    required this.from,
    this.imageUrl = '',
    this.audioUrl = '',
    this.audioMs = 0,
    this.type = 'text',
    this.callVideo = false,
    this.createdAt,
  });

  bool get isClient => from == 'client';
  bool get hasImage => imageUrl.isNotEmpty;
  bool get hasAudio => audioUrl.isNotEmpty;
  bool get isCallLog => type == 'call';

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      uid: data['uid'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      text: data['text'] ?? '',
      from: data['from'] ?? 'client',
      imageUrl: data['imageUrl'] ?? '',
      audioUrl: data['audioUrl'] ?? '',
      audioMs: (data['audioMs'] as num?)?.toInt() ?? 0,
      type: data['type'] ?? 'text',
      callVideo: data['callVideo'] == true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'text': text,
        'from': from,
        'imageUrl': imageUrl,
        if (audioUrl.isNotEmpty) 'audioUrl': audioUrl,
        if (audioUrl.isNotEmpty) 'audioMs': audioMs,
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
