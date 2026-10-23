import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Builds an Excel workbook of bookings (one sheet per service) and opens the
/// share sheet so the admin can save or send it.
class BookingExport {
  static const _headers = [
    'Booking ID', 'Service', 'Category', 'Client', 'Email', 'Phone',
    'Date', 'Time', 'Hours', 'Address', 'Notes', 'Pay Method', 'Status',
    'Booked On',
  ];

  /// Category label used in the app for bookings without one.
  static const uncategorised = 'Other';

  static String categoryOf(Map<String, dynamic> d) {
    final c = (d['category'] ?? '').toString().trim();
    return c.isEmpty ? uncategorised : c;
  }

  /// Exports [docs] and returns the number of bookings written.
  static Future<int> exportAndShare(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required String title,
  }) async {
    final excel = Excel.createExcel();
    final byCategory = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final d in docs) {
      byCategory.putIfAbsent(categoryOf(d.data()), () => []).add(d);
    }
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    for (final entry in byCategory.entries) {
      final sheet = excel[_sheetName(entry.key)];
      sheet.appendRow(_headers.map((h) => TextCellValue(h)).toList());
      for (final doc in entry.value) {
        final d = doc.data();
        final created = (d['createdAt'] as Timestamp?)?.toDate();
        sheet.appendRow([
          TextCellValue(doc.id),
          TextCellValue('${d['service'] ?? ''}'),
          TextCellValue(categoryOf(d)),
          TextCellValue('${d['clientName'] ?? ''}'),
          TextCellValue('${d['clientEmail'] ?? ''}'),
          TextCellValue('${d['phone'] ?? ''}'),
          TextCellValue('${d['date'] ?? ''}'),
          TextCellValue('${d['time'] ?? ''}'),
          IntCellValue((d['hours'] as num?)?.toInt() ?? 0),
          TextCellValue('${d['address'] ?? ''}'),
          TextCellValue('${d['notes'] ?? ''}'),
          TextCellValue('${d['payMethod'] ?? ''}'),
          TextCellValue('${d['status'] ?? ''}'),
          TextCellValue(created != null ? fmt.format(created) : ''),
        ]);
      }
    }
    // Remove the empty default sheet
    final def = excel.getDefaultSheet();
    if (def != null && !byCategory.keys.map(_sheetName).contains(def)) {
      excel.delete(def);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Could not create the Excel file.');
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final safeTitle = title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final file = File('${dir.path}/TEHCS_${safeTitle}_$stamp.xlsx');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      subject: 'TEHCS bookings — $title',
    ));
    return docs.length;
  }

  // Excel sheet names: max 31 chars, no : \ / ? * [ ]
  static String _sheetName(String s) {
    final clean = s.replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ').trim();
    return clean.length > 31 ? clean.substring(0, 31) : clean;
  }

  /// Permanently deletes the given bookings (admin only — enforced by rules).
  static Future<void> deleteAll(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final db = FirebaseFirestore.instance;
    for (var i = 0; i < docs.length; i += 400) {
      final batch = db.batch();
      for (final d in docs.skip(i).take(400)) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }
}
