import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'rules.dart';

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 20).toRadixString(36)}';

/// Single source of truth. Saves everything to one JSON file on the phone.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore instance = AppStore._();

  Settings settings = Settings();
  final List<Product> products = [];
  final List<Customer> customers = [];
  final List<Entry> entries = [];

  // caches, rebuilt by _recompute()
  final Map<String, StockInfo> _stock = {};
  final Map<String, CustomerInfo> _cust = {};
  List<Alert> alerts = [];

  File? _file;
  bool loaded = false;

  // ---------------------------------------------------------------- load/save
  Future<void> load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/jalstock_data.json');
      if (await _file!.exists()) {
        final j = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        settings = Settings.fromJson((j['settings'] ?? {}) as Map<String, dynamic>);
        products
          ..clear()
          ..addAll(((j['products'] ?? []) as List).map((e) => Product.fromJson(e as Map<String, dynamic>)));
        customers
          ..clear()
          ..addAll(((j['customers'] ?? []) as List).map((e) => Customer.fromJson(e as Map<String, dynamic>)));
        entries
          ..clear()
          ..addAll(((j['entries'] ?? []) as List).map((e) => Entry.fromJson(e as Map<String, dynamic>)));
      }
    } catch (e) {
      debugPrint('Load failed: $e');
    }
    loaded = true;
    _recompute();
    notifyListeners();
  }

  Future<void> _saveChain = Future.value();

  /// Saves run one after another (never two at once), and never crash the app.
  Future<void> _save() {
    _saveChain = _saveChain.then((_) => _writeNow()).catchError((Object e) {
      debugPrint('Save failed: $e');
    });
    return _saveChain;
  }

  Future<void> _writeNow() async {
    if (_file == null) return;
    final data = jsonEncode({
      'version': 1,
      'settings': settings.toJson(),
      'products': products.map((e) => e.toJson()).toList(),
      'customers': customers.map((e) => e.toJson()).toList(),
      'entries': entries.map((e) => e.toJson()).toList(),
    });
    // write to temp then rename, so a crash never corrupts data
    final tmp = File('${_file!.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    await tmp.rename(_file!.path);
  }

  Future<void> changed() async {
    _recompute();
    notifyListeners();
    await _save();
  }

  // ---------------------------------------------------------------- lookups
  Product? productById(String? id) {
    if (id == null) return null;
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Customer? customerById(String? id) {
    if (id == null) return null;
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  StockInfo stockOf(Product p) =>
      _stock[p.id] ??
      const StockInfo(full: 0, empty: 0, withCustomers: 0, minStock: 0, avgDailySale: 0, minIsLearned: false);

  CustomerInfo customerInfo(Customer c) => _cust[c.id] ?? const CustomerInfo(jarsHeld: 0, due: 0);

  List<Entry> entriesSorted() => [...entries]..sort((a, b) => b.date.compareTo(a.date));

  // ---------------------------------------------------------------- math
  void _recompute() {
    final full = <String, int>{};
    final empty = <String, int>{};
    final withCust = <String, int>{};
    for (final p in products) {
      full[p.id] = p.openingFull;
      empty[p.id] = p.openingEmpty;
      withCust[p.id] = 0;
    }
    final jars = <String, int>{};
    final due = <String, double>{};
    final last = <String, DateTime>{};
    for (final c in customers) {
      jars[c.id] = c.openingJars;
      due[c.id] = c.openingDue;
    }

    final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
    for (final e in sorted) {
      final pid = e.productId;
      final cid = e.customerId;
      final p = productById(pid);
      final returnable = p?.returnable ?? false;
      switch (e.type) {
        case EntryType.stockIn:
          if (pid != null) full[pid] = (full[pid] ?? 0) + e.qty;
          break;
        case EntryType.sale:
          if (pid != null) {
            full[pid] = (full[pid] ?? 0) - e.qty;
            if (returnable) {
              empty[pid] = (empty[pid] ?? 0) + e.emptyBack;
              withCust[pid] = (withCust[pid] ?? 0) + e.qty - e.emptyBack;
            }
          }
          if (cid != null) {
            if (returnable) jars[cid] = (jars[cid] ?? 0) + e.qty - e.emptyBack;
            due[cid] = (due[cid] ?? 0) + e.amount - e.paid;
          }
          break;
        case EntryType.emptyReturn:
          if (pid != null) {
            empty[pid] = (empty[pid] ?? 0) + e.qty;
            withCust[pid] = (withCust[pid] ?? 0) - e.qty;
          }
          if (cid != null) jars[cid] = (jars[cid] ?? 0) - e.qty;
          break;
        case EntryType.fill:
          if (pid != null) {
            empty[pid] = (empty[pid] ?? 0) - e.qty;
            full[pid] = (full[pid] ?? 0) + e.qty;
          }
          break;
        case EntryType.damage:
          if (pid != null) full[pid] = (full[pid] ?? 0) - e.qty;
          break;
        case EntryType.adjust:
          if (pid != null) full[pid] = (full[pid] ?? 0) + e.qty;
          break;
        case EntryType.payment:
          if (cid != null) due[cid] = (due[cid] ?? 0) - e.paid;
          break;
      }
      if (cid != null && (e.type == EntryType.emptyReturn || e.type == EntryType.payment || e.type == EntryType.sale)) {
        last[cid] = e.date;
      }
    }

    // jars held by customers before the app started count as "with customers"
    final openingWithCustomers = customers.fold<int>(0, (s, c) => s + c.openingJars);
    final returnables = products.where((p) => p.returnable).toList();

    _stock.clear();
    for (final p in products) {
      final rule = StockRules.minStockFor(p, entries, settings);
      var wc = withCust[p.id] ?? 0;
      if (returnables.length == 1 && p.returnable) wc += openingWithCustomers;
      _stock[p.id] = StockInfo(
        full: full[p.id] ?? 0,
        empty: empty[p.id] ?? 0,
        withCustomers: wc,
        minStock: rule.min,
        avgDailySale: rule.avgDaily,
        minIsLearned: rule.learned,
      );
    }
    _cust.clear();
    for (final c in customers) {
      _cust[c.id] = CustomerInfo(jarsHeld: jars[c.id] ?? 0, due: due[c.id] ?? 0, lastActivity: last[c.id]);
    }
    alerts = StockRules.buildAlerts(this);
  }

  // ---------------------------------------------------------------- actions
  Future<void> addEntry(Entry e) async {
    entries.add(e);
    await changed();
  }

  Future<void> deleteEntry(Entry e) async {
    entries.removeWhere((x) => x.id == e.id);
    await changed();
  }

  Future<void> upsertProduct(Product p) async {
    final i = products.indexWhere((x) => x.id == p.id);
    if (i >= 0) {
      products[i] = p;
    } else {
      products.add(p);
    }
    await changed();
  }

  Future<void> deleteProduct(Product p) async {
    products.removeWhere((x) => x.id == p.id);
    entries.removeWhere((e) => e.productId == p.id);
    await changed();
  }

  Future<void> upsertCustomer(Customer c) async {
    final i = customers.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      customers[i] = c;
    } else {
      customers.add(c);
    }
    await changed();
  }

  Future<void> deleteCustomer(Customer c) async {
    customers.removeWhere((x) => x.id == c.id);
    for (final e in entries) {
      if (e.customerId == c.id) e.customerId = null;
    }
    await changed();
  }

  Future<void> setLang(String lang) async {
    settings.lang = lang;
    await changed();
  }

  Future<void> resetAll() async {
    products.clear();
    customers.clear();
    entries.clear();
    await changed();
  }

  /// Adds the ₹10 / ₹20 counter bottles if the shop does not have them yet.
  Future<int> addSmallBottles() async {
    var added = 0;
    for (final p in [
      Product(id: newId(), name: '₹10 Bottle (500 ml)', unit: 'Bottle', price: 10, cost: 6.5, packSize: 24, colorIndex: 4),
      Product(id: newId(), name: '₹20 Bottle (1 Litre)', unit: 'Bottle', price: 20, cost: 13, packSize: 12, colorIndex: 5),
    ]) {
      if (productByName(p.name) == null && !products.any((x) => x.unit == 'Bottle' && x.price == p.price)) {
        products.add(p);
        added++;
      }
    }
    if (added > 0) await changed();
    return added;
  }

  Future<void> loadStarterProducts() async {
    if (products.isNotEmpty) return;
    products.addAll([
      Product(id: newId(), name: '20 Litre Jar', unit: 'Jar', returnable: true, price: 40, cost: 15, colorIndex: 0),
      Product(id: newId(), name: '₹10 Bottle (500 ml)', unit: 'Bottle', price: 10, cost: 6.5, packSize: 24, colorIndex: 4),
      Product(id: newId(), name: '₹20 Bottle (1 Litre)', unit: 'Bottle', price: 20, cost: 13, packSize: 12, colorIndex: 5),
      Product(id: newId(), name: '1 Litre Bottle (Box of 12)', unit: 'Box', price: 120, cost: 85, colorIndex: 1),
      Product(id: newId(), name: '500 ml Bottle (Box of 24)', unit: 'Box', price: 140, cost: 100, colorIndex: 2),
      Product(id: newId(), name: '250 ml Bottle (Box of 48)', unit: 'Box', price: 180, cost: 130, colorIndex: 3),
    ]);
    await changed();
  }

  /// Find product by name ignoring case/spaces (used by Excel import).
  Product? productByName(String name) {
    final k = normKey(name);
    for (final p in products) {
      if (normKey(p.name) == k) return p;
    }
    return null;
  }

  Customer? customerByName(String name) {
    final k = normKey(name);
    for (final c in customers) {
      if (normKey(c.name) == k) return c;
    }
    return null;
  }
}

String normKey(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9ऀ-૿]'), '');
