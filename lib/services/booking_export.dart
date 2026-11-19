import 'dart:io';
import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    final byCategory = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final d in docs) {
      byCategory.putIfAbsent(categoryOf(d.data()), () => []).add(d);
    }
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    final sheets = <String, List<List<Object>>>{};
    final usedNames = <String>{};
    for (final entry in byCategory.entries) {
      var name = _sheetName(entry.key);
      for (var i = 2; usedNames.contains(name.toLowerCase()); i++) {
        name = _sheetName('${entry.key} $i');
      }
      usedNames.add(name.toLowerCase());
      sheets[name] = [
        _headers,
        for (final doc in entry.value)
          () {
            final d = doc.data();
            final created = (d['createdAt'] as Timestamp?)?.toDate();
            return <Object>[
              doc.id,
              '${d['service'] ?? ''}',
              categoryOf(d),
              '${d['clientName'] ?? ''}',
              '${d['clientEmail'] ?? ''}',
              '${d['phone'] ?? ''}',
              '${d['date'] ?? ''}',
              '${d['time'] ?? ''}',
              (d['hours'] as num?)?.toInt() ?? 0,
              '${d['address'] ?? ''}',
              '${d['notes'] ?? ''}',
              '${d['payMethod'] ?? ''}',
              '${d['status'] ?? ''}',
              created != null ? fmt.format(created) : '',
            ];
          }(),
      ];
    }

    final bytes = _XlsxWriter.build(sheets);
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
    final name = clean.isEmpty ? uncategorised : clean;
    return name.length > 31 ? name.substring(0, 31) : name;
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

/// Minimal .xlsx (Office Open XML) writer: text and whole-number cells,
/// bold header row. An .xlsx file is a zip of a few XML files.
class _XlsxWriter {
  static List<int> build(Map<String, List<List<Object>>> sheets) {
    final names = sheets.keys.toList();
    final archive = Archive();
    void add(String path, String xml) => archive.addFile(ArchiveFile.string(path, xml));

    add('[Content_Types].xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
${[for (var i = 1; i <= names.length; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join('\n')}
</Types>''');

    add('_rels/.rels', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''');

    add('xl/workbook.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets>
${[for (var i = 0; i < names.length; i++) '<sheet name="${_esc(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join('\n')}
</sheets>
</workbook>''');

    add('xl/_rels/workbook.xml.rels', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
${[for (var i = 1; i <= names.length; i++) '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>'].join('\n')}
<Relationship Id="rId${names.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''');

    // Style 0 = normal, style 1 = bold (header row)
    add('xl/styles.xml', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>
<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>
</styleSheet>''');

    for (var i = 0; i < names.length; i++) {
      final rows = sheets[names[i]]!;
      final b = StringBuffer()
        ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n')
        ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
        ..write('<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>')
        ..write('<sheetData>');
      for (var r = 0; r < rows.length; r++) {
        b.write('<row r="${r + 1}">');
        for (var c = 0; c < rows[r].length; c++) {
          final ref = '${_col(c)}${r + 1}';
          final style = r == 0 ? ' s="1"' : '';
          final v = rows[r][c];
          if (v is num) {
            b.write('<c r="$ref"$style><v>$v</v></c>');
          } else {
            b.write('<c r="$ref"$style t="inlineStr"><is><t xml:space="preserve">${_esc('$v')}</t></is></c>');
          }
        }
        b.write('</row>');
      }
      b.write('</sheetData></worksheet>');
      add('xl/worksheets/sheet${i + 1}.xml', b.toString());
    }
    return ZipEncoder().encode(archive);
  }

  static String _col(int i) {
    var s = '';
    for (var n = i + 1; n > 0; n = (n - 1) ~/ 26) {
      s = String.fromCharCode(65 + (n - 1) % 26) + s;
    }
    return s;
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      // Strip control characters Excel rejects (keep tab/newline)
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
}
