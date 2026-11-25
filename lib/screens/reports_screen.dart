import 'package:flutter/material.dart';

import '../excel/export.dart';
import '../l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int days = 1; // 1 = today
  bool exporting = false;

  @override
  Widget build(BuildContext context) {
    return StoreBuilder(builder: (context, st) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
      final inRange = st.entries.where((e) => !e.date.isBefore(start)).toList();
      var sold = 0;
      double income = 0, cash = 0, profit = 0;
      final byItem = <String, int>{};
      final byItemMoney = <String, double>{};
      for (final e in inRange) {
        if (e.type == EntryType.sale) {
          sold += e.qty;
          income += e.amount;
          final p = st.productById(e.productId);
          profit += e.amount - (p?.cost ?? 0) * e.qty;
          if (e.productId != null) {
            byItem[e.productId!] = (byItem[e.productId!] ?? 0) + e.qty;
            byItemMoney[e.productId!] = (byItemMoney[e.productId!] ?? 0) + e.amount;
          }
        }
        if (e.type == EntryType.sale || e.type == EntryType.payment) cash += e.paid;
      }
      final toOrder = st.products.where((p) => st.stockOf(p).suggestedOrder > 0).toList();
      final maxSold = byItem.values.fold<int>(1, (m, v) => v > m ? v : m);
      final recent = st.entriesSorted().take(200).toList();

      return Scaffold(
        appBar: AppBar(title: Text(t('reports'))),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 1, label: Text(t('reportToday'))),
              ButtonSegment(value: 7, label: Text(t('report7'))),
              ButtonSegment(value: 30, label: Text(t('report30'))),
            ],
            selected: {days},
            onSelectionChanged: (s) => setState(() => days = s.first),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _stat(t('sold'), '$sold', Icons.local_shipping_rounded, AppColors.ok),
              _stat(t('income'), money(income), Icons.receipt_long_rounded, AppColors.water),
              _stat(t('collected'), money(cash), Icons.payments_rounded, const Color(0xFF7048E8)),
              _stat(t('profit'), money(profit), Icons.trending_up_rounded, const Color(0xFFF08C00)),
            ],
          ),
          SectionTitle(t('byItem')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: byItem.isEmpty
                  ? Text(t('noData'), style: const TextStyle(color: Colors.blueGrey, fontSize: 16))
                  : Column(children: [
                      for (final id in (byItem.keys.toList()..sort((a, b) => byItem[b]!.compareTo(byItem[a]!))))
                        if (st.productById(id) != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(children: [
                              ProductAvatar(st.productById(id)!, size: 36),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Expanded(child: Text(st.productById(id)!.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                                    Text('${byItem[id]}  •  ₹${money(byItemMoney[id] ?? 0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                  ]),
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: byItem[id]! / maxSold,
                                      minHeight: 8,
                                      color: AppColors.product(st.productById(id)!.colorIndex),
                                      backgroundColor: Colors.blueGrey.shade50,
                                    ),
                                  ),
                                ]),
                              ),
                            ]),
                          ),
                    ]),
            ),
          ),
          SectionTitle(t('shoppingList')),
          Card(
            child: toOrder.isEmpty
                ? ListTile(
                    leading: const Icon(Icons.verified_rounded, color: AppColors.ok),
                    title: Text(t('nothingToOrder'), style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
                  )
                : Column(children: [
                    for (final p in toOrder)
                      ListTile(
                        leading: ProductAvatar(p, size: 40),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(t('inStock', {'n': st.stockOf(p).full})),
                        trailing: Text('+${st.stockOf(p).suggestedOrder}',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.level(st.stockOf(p).level))),
                      ),
                  ]),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2F9E44)),
            onPressed: exporting
                ? null
                : () async {
                    setState(() => exporting = true);
                    try {
                      await ExcelExport.fullReport(st);
                    } finally {
                      if (mounted) setState(() => exporting = false);
                    }
                  },
            icon: const Icon(Icons.download_rounded, size: 28),
            label: Text(t('exportExcel')),
          ),
          SectionTitle(t('allEntries')),
          if (recent.isEmpty) EmptyState(text: t('noData')),
          for (final e in recent) Padding(padding: const EdgeInsets.only(bottom: 8), child: EntryTile(e)),
        ]),
      );
    });
  }

  Widget _stat(String label, String value, IconData icon, Color c) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: c),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: c))),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.blueGrey)),
          ]),
        ),
      );
}
