import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// One sheet = list of rows, each row = list of cells (String, num, bool or null).
class SheetData {
  final String name;
  final List<List<Object?>> rows;
  SheetData(this.name, this.rows);
}

class UnsupportedFileException implements Exception {
  final String reason; // 'xls' or 'unknown'
  UnsupportedFileException(this.reason);
}

/// Reads .xlsx (and .csv) files without any native plugin.
class XlsxReader {
  static List<SheetData> readAny(List<int> bytes, String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.csv') || lower.endsWith('.txt')) {
      return [SheetData('CSV', parseCsv(utf8.decode(bytes, allowMalformed: true)))];
    }
    if (lower.endsWith('.xls')) throw UnsupportedFileException('xls');
    // xlsx files are zip files: they start with "PK"
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      // maybe a CSV with a different extension
      final text = utf8.decode(bytes, allowMalformed: true);
      if (text.contains(',') || text.contains('\t')) return [SheetData('CSV', parseCsv(text))];
      throw UnsupportedFileException('unknown');
    }
    return readXlsx(bytes);
  }

  static Iterable<XmlElement> _els(XmlNode n, String local) =>
      n.descendants.whereType<XmlElement>().where((e) => e.name.local == local);

  static String? _attr(XmlElement e, String local) {
    for (final a in e.attributes) {
      if (a.name.local == local) return a.value;
    }
    return null;
  }

  static String? _text(Archive a, String path) {
    final f = a.findFile(path);
    if (f == null) return null;
    return utf8.decode(f.content as List<int>, allowMalformed: true);
  }

  static List<SheetData> readXlsx(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    // shared strings
    final shared = <String>[];
    final ss = _text(archive, 'xl/sharedStrings.xml');
    if (ss != null) {
      final doc = XmlDocument.parse(ss);
      for (final si in _els(doc, 'si')) {
        // ignore phonetic runs (rPh)
        final buf = StringBuffer();
        for (final t in _els(si, 't')) {
          if (t.parentElement?.name.local == 'rPh') continue;
          buf.write(t.innerText);
        }
        shared.add(buf.toString());
      }
    }

    // sheet names -> files
    final rels = <String, String>{};
    final relXml = _text(archive, 'xl/_rels/workbook.xml.rels');
    if (relXml != null) {
      for (final r in _els(XmlDocument.parse(relXml), 'Relationship')) {
        final id = _attr(r, 'Id');
        var target = _attr(r, 'Target');
        if (id == null || target == null) continue;
        if (target.startsWith('/')) {
          target = target.substring(1);
        } else if (!target.startsWith('xl/')) {
          target = 'xl/$target';
        }
        rels[id] = target;
      }
    }
    final sheets = <MapEntry<String, String>>[];
    final wb = _text(archive, 'xl/workbook.xml');
    if (wb != null) {
      for (final s in _els(XmlDocument.parse(wb), 'sheet')) {
        final name = _attr(s, 'name') ?? 'Sheet';
        final rid = _attr(s, 'id'); // r:id
        final path = rid != null ? rels[rid] : null;
        if (path != null) sheets.add(MapEntry(name, path));
      }
    }
    if (sheets.isEmpty) {
      for (final f in archive.files) {
        if (f.name.startsWith('xl/worksheets/') && f.name.endsWith('.xml')) {
          sheets.add(MapEntry(f.name.split('/').last.replaceAll('.xml', ''), f.name));
        }
      }
    }

    final out = <SheetData>[];
    for (final s in sheets) {
      final xml = _text(archive, s.value);
      if (xml == null) continue;
      out.add(SheetData(s.key, _readSheet(XmlDocument.parse(xml), shared)));
    }
    return out;
  }

  static int _colIndex(String ref) {
    var n = 0;
    for (final ch in ref.codeUnits) {
      if (ch >= 65 && ch <= 90) {
        n = n * 26 + (ch - 64);
      } else if (ch >= 97 && ch <= 122) {
        n = n * 26 + (ch - 96);
      } else {
        break;
      }
    }
    return n - 1;
  }

  static List<List<Object?>> _readSheet(XmlDocument doc, List<String> shared) {
    final rows = <List<Object?>>[];
    var rowNo = 0;
    for (final row in _els(doc, 'row')) {
      final rAttr = int.tryParse(_attr(row, 'r') ?? '');
      final thisRow = rAttr != null ? rAttr - 1 : rowNo;
      rowNo = thisRow + 1;
      while (rows.length < thisRow) {
        rows.add(<Object?>[]);
      }
      final cells = <Object?>[];
      var col = 0;
      for (final c in row.childElements.where((e) => e.name.local == 'c')) {
        final ref = _attr(c, 'r');
        final idx = ref != null ? _colIndex(ref) : col;
        col = idx + 1;
        final type = _attr(c, 't');
        Object? value;
        final v = c.childElements.where((e) => e.name.local == 'v').map((e) => e.innerText).firstOrNull;
        if (type == 's') {
          final i = int.tryParse(v ?? '');
          value = (i != null && i >= 0 && i < shared.length) ? shared[i] : null;
        } else if (type == 'inlineStr') {
          value = _els(c, 't').map((e) => e.innerText).join();
        } else if (type == 'str' || type == 'e') {
          value = v;
        } else if (type == 'b') {
          value = v == '1';
        } else if (v != null && v.isNotEmpty) {
          value = num.tryParse(v) ?? v;
        }
        while (cells.length < idx) {
          cells.add(null);
        }
        if (idx >= 0) cells.add(value);
      }
      rows.add(cells);
    }
    return rows;
  }

  static List<List<Object?>> parseCsv(String text) {
    if (text.startsWith('﻿')) text = text.substring(1);
    final firstLine = text.split('\n').first;
    final sep = firstLine.split('\t').length > firstLine.split(',').length
        ? '\t'
        : (firstLine.split(';').length > firstLine.split(',').length ? ';' : ',');
    final rows = <List<Object?>>[];
    var row = <Object?>[];
    final cell = StringBuffer();
    var inQuotes = false;
    void endCell() {
      final s = cell.toString().trim();
      row.add(s.isEmpty ? null : (num.tryParse(s.replaceAll(',', '')) ?? s));
      cell.clear();
    }

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          cell.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == sep) {
        endCell();
      } else if (ch == '\n') {
        endCell();
        rows.add(row);
        row = <Object?>[];
      } else if (ch != '\r') {
        cell.write(ch);
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      endCell();
      rows.add(row);
    }
    return rows;
  }
}

/// Writes a simple but real .xlsx (opens in Excel, Google Sheets, WPS).
class XlsxWriter {
  final List<MapEntry<String, List<List<Object?>>>> _sheets = [];

  void addSheet(String name, List<List<Object?>> rows) {
    var safe = name.replaceAll(RegExp(r'[\[\]\*\?/\\:]'), ' ');
    if (safe.length > 31) safe = safe.substring(0, 31);
    _sheets.add(MapEntry(safe, rows));
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

  static String _col(int i) {
    var s = '';
    var n = i + 1;
    while (n > 0) {
      final m = (n - 1) % 26;
      s = String.fromCharCode(65 + m) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }

  String _sheetXml(List<List<Object?>> rows) {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    // column widths
    var maxCols = 0;
    for (final r in rows) {
      if (r.length > maxCols) maxCols = r.length;
    }
    if (maxCols > 0) {
      b.write('<cols>');
      for (var c = 0; c < maxCols; c++) {
        var w = 10;
        for (final r in rows.take(200)) {
          if (c < r.length && r[c] != null) {
            final l = r[c].toString().length + 2;
            if (l > w) w = l;
          }
        }
        if (w > 45) w = 45;
        b.write('<col min="${c + 1}" max="${c + 1}" width="$w" customWidth="1"/>');
      }
      b.write('</cols>');
    }
    b.write('<sheetData>');
    for (var r = 0; r < rows.length; r++) {
      b.write('<row r="${r + 1}">');
      for (var c = 0; c < rows[r].length; c++) {
        final v = rows[r][c];
        if (v == null) continue;
        final ref = '${_col(c)}${r + 1}';
        final style = r == 0 ? ' s="1"' : '';
        if (v is num) {
          b.write('<c r="$ref"$style><v>$v</v></c>');
        } else {
          b.write('<c r="$ref"$style t="inlineStr"><is><t xml:space="preserve">${_esc(v.toString())}</t></is></c>');
        }
      }
      b.write('</row>');
    }
    b.write('</sheetData></worksheet>');
    return b.toString();
  }

  List<int> encode() {
    final a = Archive();
    void add(String name, String content) {
      final data = utf8.encode(content);
      a.addFile(ArchiveFile(name, data.length, data));
    }

    final ct = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">')
      ..write('<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>')
      ..write('<Default Extension="xml" ContentType="application/xml"/>')
      ..write('<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>')
      ..write('<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>');
    for (var i = 0; i < _sheets.length; i++) {
      ct.write('<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>');
    }
    ct.write('</Types>');
    add('[Content_Types].xml', ct.toString());

    add('_rels/.rels',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>');

    final wb = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>');
    final rels = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    for (var i = 0; i < _sheets.length; i++) {
      wb.write('<sheet name="${_esc(_sheets[i].key)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>');
      rels.write('<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>');
      add('xl/worksheets/sheet${i + 1}.xml', _sheetXml(_sheets[i].value));
    }
    final stylesId = _sheets.length + 1;
    rels.write('<Relationship Id="rId$stylesId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>');
    wb.write('</sheets></workbook>');
    rels.write('</Relationships>');
    add('xl/workbook.xml', wb.toString());
    add('xl/_rels/workbook.xml.rels', rels.toString());
    add('xl/styles.xml',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>');

    return ZipEncoder().encode(a)!;
  }
}
