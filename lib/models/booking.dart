import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String   id;
  final String   uid;
  final String   service;
  final String   category;
  final String   icon;
  final String   date;
  final String   time;
  final int      hours;
  final String   address;
  final String   notes;
  final String   payMethod;
  final String   status;
  final String   clientName;
  final String   clientEmail;
  final String   phone;
  final DateTime? createdAt;

  const Booking({
    required this.id,
    required this.uid,
    required this.service,
    this.category = '',
    required this.icon,
    required this.date,
    required this.time,
    required this.hours,
    required this.address,
    required this.notes,
    required this.payMethod,
    required this.status,
    required this.clientName,
    required this.clientEmail,
    this.phone    = '',
    this.createdAt,
  });

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Booking(
      id:          doc.id,
      uid:         d['uid']         as String? ?? '',
      service:     d['service']     as String? ?? '',
      category:    d['category']    as String? ?? '',
      icon:        d['icon']        as String? ?? '📋',
      date:        d['date']        as String? ?? '',
      time:        d['time']        as String? ?? '',
      hours:       (d['hours']      as num?)?.toInt() ?? 0,
      address:     d['address']     as String? ?? '',
      notes:       d['notes']       as String? ?? '',
      payMethod:   d['payMethod']   as String? ?? '',
      status:      d['status']      as String? ?? 'pending',
      clientName:  d['clientName']  as String? ?? '',
      clientEmail: d['clientEmail'] as String? ?? '',
      phone:       d['phone']       as String? ?? '',
      createdAt:  (d['createdAt']   as Timestamp?)?.toDate(),
    );
  }

  Color get statusColor => switch (status) {
    'active'    => const Color(0xFF16a34a),
    'complete'  => const Color(0xFF1B2B5E),
    'cancelled' => const Color(0xFFE63329),
    _           => const Color(0xFFB07D1A),
  };

  Map<String, dynamic> toMap() => {
    'uid':         uid,
    'service':     service,
    'category':    category,
    'icon':        icon,
    'date':        date,
    'time':        time,
    'hours':       hours,
    'address':     address,
    'notes':       notes,
    'payMethod':   payMethod,
    'status':      status,
    'clientName':  clientName,
    'clientEmail': clientEmail,
    'phone':       phone,
    'createdAt':   FieldValue.serverTimestamp(),
  };
}
