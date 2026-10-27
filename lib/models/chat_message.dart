import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String uid;
  final String name;
  final String email;
  final String text;
  final String from; // 'client' or 'agent'
  final String imageUrl; // '' when no image
  final String audioUrl; // '' when no voice note (data:audio/mp4;base64,...)
  final int audioSeconds;
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
    this.audioSeconds = 0,
    this.createdAt,
  });

  bool get isClient => from == 'client';
  bool get hasImage => imageUrl.isNotEmpty;
  bool get hasAudio => audioUrl.isNotEmpty;

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
      audioSeconds: (data['audioSeconds'] as num?)?.toInt() ?? 0,
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
        'createdAt': FieldValue.serverTimestamp(),
      };
}
