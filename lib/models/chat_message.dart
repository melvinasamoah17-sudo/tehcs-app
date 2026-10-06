import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String uid;
  final String name;
  final String email;
  final String text;
  final String from; // 'client' or 'agent'
  final String imageUrl; // '' when no image
  final DateTime? createdAt;

  ChatMessage({
    required this.id,
    required this.uid,
    required this.name,
    required this.email,
    required this.text,
    required this.from,
    this.imageUrl = '',
    this.createdAt,
  });

  bool get isClient => from == 'client';
  bool get hasImage => imageUrl.isNotEmpty;

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
