import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models.dart';
import '../rules.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'customers_screen.dart';
import 'entry_screen.dart';
import 'import_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'stock_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _go(BuildContext c, Widget w) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    return StoreBuilder(builder: (context, st) {
      final now = DateTime.now();
      final today = st.entries.where((e) => e.date.year == now.year && e.date.month == now.month && e.date.day == now.day);
      var soldToday = 0;
      double cashToday = 0;
      for (final e in today) {
        if (e.type == EntryType.sale) soldToday += e.qty;
        if (e.type == EntryType.sale || e.type == EntryType.payment) cashToday += e.paid;
      }
      var full = 0, empty = 0, withC = 0;
      for (final p in st.products.where((p) => p.returnable)) {
        final i = st.stockOf(p);
        full += i.full;
        empty += i.empty;
        withC += i.withCustomers;
      }
      final hasJars = st.products.any((p) => p.returnable);

      return Scaffold(
        body: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: waterGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 12, 26),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.water_drop_rounded, color: Colors.white, size: 30),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      st.settings.businessName.isEmpty ? t('appName') : st.settings.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(20)),
                    child: const Text('v$appVersion', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    onPressed: () => _go(context, const SettingsScreen()),
                    icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 28),
                  ),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  _HeaderStat(label: t('salesToday'), value: '$soldToday', icon: Icons.local_shipping_rounded),
                  const SizedBox(width: 12),
                  _HeaderStat(label: t('cashToday'), value: '₹${money(cashToday)}', icon: Icons.currency_rupee_rounded),
                ]),
                if (hasJars) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(18)),
                    child: Row(children: [
                      _JarStat(t('full'), full, Icons.water_drop_rounded),
                      _JarStat(t('empty'), empty, Icons.water_drop_outlined),
                      _JarStat(t('withCustomers'), withC, Icons.groups_rounded),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(child: _AlertsCard(alerts: st.alerts, onOpenStock: () => _go(context, const StockScreen()))),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.25,
              children: [
                _Tile(t('sell'), Icons.local_shipping_rounded, AppColors.ok, () => _go(context, const EntryScreen(type: EntryType.sale))),
                _Tile(t('stockIn'), Icons.add_box_rounded, const Color(0xFF1C7ED6), () => _go(context, const EntryScreen(type: EntryType.stockIn))),
                if (hasJars)
                  _Tile(t('emptyReturn'), Icons.assignment_return_rounded, const Color(0xFFF08C00),
                      () => _go(context, const EntryScreen(type: EntryType.emptyReturn))),
                if (hasJars)
                  _Tile(t('fill'), Icons.water_drop_rounded, AppColors.aqua, () => _go(context, const EntryScreen(type: EntryType.fill))),
                _Tile(t('payment'), Icons.currency_rupee_rounded, const Color(0xFF7048E8), () => _go(context, const EntryScreen(type: EntryType.payment))),
                _Tile(t('damage'), Icons.broken_image_rounded, AppColors.out, () => _go(context, const EntryScreen(type: EntryType.damage))),
                _Tile(t('stock'), Icons.inventory_rounded, AppColors.deep, () => _go(context, const StockScreen())),
                _Tile(t('customers'), Icons.groups_rounded, const Color(0xFF12A594), () => _go(context, const CustomersScreen())),
                _Tile(t('uploadExcel'), Icons.upload_file_rounded, const Color(0xFF2F9E44), () => _go(context, const ImportScreen())),
                _Tile(t('reports'), Icons.bar_chart_rounded, const Color(0xFFE64980), () => _go(context, const ReportsScreen())),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ]),
      );
    });
  }
}

class _HeaderStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _HeaderStat({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Icon(icon, color: AppColors.water, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.deep)),
                ),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
              ]),
            ),
          ]),
        ),
      );
}

class _JarStat extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  const _JarStat(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 4),
            Text('$value', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          ]),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      );
}

class _Tile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Tile(this.label, this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(20)),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(height: 10),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );
}

class _AlertsCard extends StatelessWidget {
  final List<Alert> alerts;
  final VoidCallback onOpenStock;
  const _AlertsCard({required this.alerts, required this.onOpenStock});

  @override
  Widget build(BuildContext context) {
    if (AppStore.instance.products.isEmpty) {
      return Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: const Icon(Icons.upload_file_rounded, size: 36, color: AppColors.water),
          title: Text(t('startExcel'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          subtitle: Text(t('startExcelSub')),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ImportScreen())),
        ),
      );
    }
    if (alerts.isEmpty) {
      return Card(
        color: AppColors.ok.withValues(alpha: .1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.verified_rounded, color: AppColors.ok, size: 34),
            const SizedBox(width: 12),
            Expanded(child: Text(t('allGood'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ok))),
          ]),
        ),
      );
    }
    final show = alerts.take(4).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.notifications_active_rounded, color: AppColors.low),
            const SizedBox(width: 8),
            Expanded(child: Text('${t('alerts')} (${alerts.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 6),
          for (final a in show)
            InkWell(
              onTap: onOpenStock,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Icon(alertIcon(a), color: alertColor(a), size: 26),
                  const SizedBox(width: 12),
                  Expanded(child: Text(alertText(a), style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: alertColor(a)))),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
