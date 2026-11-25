import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../excel/excel_learner.dart';
import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class ProductEditScreen extends StatefulWidget {
  final Product? product;
  const ProductEditScreen({super.key, this.product});
  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final st = AppStore.instance;
  late final name = TextEditingController(text: widget.product?.name ?? '');
  late final price = TextEditingController(text: _n(widget.product?.price));
  late final cost = TextEditingController(text: _n(widget.product?.cost));
  late final full = TextEditingController(text: widget.product == null ? '' : '${st.stockOf(widget.product!).full}');
  late final empty = TextEditingController(text: widget.product == null ? '' : '${st.stockOf(widget.product!).empty}');
  late final min = TextEditingController(text: widget.product?.minStockManual?.toString() ?? '');
  late String unit = widget.product?.unit ?? 'Box';
  late bool returnable = widget.product?.returnable ?? false;
  late int color = widget.product?.colorIndex ?? st.products.length % AppColors.products.length;
  late final pack = TextEditingController(
      text: (widget.product?.packSize ?? 1) > 1 ? '${widget.product!.packSize}' : '');
  int kind = -1;

  // Item types the owner can pick: (label key, icon, unit, returnable, pack, sample name)
  static const kinds = [
    ('kindJar', Icons.water_drop_rounded, 'Jar', true, 1, '20 Litre Jar'),
    ('kindBigBottle', Icons.local_drink_rounded, 'Bottle', false, 12, '₹20 Bottle (1 Litre)'),
    ('kindSmallBottle', Icons.local_drink_outlined, 'Bottle', false, 24, '₹10 Bottle (500 ml)'),
    ('kindBox', Icons.inventory_2_rounded, 'Box', false, 1, '1 Litre Box (12)'),
    ('kindPouch', Icons.local_mall_rounded, 'Packet', false, 1, '₹2 Water Pouch'),
  ];

  void _pickKind(int i) {
    final k = kinds[i];
    setState(() {
      kind = i;
      unit = k.$3;
      returnable = k.$4;
      pack.text = k.$5 > 1 ? '${k.$5}' : '';
    });
  }

  static String _n(double? v) => (v == null || v == 0) ? '' : v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  int _i(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
  double _d(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Future<void> _save() async {
    if (name.text.trim().isEmpty) {
      toast(context, t('productName'), error: true);
      return;
    }
    final isNew = widget.product == null;
    final p = widget.product ?? Product(id: newId(), name: '');
    p
      ..name = name.text.trim()
      ..unit = unit
      ..returnable = returnable
      ..price = _d(price)
      ..cost = _d(cost)
      ..colorIndex = color
      ..minStockManual = min.text.trim().isEmpty ? null : _i(min)
      ..packSize = (unit == 'Bottle' || unit == 'Packet') && _i(pack) > 1 ? _i(pack) : 1;
    if (isNew) {
      p.openingFull = _i(full);
      p.openingEmpty = _i(empty);
      await st.upsertProduct(p);
    } else {
      // stock typed here = counted stock now. Fix difference with a "count fix" entry.
      final info = st.stockOf(p);
      final df = _i(full) - info.full;
      if (df != 0) {
        st.entries.add(Entry(id: newId(), date: DateTime.now(), type: EntryType.adjust, productId: p.id, qty: df));
      }
      p.openingEmpty += _i(empty) - info.empty;
      await st.upsertProduct(p);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final numF = [FilteringTextInputFormatter.allow(RegExp(r'[\d\.]'))];
    final preview = Product(id: 'x', name: name.text, unit: unit, returnable: returnable, colorIndex: color);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? t('addProduct') : t('editProduct')),
        actions: [
          if (widget.product != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                if (await confirm(context, '${t('delete')} ${widget.product!.name}?', yes: t('delete'))) {
                  await st.deleteProduct(widget.product!);
                  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                }
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 110), children: [
        if (widget.product == null) ...[
          Text(t('whatKind'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: .95,
            children: [
              for (var i = 0; i < kinds.length; i++)
                Material(
                  color: kind == i ? AppColors.water : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _pickKind(i),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(kinds[i].$2, size: 36, color: kind == i ? Colors.white : AppColors.water),
                        const SizedBox(height: 6),
                        Text(t(kinds[i].$1),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: kind == i ? Colors.white : null)),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        Center(child: ProductAvatar(preview, size: 84)),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: AppColors.products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => setState(() => color = i),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.products[i],
                child: color == i ? const Icon(Icons.check, color: Colors.white) : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: name,
          style: const TextStyle(fontSize: 20),
          decoration: InputDecoration(labelText: t('productName'), hintText: kind >= 0 ? kinds[kind].$6 : '20 Litre Jar'),
          onChanged: (v) => setState(() {
            if (widget.product == null && ExcelLearner.looksReturnable(v, '')) {
              returnable = true;
              unit = 'Jar';
            }
          }),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (final u in const ['Jar', 'Box', 'Bottle', 'Packet'])
            ChoiceChip(
              label: Text(u, style: const TextStyle(fontSize: 16)),
              selected: unit == u,
              onSelected: (_) => setState(() => unit = u),
            ),
        ]),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: returnable,
          onChanged: (v) => setState(() => returnable = v),
          title: Text(t('returnable'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          secondary: const Icon(Icons.recycling_rounded, color: AppColors.water),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, inputFormatters: numF, decoration: InputDecoration(labelText: t('price')))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: cost, keyboardType: TextInputType.number, inputFormatters: numF, decoration: InputDecoration(labelText: t('cost')))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: full,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              decoration: InputDecoration(labelText: t('openingFull')),
            ),
          ),
          if (returnable) ...[
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: empty,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                decoration: InputDecoration(labelText: t('openingEmpty')),
              ),
            ),
          ],
        ]),
        if (unit == 'Bottle' || unit == 'Packet') ...[
          const SizedBox(height: 12),
          TextField(
            controller: pack,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: t('packSize'), hintText: '24', prefixIcon: const Icon(Icons.inventory_2_outlined)),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: min,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: t('minManual'), prefixIcon: const Icon(Icons.flag_rounded)),
        ),
      ]),
      bottomSheet: SafeArea(
        child: Container(
          color: AppColors.bg,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.check_rounded, size: 30), label: Text(t('save'))),
        ),
      ),
    );
  }
}
