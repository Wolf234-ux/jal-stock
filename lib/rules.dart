import 'models.dart';
import 'store.dart';

/// Result of the minimum-stock rule for one product.
class MinRule {
  final int min;
  final double avgDaily;
  final bool learned;
  const MinRule(this.min, this.avgDaily, this.learned);
}

enum AlertKind { outOfStock, lowStock, fillEmpties, collectJars, pendingMoney }

class Alert {
  final AlertKind kind;
  final String? productId;
  final String? customerId;
  final int n;
  final double amount;
  const Alert(this.kind, {this.productId, this.customerId, this.n = 0, this.amount = 0});

  int get severity => switch (kind) {
        AlertKind.outOfStock => 3,
        AlertKind.lowStock => 2,
        AlertKind.collectJars => 1,
        AlertKind.fillEmpties => 1,
        AlertKind.pendingMoney => 0,
      };
}

/// All the stock-management rules of the water business live here.
///
/// 1. Minimum stock (reorder level)
///    - If the owner (or the Excel) gave a minimum, use it.
///    - Otherwise learn it: average daily sale x days needed to get stock
///      (lead days) + safety buffer %.
/// 2. Never sell or write off more than what is in stock.
/// 3. Never fill more jars than the empties available.
/// 4. Returnable jars are tracked: full in godown, empty in godown, with
///    customers. Customers holding jars too long get a reminder.
/// 5. Suggested order = bring stock back to 2 x minimum.
class StockRules {
  static const int windowDays = 30;
  static const int minSpanDays = 7;

  static MinRule minStockFor(Product p, List<Entry> entries, Settings s) {
    final sales = entries.where((e) => e.productId == p.id && e.type == EntryType.sale).toList();
    double avg = 0;
    if (sales.isNotEmpty) {
      final now = DateTime.now();
      var latest = sales.first.date;
      for (final e in sales) {
        if (e.date.isAfter(latest)) latest = e.date;
      }
      // if history is old (e.g. imported last year's Excel) learn from the
      // last 30 days of that history instead of an empty window
      final ref = now.difference(latest).inDays <= windowDays ? now : latest;
      final from = ref.subtract(const Duration(days: windowDays));
      final inWindow = sales.where((e) => !e.date.isBefore(from) && !e.date.isAfter(ref)).toList();
      if (inWindow.isNotEmpty) {
        var first = inWindow.first.date;
        for (final e in inWindow) {
          if (e.date.isBefore(first)) first = e.date;
        }
        var span = ref.difference(first).inDays + 1;
        if (span < minSpanDays) span = minSpanDays;
        if (span > windowDays) span = windowDays;
        final total = inWindow.fold<int>(0, (t, e) => t + e.qty);
        avg = total / span;
      }
    }
    if (p.minStockManual != null && p.minStockManual! > 0) {
      return MinRule(p.minStockManual!, avg, false);
    }
    if (!s.autoMinStock || avg <= 0) return MinRule(0, avg, false);
    final min = (avg * s.leadDays * (1 + s.safetyPercent / 100)).ceil();
    return MinRule(min < 1 ? 1 : min, avg, true);
  }

  /// Returns an error key (see l10n) if the entry breaks a hard rule.
  static String? hardError(AppStore st, Entry e) {
    final p = st.productById(e.productId);
    if (e.type == EntryType.payment) {
      if (e.customerId == null) return 'errPickCustomer';
      if (e.paid <= 0) return 'errAmount';
      return null;
    }
    if (p == null) return 'errPickProduct';
    if (e.type != EntryType.adjust && e.qty <= 0) return 'errQty';
    final info = st.stockOf(p);
    switch (e.type) {
      case EntryType.sale:
        if (e.qty > info.full) return 'errNotEnoughStock';
        if (e.emptyBack < 0) return 'errQty';
        break;
      case EntryType.damage:
        if (e.qty > info.full) return 'errNotEnoughStock';
        break;
      case EntryType.fill:
        if (e.qty > info.empty) return 'errNotEnoughEmpty';
        break;
      case EntryType.emptyReturn:
        if (!p.returnable) return 'errNotReturnable';
        break;
      default:
        break;
    }
    return null;
  }

  /// Soft warnings: user may still save after confirming.
  static String? softWarning(AppStore st, Entry e) {
    final c = st.customerById(e.customerId);
    final p = st.productById(e.productId);
    if (c == null || p == null || !p.returnable) return null;
    final held = st.customerInfo(c).jarsHeld;
    if (e.type == EntryType.emptyReturn && e.qty > held) return 'warnMoreThanHeld';
    if (e.type == EntryType.sale && e.emptyBack > held + e.qty) return 'warnMoreThanHeld';
    return null;
  }

  static List<Alert> buildAlerts(AppStore st) {
    final out = <Alert>[];
    for (final p in st.products) {
      final i = st.stockOf(p);
      if (i.level == StockLevel.out) {
        out.add(Alert(AlertKind.outOfStock, productId: p.id, n: i.suggestedOrder));
      } else if (i.level == StockLevel.low) {
        out.add(Alert(AlertKind.lowStock, productId: p.id, n: i.suggestedOrder));
      }
      if (p.returnable && i.empty > 0 && i.level != StockLevel.ok) {
        out.add(Alert(AlertKind.fillEmpties, productId: p.id, n: i.empty));
      }
    }
    final now = DateTime.now();
    var pendingCount = 0;
    double pendingTotal = 0;
    for (final c in st.customers) {
      final ci = st.customerInfo(c);
      if (ci.jarsHeld > 0) {
        final last = ci.lastActivity;
        if (last == null || now.difference(last).inDays >= st.settings.jarReminderDays) {
          out.add(Alert(AlertKind.collectJars, customerId: c.id, n: ci.jarsHeld));
        }
      }
      if (ci.due > 0.5) {
        pendingCount++;
        pendingTotal += ci.due;
      }
    }
    if (pendingCount > 0) {
      out.add(Alert(AlertKind.pendingMoney, n: pendingCount, amount: pendingTotal));
    }
    out.sort((a, b) => b.severity.compareTo(a.severity));
    return out;
  }
}
