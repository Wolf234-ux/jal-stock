import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n.dart';
import 'models.dart';
import 'rules.dart';
import 'store.dart';
import 'theme.dart';

final navKey = GlobalKey<NavigatorState>();

/// Rebuilds when store data changes.
class StoreBuilder extends StatelessWidget {
  final Widget Function(BuildContext, AppStore) builder;
  const StoreBuilder({super.key, required this.builder});
  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: AppStore.instance, builder: (c, _) => builder(c, AppStore.instance));
}

class ProductAvatar extends StatelessWidget {
  final Product p;
  final double size;
  const ProductAvatar(this.p, {super.key, this.size = 52});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.product(p.colorIndex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.withValues(alpha: .85), c], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * .32),
        boxShadow: [BoxShadow(color: c.withValues(alpha: .3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Icon(productIcon(p), color: Colors.white, size: size * .55),
    );
  }
}

class StatusChip extends StatelessWidget {
  final StockLevel level;
  const StatusChip(this.level, {super.key});
  @override
  Widget build(BuildContext context) {
    final label = switch (level) {
      StockLevel.ok => t('statusOk'),
      StockLevel.near => t('statusNear'),
      StockLevel.low => t('statusLow'),
      StockLevel.out => t('statusOut'),
    };
    final c = AppColors.level(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(30)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(level == StockLevel.ok ? Icons.check_circle : Icons.warning_rounded, color: c, size: 18),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 14)),
      ]),
    );
  }
}

/// Big round + / - buttons with a large number in the middle.
class QtyPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final Color color;
  const QtyPicker({super.key, required this.value, required this.onChanged, this.min = 0, this.color = AppColors.water});

  Future<void> _type(BuildContext context) async {
    final ctl = TextEditingController(text: value == 0 ? '' : '$value');
    final r = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('quantity')),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))],
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, int.tryParse(ctl.text) ?? 0), child: const Text('OK')),
        ],
      ),
    );
    if (r != null) onChanged(r < min ? min : r);
  }

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, int d) => Material(
          color: color.withValues(alpha: .12),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.selectionClick();
              final n = value + d;
              onChanged(n < min ? min : n);
            },
            onLongPress: () {
              final n = value + d * 10;
              onChanged(n < min ? min : n);
            },
            child: SizedBox(width: 68, height: 68, child: Icon(i, size: 38, color: color)),
          ),
        );
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      btn(Icons.remove_rounded, -1),
      Expanded(
        child: GestureDetector(
          onTap: () => _type(context),
          child: Column(children: [
            Text('$value', style: TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: color, height: 1)),
            const SizedBox(height: 4),
            Icon(Icons.keyboard_rounded, size: 18, color: Colors.blueGrey.shade300),
          ]),
        ),
      ),
      btn(Icons.add_rounded, 1),
    ]);
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, this.icon = Icons.inbox_rounded, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          Icon(icon, size: 72, color: Colors.blueGrey.shade200),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.blueGrey.shade400)),
        ]),
      );
}

/// Big, simple dialog for a problem, with an optional fix button.
Future<void> showProblem(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  HapticFeedback.heavyImpact();
  return showDialog(
    context: context,
    builder: (c) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: AppColors.low.withValues(alpha: .12), shape: BoxShape.circle),
            child: const Icon(Icons.info_rounded, color: AppColors.low, size: 46),
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.35)),
          const SizedBox(height: 22),
          if (actionLabel != null && onAction != null) ...[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(c);
                onAction();
              },
              child: Text(actionLabel),
            ),
            const SizedBox(height: 8),
          ],
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(t('okGotIt'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    ),
  );
}

/// Sticky bottom bar with the big SAVE button.
class SaveBar extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color color;
  final String? label;
  const SaveBar({super.key, required this.onPressed, this.color = AppColors.water, this.label});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: color),
              onPressed: onPressed,
              icon: const Icon(Icons.check_rounded, size: 30),
              label: Text(label ?? t('save')),
            ),
          ),
        ),
      );
}

String alertText(Alert a) {
  final st = AppStore.instance;
  final p = st.productById(a.productId);
  final c = st.customerById(a.customerId);
  return switch (a.kind) {
    AlertKind.outOfStock => t('outMsg', {'name': p?.name ?? '', 'n': a.n}),
    AlertKind.lowStock => t('lowMsg', {'name': p?.name ?? '', 'n': a.n}),
    AlertKind.fillEmpties => t('fillMsg', {'name': p?.name ?? '', 'n': a.n}),
    AlertKind.collectJars => t('jarsMsg', {'name': c?.name ?? '', 'n': a.n}),
    AlertKind.pendingMoney => t('moneyMsg', {'n': a.n, 'amt': money(a.amount)}),
  };
}

Color alertColor(Alert a) => switch (a.kind) {
      AlertKind.outOfStock => AppColors.out,
      AlertKind.lowStock => AppColors.low,
      AlertKind.fillEmpties => AppColors.water,
      AlertKind.collectJars => AppColors.near,
      AlertKind.pendingMoney => const Color(0xFF7048E8),
    };

IconData alertIcon(Alert a) => switch (a.kind) {
      AlertKind.outOfStock => Icons.error_rounded,
      AlertKind.lowStock => Icons.trending_down_rounded,
      AlertKind.fillEmpties => Icons.water_drop_outlined,
      AlertKind.collectJars => Icons.assignment_return_rounded,
      AlertKind.pendingMoney => Icons.currency_rupee_rounded,
    };

Future<bool> confirm(BuildContext context, String msg, {String? yes}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(msg, style: const TextStyle(fontSize: 18)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('no'), style: const TextStyle(fontSize: 17))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(yes ?? t('yes'), style: const TextStyle(fontSize: 17))),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: error ? AppColors.out : AppColors.ok,
      content: Row(children: [
        Icon(error ? Icons.error_rounded : Icons.check_circle_rounded, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
    ));
}

String entryLabel(EntryType e) => switch (e) {
      EntryType.stockIn => t('stockIn'),
      EntryType.sale => t('sell'),
      EntryType.emptyReturn => t('emptyReturn'),
      EntryType.fill => t('fill'),
      EntryType.damage => t('damage'),
      EntryType.adjust => t('adjust'),
      EntryType.payment => t('payment'),
    };

IconData entryIcon(EntryType e) => switch (e) {
      EntryType.stockIn => Icons.add_box_rounded,
      EntryType.sale => Icons.local_shipping_rounded,
      EntryType.emptyReturn => Icons.assignment_return_rounded,
      EntryType.fill => Icons.water_drop_rounded,
      EntryType.damage => Icons.broken_image_rounded,
      EntryType.adjust => Icons.fact_check_rounded,
      EntryType.payment => Icons.currency_rupee_rounded,
    };

Color entryColor(EntryType e) => switch (e) {
      EntryType.stockIn => const Color(0xFF1C7ED6),
      EntryType.sale => AppColors.ok,
      EntryType.emptyReturn => const Color(0xFFF08C00),
      EntryType.fill => AppColors.aqua,
      EntryType.damage => AppColors.out,
      EntryType.adjust => const Color(0xFF495057),
      EntryType.payment => const Color(0xFF7048E8),
    };

class EntryTile extends StatelessWidget {
  final Entry e;
  final bool allowDelete;
  const EntryTile(this.e, {super.key, this.allowDelete = true});
  @override
  Widget build(BuildContext context) {
    final st = AppStore.instance;
    final p = st.productById(e.productId);
    final c = st.customerById(e.customerId);
    final color = entryColor(e.type);
    final qtyText = e.type == EntryType.payment
        ? '₹${money(e.paid)}'
        : (e.type == EntryType.adjust && e.qty > 0 ? '+${e.qty}' : '${e.type == EntryType.sale || e.type == EntryType.damage ? '-' : (e.type == EntryType.adjust ? '' : '+')}${e.qty}');
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: .14), child: Icon(entryIcon(e.type), color: color)),
        title: Text('${entryLabel(e.type)}${p != null ? ' · ${p.name}' : ''}',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([
          fmtDate(e.date),
          if (c != null) c.name,
          if (e.emptyBack > 0) '${t('empty')} +${e.emptyBack}',
          if (e.type == EntryType.sale && e.amount > 0) '₹${money(e.amount)}',
          if (e.note.isNotEmpty && e.note != 'Excel') e.note,
        ].join('  •  ')),
        trailing: Text(qtyText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        onLongPress: !allowDelete
            ? null
            : () async {
                if (await confirm(context, t('deleteEntryQ'), yes: t('delete'))) {
                  await st.deleteEntry(e);
                }
              },
      ),
    );
  }
}
