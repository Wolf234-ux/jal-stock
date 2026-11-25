import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'entry_screen.dart';
import 'product_edit_screen.dart';

class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreBuilder(builder: (context, st) {
      final list = [...st.products]..sort((a, b) => st.stockOf(b).level.index.compareTo(st.stockOf(a).level.index));
      return Scaffold(
        appBar: AppBar(title: Text(t('stock'))),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.water,
          foregroundColor: Colors.white,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductEditScreen())),
          icon: const Icon(Icons.add_rounded),
          label: Text(t('addProduct'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        body: list.isEmpty
            ? EmptyState(icon: Icons.inventory_2_outlined, text: t('noData'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => ProductCard(list[i]),
              ),
      );
    });
  }
}

class ProductCard extends StatelessWidget {
  final Product p;
  const ProductCard(this.p, {super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppStore.instance;
    final i = st.stockOf(p);
    final lc = AppColors.level(i.level);
    final ratio = i.minStock > 0 ? (i.full / (i.minStock * 2)).clamp(0.0, 1.0) : 1.0;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _detail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ProductAvatar(p),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  StatusChip(i.level),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${i.full}', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: lc, height: 1)),
                Text(p.unit, style: const TextStyle(color: Colors.blueGrey)),
                if (p.packSize > 1 && i.full >= p.packSize)
                  Text('≈ ${i.full ~/ p.packSize} ${t('boxes')}', style: const TextStyle(color: Colors.blueGrey, fontSize: 13)),
              ]),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: ratio, minHeight: 10, color: lc, backgroundColor: lc.withValues(alpha: .12)),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 14, runSpacing: 4, children: [
              if (i.minStock > 0) _info(Icons.flag_rounded, t('minStock', {'n': i.minStock})),
              if (i.daysLeft != null) _info(Icons.schedule_rounded, t('daysLeft', {'n': i.daysLeft!.floor()})),
              if (p.returnable) _info(Icons.water_drop_outlined, '${t('empty')}: ${i.empty}'),
              if (p.returnable) _info(Icons.groups_rounded, '${t('withCustomers')}: ${i.withCustomers}'),
            ]),
            if (i.suggestedOrder > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: lc.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.shopping_cart_rounded, color: lc),
                  const SizedBox(width: 8),
                  Text(t('orderNow', {'n': i.suggestedOrder}), style: TextStyle(color: lc, fontWeight: FontWeight.w800, fontSize: 16)),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 17, color: Colors.blueGrey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 14.5, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
      ]);

  void _detail(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id)));
  }
}

class ProductDetailScreen extends StatelessWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return StoreBuilder(builder: (context, st) {
      final p = st.productById(productId);
      if (p == null) return const Scaffold();
      final i = st.stockOf(p);
      final hist = st.entriesSorted().where((e) => e.productId == p.id).take(100).toList();
      void go(EntryType ty) => Navigator.push(context, MaterialPageRoute(builder: (_) => EntryScreen(type: ty, productId: p.id)));
      return Scaffold(
        appBar: AppBar(title: Text(p.name), actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductEditScreen(product: p))),
          ),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          ProductCard(p),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7048E8)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    i.minIsLearned
                        ? t('learnedMin', {'avg': i.avgDailySale.toStringAsFixed(1), 'n': i.minStock})
                        : (i.minStock > 0 ? t('manualMin', {'n': i.minStock}) : t('rule1')),
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _act(t('sell'), EntryType.sale, go),
            _act(t('stockIn'), EntryType.stockIn, go),
            if (p.returnable) _act(t('fill'), EntryType.fill, go),
            if (p.returnable) _act(t('emptyReturn'), EntryType.emptyReturn, go),
            _act(t('damage'), EntryType.damage, go),
            _act(t('adjust'), EntryType.adjust, go),
          ]),
          SectionTitle(t('history')),
          if (hist.isEmpty) EmptyState(text: t('noData')),
          for (final e in hist) Padding(padding: const EdgeInsets.only(bottom: 8), child: EntryTile(e)),
        ]),
      );
    });
  }

  Widget _act(String label, EntryType type, void Function(EntryType) go) => ActionChip(
        avatar: Icon(entryIcon(type), color: entryColor(type)),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        backgroundColor: Colors.white,
        onPressed: () => go(type),
      );
}
