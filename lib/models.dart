// Data models for JalStock.
//
// Stock is never stored directly. Every product keeps its OPENING stock and
// every movement is a [Entry]. Current stock = opening + all entries.
// This makes "delete entry" (undo) always safe and the numbers always right.

enum EntryType {
  stockIn, // new stock bought / produced  -> full +
  sale, // delivered / sold to customer  -> full -, jars go to customer
  emptyReturn, // customer gives empty jars back -> empty +
  fill, // empty jars filled at plant  -> empty -, full +
  damage, // broken / leaking / expired  -> full -
  adjust, // stock count correction (signed qty) -> full +/-
  payment, // money received from customer (no stock change)
}

EntryType entryTypeFromName(String s) =>
    EntryType.values.firstWhere((e) => e.name == s, orElse: () => EntryType.adjust);

class Product {
  String id;
  String name;
  String unit; // Jar, Box, Bottle, Packet
  bool returnable; // 20L jars etc. that come back empty
  double price; // selling price per unit
  double cost; // purchase cost per unit
  int openingFull;
  int openingEmpty;
  int? minStockManual; // if user/Excel set it, rules use this
  int colorIndex;

  Product({
    required this.id,
    required this.name,
    this.unit = 'Box',
    this.returnable = false,
    this.price = 0,
    this.cost = 0,
    this.openingFull = 0,
    this.openingEmpty = 0,
    this.minStockManual,
    this.colorIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'returnable': returnable,
        'price': price,
        'cost': cost,
        'openingFull': openingFull,
        'openingEmpty': openingEmpty,
        'minStockManual': minStockManual,
        'colorIndex': colorIndex,
      };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String,
        name: j['name'] as String,
        unit: (j['unit'] ?? 'Box') as String,
        returnable: (j['returnable'] ?? false) as bool,
        price: ((j['price'] ?? 0) as num).toDouble(),
        cost: ((j['cost'] ?? 0) as num).toDouble(),
        openingFull: ((j['openingFull'] ?? 0) as num).toInt(),
        openingEmpty: ((j['openingEmpty'] ?? 0) as num).toInt(),
        minStockManual: (j['minStockManual'] as num?)?.toInt(),
        colorIndex: ((j['colorIndex'] ?? 0) as num).toInt(),
      );
}

class Customer {
  String id;
  String name;
  String phone;
  String area;
  int openingJars; // jars already with customer before using app
  double openingDue; // money already pending

  Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.area = '',
    this.openingJars = 0,
    this.openingDue = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'area': area,
        'openingJars': openingJars,
        'openingDue': openingDue,
      };

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: (j['phone'] ?? '') as String,
        area: (j['area'] ?? '') as String,
        openingJars: ((j['openingJars'] ?? 0) as num).toInt(),
        openingDue: ((j['openingDue'] ?? 0) as num).toDouble(),
      );
}

class Entry {
  String id;
  DateTime date;
  EntryType type;
  String? productId;
  String? customerId;
  int qty; // signed only for adjust
  int emptyBack; // empties collected during a sale
  double amount; // bill value (sale) or cost (stock in)
  double paid; // cash received now
  String note;

  Entry({
    required this.id,
    required this.date,
    required this.type,
    this.productId,
    this.customerId,
    this.qty = 0,
    this.emptyBack = 0,
    this.amount = 0,
    this.paid = 0,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'type': type.name,
        'productId': productId,
        'customerId': customerId,
        'qty': qty,
        'emptyBack': emptyBack,
        'amount': amount,
        'paid': paid,
        'note': note,
      };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        type: entryTypeFromName(j['type'] as String),
        productId: j['productId'] as String?,
        customerId: j['customerId'] as String?,
        qty: ((j['qty'] ?? 0) as num).toInt(),
        emptyBack: ((j['emptyBack'] ?? 0) as num).toInt(),
        amount: ((j['amount'] ?? 0) as num).toDouble(),
        paid: ((j['paid'] ?? 0) as num).toDouble(),
        note: (j['note'] ?? '') as String,
      );
}

class Settings {
  String lang; // en, gu, hi
  String businessName;
  int leadDays; // days needed to get new stock
  int safetyPercent; // extra buffer
  bool autoMinStock; // learn minimum stock from sales
  int jarReminderDays; // remind if customer keeps jars this long
  bool onboarded;

  Settings({
    this.lang = 'en',
    this.businessName = '',
    this.leadDays = 2,
    this.safetyPercent = 20,
    this.autoMinStock = true,
    this.jarReminderDays = 10,
    this.onboarded = false,
  });

  Map<String, dynamic> toJson() => {
        'lang': lang,
        'businessName': businessName,
        'leadDays': leadDays,
        'safetyPercent': safetyPercent,
        'autoMinStock': autoMinStock,
        'jarReminderDays': jarReminderDays,
        'onboarded': onboarded,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        lang: (j['lang'] ?? 'en') as String,
        businessName: (j['businessName'] ?? '') as String,
        leadDays: ((j['leadDays'] ?? 2) as num).toInt(),
        safetyPercent: ((j['safetyPercent'] ?? 20) as num).toInt(),
        autoMinStock: (j['autoMinStock'] ?? true) as bool,
        jarReminderDays: ((j['jarReminderDays'] ?? 10) as num).toInt(),
        onboarded: (j['onboarded'] ?? false) as bool,
      );
}

/// Calculated live numbers for one product.
class StockInfo {
  final int full;
  final int empty;
  final int withCustomers;
  final int minStock;
  final double avgDailySale;
  final bool minIsLearned;
  const StockInfo({
    required this.full,
    required this.empty,
    required this.withCustomers,
    required this.minStock,
    required this.avgDailySale,
    required this.minIsLearned,
  });

  StockLevel get level {
    if (full <= 0) return StockLevel.out;
    if (minStock > 0 && full <= minStock) return StockLevel.low;
    if (minStock > 0 && full <= (minStock * 1.5).ceil()) return StockLevel.near;
    return StockLevel.ok;
  }

  /// How many to order now so stock comes back to 2x minimum.
  int get suggestedOrder {
    if (minStock <= 0) return 0;
    final need = minStock * 2 - full;
    return need > 0 ? need : 0;
  }

  /// Approx days of stock left.
  double? get daysLeft => avgDailySale > 0 ? full / avgDailySale : null;
}

enum StockLevel { ok, near, low, out }

class CustomerInfo {
  final int jarsHeld;
  final double due;
  final DateTime? lastActivity;
  const CustomerInfo({required this.jarsHeld, required this.due, this.lastActivity});
}
