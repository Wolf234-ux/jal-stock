import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../store.dart';
import 'xlsx_io.dart';

/// English entry type names used in Excel (the importer understands them back).
String entryTypeExcel(EntryType e) => switch (e) {
      EntryType.stockIn => 'Stock In',
      EntryType.sale => 'Sale',
      EntryType.emptyReturn => 'Empty Return',
      EntryType.fill => 'Fill',
      EntryType.damage => 'Damage',
      EntryType.adjust => 'Adjust',
      EntryType.payment => 'Payment',
    };

const stockHeader = ['Item', 'Unit', 'Stock', 'Empty Jars', 'Selling Price', 'Buying Cost', 'Min Stock'];
const customerHeader = ['Customer', 'Phone', 'Area', 'Jars With Customer', 'Pending Amount'];
const entryHeader = ['Date', 'Type', 'Item', 'Customer', 'Qty', 'Empty Back', 'Amount', 'Paid', 'Note'];

class ExcelExport {
  static Future<File> _write(String baseName, XlsxWriter w) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
    final f = File('${dir.path}/${baseName}_$stamp.xlsx');
    await f.writeAsBytes(w.encode(), flush: true);
    return f;
  }

  static Future<void> _share(File f) async {
    await Share.shareXFiles([XFile(f.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')]);
  }

  /// Full backup / report: Stock, Customers, Entries, Summary.
  static Future<void> fullReport(AppStore st) async {
    final w = XlsxWriter();
    w.addSheet('Stock', [
      [...stockHeader, 'With Customers', 'Status', 'Order Now'],
      for (final p in st.products)
        () {
          final i = st.stockOf(p);
          return <Object?>[
            p.name,
            p.returnable ? 'Jar' : p.unit,
            i.full,
            p.returnable ? i.empty : null,
            p.price,
            p.cost,
            p.minStockManual ?? (i.minStock > 0 ? i.minStock : null),
            p.returnable ? i.withCustomers : null,
            i.level.name.toUpperCase(),
            i.suggestedOrder > 0 ? i.suggestedOrder : null,
          ];
        }(),
    ]);
    w.addSheet('Customers', [
      customerHeader,
      for (final c in st.customers)
        () {
          final ci = st.customerInfo(c);
          return <Object?>[c.name, c.phone, c.area, ci.jarsHeld, double.parse(ci.due.toStringAsFixed(2))];
        }(),
    ]);
    final df = DateFormat('yyyy-MM-dd HH:mm');
    w.addSheet('Entries', [
      entryHeader,
      for (final e in [...st.entries]..sort((a, b) => a.date.compareTo(b.date)))
        <Object?>[
          df.format(e.date),
          entryTypeExcel(e.type),
          st.productById(e.productId)?.name,
          st.customerById(e.customerId)?.name,
          e.type == EntryType.payment ? null : e.qty,
          e.emptyBack == 0 ? null : e.emptyBack,
          e.amount == 0 ? null : e.amount,
          e.paid == 0 ? null : e.paid,
          e.note.isEmpty ? null : e.note,
        ],
    ]);
    await _share(await _write('JalStock_Report', w));
  }

  /// Blank format the shop owner can fill and upload.
  static Future<void> template() async {
    final w = XlsxWriter();
    w.addSheet('Stock', [
      stockHeader,
      ['20 Litre Jar', 'Jar', 150, 40, 40, 15, null],
      ['1 Litre Bottle (Box of 12)', 'Box', 60, null, 120, 85, 20],
      ['500 ml Bottle (Box of 24)', 'Box', 45, null, 140, 100, null],
    ]);
    w.addSheet('Customers', [
      customerHeader,
      ['Ramesh Tea Stall', '9876543210', 'Station Road', 4, 320],
      ['Shiv Hardware', '9898989898', 'Main Bazaar', 2, 0],
    ]);
    w.addSheet('Entries', [
      entryHeader,
      [DateFormat('yyyy-MM-dd').format(DateTime.now()), 'Sale', '20 Litre Jar', 'Ramesh Tea Stall', 5, 3, 200, 200, null],
    ]);
    await _share(await _write('JalStock_Format', w));
  }
}
