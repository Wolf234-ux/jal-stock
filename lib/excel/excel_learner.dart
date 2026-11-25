import 'package:intl/intl.dart';

import '../models.dart';
import '../rules.dart';
import '../store.dart';
import 'xlsx_io.dart';

/// What a column means.
enum Field {
  product, qty, empty, price, cost, min, unit, date, type, inQty, outQty,
  customer, phone, area, jars, due, paid, amount,
}

/// Keywords for each field (English, Gujarati, Hindi, Hinglish).
/// ORDER MATTERS: more specific fields are checked first.
const List<MapEntry<Field, List<String>>> _keywords = [
  MapEntry(Field.qty, ['total stock', 'total qty', 'total quantity', 'stock level', 'stock now']),
  MapEntry(Field.jars, ['jars with', 'jar with', 'jars held', 'jars out', 'jar balance', 'jar pending', 'jars pending', 'pending jar', 'jar due', 'jar baki', 'jars baki', 'baki jar', 'ગ્રાહક પાસે જાર', 'જાર બાકી', 'जार बाकी']),
  MapEntry(Field.min, ['minimum', 'min stock', 'min qty', 'min.', 'reorder', 're-order', 'alert', 'safety', 'ઓછામાં ઓછ', 'कम से कम', 'न्यूनतम']),
  MapEntry(Field.cost, ['cost', 'purchase rate', 'purchase price', 'buy rate', 'buying', 'kharid', 'ખરીદ ભાવ', 'खरीद भाव', 'लागत']),
  MapEntry(Field.price, ['rate', 'price', 'mrp', 'selling', 'bhav', 'ભાવ', 'भाव', 'दर', 'કિંમત', 'कीमत']),
  MapEntry(Field.phone, ['phone', 'mobile', 'contact', 'mob', 'whatsapp', 'ફોન', 'મોબાઇલ', 'फ़ोन', 'फोन', 'मोबाइल']),
  MapEntry(Field.area, ['area', 'address', 'location', 'city', 'village', 'route', 'વિસ્તાર', 'સરનામ', 'ગામ', 'पता', 'इलाका', 'गांव', 'गाँव']),
  MapEntry(Field.due, ['due', 'pending amount', 'balance amount', 'outstanding', 'udhar', 'baki', 'credit', 'બાકી', 'ઉધાર', 'बाकी', 'उधार']),
  MapEntry(Field.paid, ['paid', 'payment', 'cash', 'received amount', 'amount received', 'jama', 'chukv', 'ચૂકવ', 'જમા', 'भुगतान', 'जमा']),
  MapEntry(Field.amount, ['amount', 'total', 'value', 'bill', 'rakam', 'રકમ', 'रकम', 'कुल']),
  MapEntry(Field.empty, ['empty', 'khali', 'return', 'ખાલી', 'खाली', 'वापस']),
  MapEntry(Field.date, ['date', 'dt', 'day', 'tarikh', 'તારીખ', 'तारीख', 'दिनांक']),
  MapEntry(Field.type, ['type', 'in/out', 'transaction', 'voucher', 'prakar', 'પ્રકાર', 'प्रकार']),
  MapEntry(Field.inQty, ['in qty', 'qty in', 'inward', 'received', 'purchase', 'production', 'produced', 'stock in', 'aavak', 'આવક', 'आवक']),
  MapEntry(Field.outQty, ['out qty', 'qty out', 'outward', 'sold', 'sale', 'issued', 'deliver', 'dispatch', 'vechan', 'વેચાણ', 'જાવક', 'बिक्री', 'जावक']),
  MapEntry(Field.customer, ['customer', 'party', 'client', 'grahak', 'buyer', 'shop name', 'ગ્રાહક', 'ग्राहक', 'पार्टी']),
  MapEntry(Field.unit, ['unit', 'uom', 'pack', 'એકમ', 'इकाई']),
  MapEntry(Field.qty, ['qty', 'quantity', 'stock', 'nos', 'pcs', 'balance', 'closing', 'opening', 'current', 'available', 'count', 'jaththo', 'jaththa', 'nang', 'જથ્થો', 'નંગ', 'સ્ટોક', 'नंग', 'मात्रा', 'स्टॉक']),
  MapEntry(Field.product, ['product', 'item', 'name', 'particulars', 'material', 'brand', 'description', 'maal', 'saman', 'sku', 'size', 'ઉત્પાદન', 'વસ્તુ', 'માલ', 'નામ', 'सामान', 'माल', 'उत्पाद', 'नाम']),
];

Field? fieldForHeader(String header) {
  final h = header.toLowerCase().trim();
  if (h.isEmpty) return null;
  if (h == 'in') return Field.inQty;
  if (h == 'out') return Field.outQty;
  for (final kw in _keywords) {
    for (final k in kw.value) {
      if (h.contains(k)) return kw.key;
    }
  }
  return null;
}

String fieldLabel(Field f, String lang) {
  const en = {
    Field.product: 'Item', Field.qty: 'Stock / Qty', Field.empty: 'Empty jars', Field.price: 'Selling price',
    Field.cost: 'Buying cost', Field.min: 'Minimum stock', Field.unit: 'Unit', Field.date: 'Date',
    Field.type: 'Entry type', Field.inQty: 'Stock in', Field.outQty: 'Sold', Field.customer: 'Customer',
    Field.phone: 'Phone', Field.area: 'Area', Field.jars: 'Jars with customer', Field.due: 'Money pending',
    Field.paid: 'Cash paid', Field.amount: 'Amount',
  };
  const gu = {
    Field.product: 'માલ', Field.qty: 'સ્ટોક / સંખ્યા', Field.empty: 'ખાલી જાર', Field.price: 'વેચાણ ભાવ',
    Field.cost: 'ખરીદ ભાવ', Field.min: 'ઓછામાં ઓછો સ્ટોક', Field.unit: 'એકમ', Field.date: 'તારીખ',
    Field.type: 'એન્ટ્રી પ્રકાર', Field.inQty: 'આવક', Field.outQty: 'વેચાણ', Field.customer: 'ગ્રાહક',
    Field.phone: 'ફોન', Field.area: 'વિસ્તાર', Field.jars: 'ગ્રાહક પાસે જાર', Field.due: 'બાકી પૈસા',
    Field.paid: 'ચૂકવેલા પૈસા', Field.amount: 'રકમ',
  };
  const hi = {
    Field.product: 'माल', Field.qty: 'स्टॉक / संख्या', Field.empty: 'खाली जार', Field.price: 'बिक्री भाव',
    Field.cost: 'खरीद भाव', Field.min: 'कम से कम स्टॉक', Field.unit: 'इकाई', Field.date: 'तारीख',
    Field.type: 'एंट्री प्रकार', Field.inQty: 'आवक', Field.outQty: 'बिक्री', Field.customer: 'ग्राहक',
    Field.phone: 'फ़ोन', Field.area: 'इलाका', Field.jars: 'ग्राहक के पास जार', Field.due: 'बाकी पैसे',
    Field.paid: 'दिए पैसे', Field.amount: 'रकम',
  };
  final m = lang == 'gu' ? gu : (lang == 'hi' ? hi : en);
  return m[f] ?? f.name;
}

class ImportedProduct {
  String name;
  String? unit;
  bool returnable;
  double? price;
  double? cost;
  int? qty;
  int? empty;
  int? min;
  ImportedProduct(this.name, {this.returnable = false});
}

class ImportedCustomer {
  String name;
  String phone = '';
  String area = '';
  int? jars;
  double? due;
  ImportedCustomer(this.name);
}

class ImportedEntry {
  DateTime date;
  EntryType type;
  String? product;
  String? customer;
  int qty;
  int emptyBack;
  double amount;
  double paid;
  ImportedEntry(this.date, this.type,
      {this.product, this.customer, this.qty = 0, this.emptyBack = 0, this.amount = 0, this.paid = 0});
}

class ColumnHit {
  final String sheet;
  final String header;
  final Field field;
  ColumnHit(this.sheet, this.header, this.field);
}

class LearnedRule {
  final String product;
  final double avgDaily;
  final int min;
  final bool manual;
  final int autoOpening;
  LearnedRule(this.product, this.avgDaily, this.min, this.manual, this.autoOpening);
}

class ImportPlan {
  final Map<String, ImportedProduct> products = {}; // key = normKey(name)
  final Map<String, ImportedCustomer> customers = {};
  final List<ImportedEntry> entries = [];
  final List<ColumnHit> columns = [];
  final Map<String, int> autoOpening = {}; // opening stock learned so history never goes below 0
  int skipped = 0;
  List<LearnedRule> rules = [];

  bool get isEmpty => products.isEmpty && customers.isEmpty && entries.isEmpty;
}

/// Reads any shop Excel and turns it into products, customers and entries.
class ExcelLearner {
  static ImportPlan learn(List<SheetData> sheets, Settings settings) {
    final plan = ImportPlan();
    for (final s in sheets) {
      _learnSheet(s, plan);
    }
    _fillGaps(plan);
    _learnRules(plan, settings);
    return plan;
  }

  // ------------------------------------------------------------ helpers
  static String _str(Object? v) {
    if (v == null) return '';
    if (v is double && v == v.roundToDouble()) return v.toInt().toString();
    return v.toString().trim();
  }

  static double? _num(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is bool) return null;
    final s = v.toString().replaceAll(RegExp(r'(₹|rs\.?|inr|,|\s)', caseSensitive: false), '');
    if (s.isEmpty) return null;
    final m = RegExp(r'-?\d+(\.\d+)?').firstMatch(s);
    return m == null ? null : double.tryParse(m.group(0)!);
  }

  static int? _int(Object? v) => _num(v)?.round();

  static bool _onlyNumber(String s) => RegExp(r'^[\d\.\s,\-]+$').hasMatch(s);

  static DateTime? parseDate(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is num) {
      if (v > 20000 && v < 80000) {
        return DateTime(1899, 12, 30).add(Duration(days: v.floor()));
      }
      return null;
    }
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final m = RegExp(r'^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})').firstMatch(s);
    if (m != null) {
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      var y = int.parse(m.group(3)!);
      if (y < 100) y += 2000;
      // India uses day/month/year. If month > 12 it must be month/day.
      if (mo > 12 && d <= 12) return DateTime(y, d, mo);
      if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31) return DateTime(y, mo, d);
    }
    for (final f in ['d MMM yyyy', 'd MMMM yyyy', 'd-MMM-yyyy', 'd-MMM-yy', 'MMM d, yyyy', 'd MMM yy']) {
      try {
        return DateFormat(f).parseLoose(s);
      } catch (_) {}
    }
    return null;
  }

  static final _jarWords = RegExp(
      r'(20\s*l|20\s*ltr|20\s*litre|20\s*liter|18\s*l|19\s*l|15\s*l|jar|can\b|camper|bubble|carboy|dispenser|જાર|जार|કેન|कैन)',
      caseSensitive: false);

  static bool looksReturnable(String name, String unit) => _jarWords.hasMatch('$name $unit');

  static String guessUnit(String name, bool returnable) {
    final n = name.toLowerCase();
    if (returnable) return 'Jar';
    if (n.contains('box') || n.contains('case') || n.contains('carton') || n.contains('બોક્સ') || n.contains('बॉक्स')) return 'Box';
    if (n.contains('pouch') || n.contains('packet') || n.contains('pkt')) return 'Packet';
    if (n.contains('bottle') || n.contains('ml') || n.contains('ltr') || RegExp(r'\d\s*l\b').hasMatch(n)) return 'Box';
    return 'Box';
  }

  static EntryType? parseType(String raw) {
    final s = raw.toLowerCase().trim();
    if (s.isEmpty) return null;
    bool any(List<String> ks) => ks.any((k) => s.contains(k));
    if (any(['damage', 'leak', 'broken', 'expire', 'waste', 'wastage', 'nuksan', 'નુકસાન', 'नुकसान', 'तूटा', 'टूटा'])) return EntryType.damage;
    if (any(['return', 'empty', 'khali', 'ખાલી', 'खाली', 'वापस', 'પાછા'])) return EntryType.emptyReturn;
    if (any(['refill', 'fill', 'bhar', 'ભર', 'भर'])) return EntryType.fill;
    if (any(['payment', 'paid', 'cash rec', 'money', 'chukv', 'ચૂકવ', 'भुगतान'])) return EntryType.payment;
    if (any(['adjust', 'correction', 'count'])) return EntryType.adjust;
    if (s == 'out' || any(['sale', 'sold', 'deliver', 'issue', 'dispatch', 'vechan', 'becha', 'outward', 'વેચાણ', 'જાવક', 'बिक्री', 'जावक'])) {
      return EntryType.sale;
    }
    if (s == 'in' || any(['purchase', 'receiv', 'production', 'produced', 'buy', 'stock in', 'inward', 'aavak', 'આવક', 'आवक', 'खरीद', 'ખરીદ'])) {
      return EntryType.stockIn;
    }
    return null;
  }

  static ImportedProduct _product(ImportPlan plan, String name) {
    final key = normKey(name);
    return plan.products.putIfAbsent(key, () => ImportedProduct(name, returnable: looksReturnable(name, '')));
  }

  static ImportedCustomer _customer(ImportPlan plan, String name) =>
      plan.customers.putIfAbsent(normKey(name), () => ImportedCustomer(name));

  static bool _isTotalRow(String s) {
    final l = s.toLowerCase();
    return l == 'total' || l == 'grand total' || l.startsWith('total ') || l == 'કુલ' || l == 'कुल' || l == 'sub total';
  }

  // ------------------------------------------------------------ sheets
  static void _learnSheet(SheetData sheet, ImportPlan plan) {
    final rows = sheet.rows;
    if (rows.isEmpty) return;

    // 1. find the header row (the row in the first 15 with most known words)
    var headerIdx = -1;
    var best = 1;
    for (var r = 0; r < rows.length && r < 15; r++) {
      var hits = 0;
      for (final c in rows[r]) {
        if (c is String && c.length < 60 && fieldForHeader(c) != null) hits++;
      }
      if (hits > best) {
        best = hits;
        headerIdx = r;
      }
    }
    if (headerIdx < 0) {
      // No headers? Maybe a plain list: first column names, second column numbers.
      _learnPlainList(sheet, plan);
      return;
    }

    final header = rows[headerIdx];
    final cols = <Field, List<int>>{};
    final headerText = <int, String>{};
    for (var c = 0; c < header.length; c++) {
      final h = _str(header[c]);
      final f = fieldForHeader(h);
      if (f == null) continue;
      cols.putIfAbsent(f, () => []).add(c);
      headerText[c] = h;
      plan.columns.add(ColumnHit(sheet.name, h, f));
    }
    int? col(Field f) => cols[f]?.first;
    bool has(Field f) => cols.containsKey(f);

    final dataRows = rows.skip(headerIdx + 1).toList();
    final isTxn = has(Field.date) && (has(Field.type) || has(Field.inQty) || has(Field.outQty) || (has(Field.customer) && has(Field.qty)));

    if (isTxn) {
      _learnTransactions(dataRows, cols, headerText, plan);
    } else if (has(Field.product)) {
      _learnProducts(dataRows, cols, headerText, plan);
    } else if (has(Field.customer)) {
      _learnCustomers(dataRows, col, plan);
    } else {
      plan.skipped += dataRows.length;
    }
  }

  static Object? _cell(List<Object?> row, int? c) => (c != null && c >= 0 && c < row.length) ? row[c] : null;

  static void _learnProducts(List<List<Object?>> rows, Map<Field, List<int>> cols, Map<int, String> headerText, ImportPlan plan) {
    int? col(Field f) => cols[f]?.first;
    // pick the right quantity column: "closing / balance / current" beats "opening"
    int? closingCol;
    int? openingCol;
    for (final c in cols[Field.qty] ?? <int>[]) {
      final h = (headerText[c] ?? '').toLowerCase();
      if (RegExp(r'(closing|balance|current|available|now|in hand|present|હાલ|बाकी|अभी)').hasMatch(h)) {
        closingCol ??= c;
      } else if (RegExp(r'(opening|start|શરૂ|शुरू)').hasMatch(h)) {
        openingCol ??= c;
      } else {
        closingCol ??= c;
      }
    }

    for (final row in rows) {
      final name = _str(_cell(row, col(Field.product)));
      if (name.isEmpty || _isTotalRow(name) || _onlyNumber(name)) {
        if (row.any((e) => e != null)) plan.skipped++;
        continue;
      }
      final unit = _str(_cell(row, col(Field.unit)));
      final p = _product(plan, name);
      if (unit.isNotEmpty) p.unit = unit;
      p.returnable = p.returnable || looksReturnable(name, unit);

      int? qty;
      if (closingCol != null) {
        qty = _int(_cell(row, closingCol));
      } else if (openingCol != null || cols.containsKey(Field.inQty) || cols.containsKey(Field.outQty)) {
        final o = _int(_cell(row, openingCol)) ?? 0;
        final i = _int(_cell(row, col(Field.inQty))) ?? 0;
        final s = _int(_cell(row, col(Field.outQty))) ?? 0;
        qty = o + i - s;
      }
      if (qty != null) p.qty = (p.qty ?? 0) + qty;
      final e = _int(_cell(row, col(Field.empty)));
      if (e != null) p.empty = (p.empty ?? 0) + e;
      p.price = _num(_cell(row, col(Field.price))) ?? p.price;
      p.cost = _num(_cell(row, col(Field.cost))) ?? p.cost;
      final mn = _int(_cell(row, col(Field.min)));
      if (mn != null && mn > 0) p.min = mn;
    }
  }

  static void _learnCustomers(List<List<Object?>> rows, int? Function(Field) col, ImportPlan plan) {
    for (final row in rows) {
      final name = _str(_cell(row, col(Field.customer)));
      if (name.isEmpty || _isTotalRow(name)) {
        if (row.any((e) => e != null)) plan.skipped++;
        continue;
      }
      final c = _customer(plan, name);
      final ph = _str(_cell(row, col(Field.phone)));
      if (ph.isNotEmpty) c.phone = ph;
      final ar = _str(_cell(row, col(Field.area)));
      if (ar.isNotEmpty) c.area = ar;
      c.jars = _int(_cell(row, col(Field.jars))) ?? _int(_cell(row, col(Field.empty))) ?? _int(_cell(row, col(Field.qty))) ?? c.jars;
      c.due = _num(_cell(row, col(Field.due))) ?? _num(_cell(row, col(Field.amount))) ?? c.due;
    }
  }

  static void _learnTransactions(List<List<Object?>> rows, Map<Field, List<int>> cols, Map<int, String> headerText, ImportPlan plan) {
    int? col(Field f) => cols[f]?.first;
    DateTime? lastDate;
    String? lastProduct;
    for (final row in rows) {
      if (!row.any((e) => e != null && _str(e).isNotEmpty)) continue;
      final date = parseDate(_cell(row, col(Field.date))) ?? lastDate;
      if (date == null) {
        plan.skipped++;
        continue;
      }
      lastDate = date;
      var prodName = _str(_cell(row, col(Field.product)));
      if (prodName.isEmpty && cols.containsKey(Field.product)) prodName = lastProduct ?? '';
      if (_isTotalRow(prodName)) continue;
      final custName = _str(_cell(row, col(Field.customer)));
      final typeRaw = _str(_cell(row, col(Field.type)));
      var type = parseType(typeRaw);
      final qty = _int(_cell(row, col(Field.qty))) ?? 0;
      final inQ = _int(_cell(row, col(Field.inQty))) ?? 0;
      final outQ = _int(_cell(row, col(Field.outQty))) ?? 0;
      final emptyQ = _int(_cell(row, col(Field.empty))) ?? 0;
      final amount = _num(_cell(row, col(Field.amount))) ?? 0;
      final paid = _num(_cell(row, col(Field.paid))) ?? 0;

      // if no product column but only one product exists, use it
      if (prodName.isEmpty && plan.products.length == 1) prodName = plan.products.values.first.name;
      if (prodName.isEmpty && type != EntryType.payment && !(paid > 0 && qty == 0 && inQ == 0 && outQ == 0)) {
        plan.skipped++;
        continue;
      }
      if (prodName.isNotEmpty) {
        _product(plan, prodName);
        lastProduct = prodName;
      }
      final cust = custName.isEmpty ? null : custName;
      // only real customers (sale / empty back / money) become customers,
      // not suppliers on "stock in" rows
      String? custFor(EntryType ty) {
        if (cust == null) return null;
        if (ty == EntryType.sale || ty == EntryType.emptyReturn || ty == EntryType.payment) {
          _customer(plan, cust);
          return cust;
        }
        return null;
      }
      final prod = prodName.isEmpty ? null : prodName;

      var made = false;
      if (inQ > 0) {
        plan.entries.add(ImportedEntry(date, EntryType.stockIn, product: prod, qty: inQ));
        made = true;
      }
      if (outQ > 0) {
        plan.entries.add(ImportedEntry(date, EntryType.sale,
            product: prod, customer: custFor(EntryType.sale), qty: outQ, emptyBack: emptyQ, amount: amount, paid: paid));
        made = true;
      }
      if (!made) {
        type ??= (cust != null && qty > 0) ? EntryType.sale : null;
        if (type == null && emptyQ > 0 && qty == 0) type = EntryType.emptyReturn;
        if (type == null && paid > 0 && qty == 0) type = EntryType.payment;
        if (type == null) {
          plan.skipped++;
          continue;
        }
        switch (type) {
          case EntryType.payment:
            if (cust == null) {
              plan.skipped++;
              continue;
            }
            plan.entries.add(ImportedEntry(date, type, customer: custFor(type), paid: paid > 0 ? paid : amount));
            break;
          case EntryType.emptyReturn:
            plan.entries.add(ImportedEntry(date, type, product: prod, customer: custFor(type), qty: qty > 0 ? qty : emptyQ));
            break;
          case EntryType.sale:
            plan.entries.add(ImportedEntry(date, type,
                product: prod, customer: custFor(type), qty: qty, emptyBack: emptyQ, amount: amount, paid: paid));
            break;
          default:
            if (qty == 0) {
              plan.skipped++;
              continue;
            }
            plan.entries.add(ImportedEntry(date, type,
                product: prod, qty: type == EntryType.adjust ? qty : qty.abs(), amount: amount));
        }
      } else if (inQ == 0 && outQ == 0 && emptyQ > 0) {
        plan.entries.add(ImportedEntry(date, EntryType.emptyReturn, product: prod, customer: custFor(EntryType.emptyReturn), qty: emptyQ));
      }
    }
  }

  static void _learnPlainList(SheetData sheet, ImportPlan plan) {
    for (final row in sheet.rows) {
      if (row.length < 2) continue;
      final name = _str(row[0]);
      final q = _int(row[1]);
      if (name.isEmpty || q == null || _onlyNumber(name) || _isTotalRow(name)) {
        if (row.any((e) => e != null)) plan.skipped++;
        continue;
      }
      final p = _product(plan, name);
      p.qty = (p.qty ?? 0) + q;
      if (row.length > 2) p.price = _num(row[2]) ?? p.price;
    }
  }

  // ------------------------------------------------------------ learning
  static void _fillGaps(ImportPlan plan) {
    // Price from history if the Excel had no price column
    for (final p in plan.products.values) {
      p.unit ??= guessUnit(p.name, p.returnable);
      if (p.price == null || p.price == 0) {
        final rates = plan.entries
            .where((e) => e.type == EntryType.sale && e.product != null && normKey(e.product!) == normKey(p.name) && e.qty > 0 && e.amount > 0)
            .map((e) => e.amount / e.qty)
            .toList()
          ..sort();
        if (rates.isNotEmpty) p.price = rates[rates.length ~/ 2];
      }
    }
    // Bill amount from price if the Excel had no amount
    for (final e in plan.entries) {
      if (e.type == EntryType.sale && e.amount == 0 && e.product != null) {
        final p = plan.products[normKey(e.product!)];
        if (p?.price != null) e.amount = p!.price! * e.qty;
        if (e.paid == 0 && e.customer == null) e.paid = e.amount; // walk-in pays cash
      }
    }
    // If only history (no stock sheet), find the smallest opening stock that
    // never lets the stock go below zero.
    plan.entries.sort((a, b) => a.date.compareTo(b.date));
    for (final p in plan.products.values) {
      if (p.qty != null) continue;
      var bal = 0, lowest = 0;
      for (final e in plan.entries) {
        if (e.product == null || normKey(e.product!) != normKey(p.name)) continue;
        switch (e.type) {
          case EntryType.stockIn:
          case EntryType.fill:
            bal += e.qty;
            break;
          case EntryType.sale:
          case EntryType.damage:
            bal -= e.qty;
            break;
          case EntryType.adjust:
            bal += e.qty;
            break;
          default:
            break;
        }
        if (bal < lowest) lowest = bal;
      }
      if (lowest < 0) plan.autoOpening[normKey(p.name)] = -lowest;
    }
  }

  static void _learnRules(ImportPlan plan, Settings s) {
    final rules = <LearnedRule>[];
    for (final ip in plan.products.values) {
      final tmp = Product(id: 'tmp', name: ip.name, minStockManual: ip.min);
      final tmpEntries = plan.entries
          .where((e) => e.product != null && normKey(e.product!) == normKey(ip.name))
          .map((e) => Entry(id: 'x', date: e.date, type: e.type, productId: 'tmp', qty: e.qty))
          .toList();
      final r = StockRules.minStockFor(tmp, tmpEntries, s);
      rules.add(LearnedRule(ip.name, r.avgDaily, r.min, ip.min != null, plan.autoOpening[normKey(ip.name)] ?? 0));
    }
    plan.rules = rules;
  }

  // ------------------------------------------------------------ apply
  static Future<void> apply(AppStore st, ImportPlan plan, {required bool replace}) async {
    if (replace) {
      st.products.clear();
      st.customers.clear();
      st.entries.clear();
    }
    final now = DateTime.now();
    final pid = <String, String>{};
    var color = st.products.length;
    for (final ip in plan.products.values) {
      final existing = st.productByName(ip.name);
      final opening = ip.qty ?? plan.autoOpening[normKey(ip.name)] ?? 0;
      if (existing == null) {
        final p = Product(
          id: newId(),
          name: ip.name,
          unit: ip.unit ?? 'Box',
          returnable: ip.returnable,
          price: ip.price ?? 0,
          cost: ip.cost ?? 0,
          openingFull: ip.qty == null ? opening : 0,
          openingEmpty: ip.empty == null ? 0 : ip.empty! - _emptyNet(plan, ip.name),
          minStockManual: ip.min,
          colorIndex: color++ % 8,
        );
        st.products.add(p);
        pid[normKey(ip.name)] = p.id;
        // A stock sheet says "stock NOW": make the history end at that number
        if (ip.qty != null) {
          p.openingFull = ip.qty! - _netChange(plan, ip.name);
        }
      } else {
        pid[normKey(ip.name)] = existing.id;
        if (ip.price != null && ip.price! > 0) existing.price = ip.price!;
        if (ip.cost != null && ip.cost! > 0) existing.cost = ip.cost!;
        if (ip.min != null) existing.minStockManual = ip.min;
        if (ip.unit != null) existing.unit = ip.unit!;
        existing.returnable = existing.returnable || ip.returnable;
        if (ip.qty != null) {
          // correct current stock to Excel's number with one "count fix" entry
          final current = st.stockOf(existing).full + _netChange(plan, ip.name);
          final delta = ip.qty! - current;
          if (delta != 0) {
            st.entries.add(Entry(id: newId(), date: now, type: EntryType.adjust, productId: existing.id, qty: delta, note: 'Excel'));
          }
        }
        if (ip.empty != null) existing.openingEmpty += ip.empty! - st.stockOf(existing).empty;
      }
    }
    final cid = <String, String>{};
    for (final ic in plan.customers.values) {
      var c = st.customerByName(ic.name);
      if (c == null) {
        // A customer sheet says jars/money "NOW": make the history end at that number
        final net = _customerNet(plan, ic.name);
        c = Customer(
          id: newId(),
          name: ic.name,
          phone: ic.phone,
          area: ic.area,
          openingJars: ic.jars == null ? 0 : ic.jars! - net.jars,
          openingDue: ic.due == null ? 0 : ic.due! - net.due,
        );
        st.customers.add(c);
      } else {
        if (ic.phone.isNotEmpty) c.phone = ic.phone;
        if (ic.area.isNotEmpty) c.area = ic.area;
      }
      cid[normKey(ic.name)] = c.id;
    }
    for (final ie in plan.entries) {
      st.entries.add(Entry(
        id: newId(),
        date: ie.date,
        type: ie.type,
        productId: ie.product == null ? null : pid[normKey(ie.product!)],
        customerId: ie.customer == null ? null : cid[normKey(ie.customer!)],
        qty: ie.qty,
        emptyBack: ie.emptyBack,
        amount: ie.amount,
        paid: ie.paid,
        note: 'Excel',
      ));
    }
    await st.changed();
  }

  /// Net change of empty jars in godown from imported history.
  static int _emptyNet(ImportPlan plan, String name) {
    var n = 0;
    for (final e in plan.entries) {
      if (e.product == null || normKey(e.product!) != normKey(name)) continue;
      if (e.type == EntryType.sale) n += e.emptyBack;
      if (e.type == EntryType.emptyReturn) n += e.qty;
      if (e.type == EntryType.fill) n -= e.qty;
    }
    return n;
  }

  /// Jars and money a customer gained from imported history.
  static ({int jars, double due}) _customerNet(ImportPlan plan, String name) {
    var jars = 0;
    double due = 0;
    for (final e in plan.entries) {
      if (e.customer == null || normKey(e.customer!) != normKey(name)) continue;
      final returnable = e.product != null && (plan.products[normKey(e.product!)]?.returnable ?? false);
      switch (e.type) {
        case EntryType.sale:
          if (returnable) jars += e.qty - e.emptyBack;
          due += e.amount - e.paid;
          break;
        case EntryType.emptyReturn:
          jars -= e.qty;
          break;
        case EntryType.payment:
          due -= e.paid;
          break;
        default:
          break;
      }
    }
    return (jars: jars, due: due);
  }

  /// Net change of full stock from imported history for one product.
  static int _netChange(ImportPlan plan, String name) {
    var n = 0;
    for (final e in plan.entries) {
      if (e.product == null || normKey(e.product!) != normKey(name)) continue;
      switch (e.type) {
        case EntryType.stockIn:
        case EntryType.fill:
        case EntryType.adjust:
          n += e.qty;
          break;
        case EntryType.sale:
        case EntryType.damage:
          n -= e.qty;
          break;
        default:
          break;
      }
    }
    return n;
  }
}
