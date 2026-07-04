import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id;
  final String uid;
  final String clientName;
  final String clientEmail;
  final String phone;
  final String service;
  final String icon;
  final String date;
  final String time;
  final String address;
  final String notes;
  final String status;
  final DateTime? createdAt;

  const Booking({
    required this.id,
    required this.uid,
    required this.clientName,
    required this.clientEmail,
    required this.phone,
    required this.service,
    required this.icon,
    required this.date,
    required this.time,
    required this.address,
    required this.notes,
    required this.status,
    this.createdAt,
  });

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Booking(
      id:          doc.id,
      uid:         d['uid']         ?? '',
      clientName:  d['clientName']  ?? '',
      clientEmail: d['clientEmail'] ?? '',
      phone:       d['phone']       ?? '',
      service:     d['service']     ?? '',
      icon:        d['icon']        ?? '🔧',
      date:        d['date']        ?? '',
      time:        d['time']        ?? 'Flexible',
      address:     d['address']     ?? '',
      notes:       d['notes']       ?? '',
      status:      d['status']      ?? 'pending',
      createdAt:   (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':         uid,
    'clientName':  clientName,
    'clientEmail': clientEmail,
    'phone':       phone,
    'service':     service,
    'icon':        icon,
    'date':        date,
    'time':        time,
    'address':     address,
    'notes':       notes,
    'status':      status,
    'createdAt':   FieldValue.serverTimestamp(),
  };

  Color get statusColor => switch (status) {
    'active'   => const Color(0xFF16A34A),
    'complete' => const Color(0xFF1B2B5E),
    _          => const Color(0xFFD4891A),
  };

  String get statusLabel => switch (status) {
    'active'   => 'Active',
    'complete' => 'Complete',
    _          => 'Pending',
  };
}