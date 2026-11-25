import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';
import '../models.dart';
import '../rules.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'customers_screen.dart';
import 'product_edit_screen.dart';

/// One screen for every kind of entry: sell, new stock, empty back, fill,
/// damage, count fix, money in.
class EntryScreen extends StatefulWidget {
  final EntryType type;
  final String? productId;
  final String? customerId;
  const EntryScreen({super.key, required this.type, this.productId, this.customerId});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final st = AppStore.instance;
  String? productId;
  String? customerId;
  int qty = 1;
  int emptyBack = 0;
  final amountCtl = TextEditingController();
  final paidCtl = TextEditingController();
  final noteCtl = TextEditingController();
  bool amountTouched = false;
  bool paidTouched = false;
  bool saving = false;
  bool inBoxes = false; // count in boxes instead of single bottles

  int get pack => product?.packSize ?? 1;
  bool get canUseBoxes =>
      pack > 1 && (type == EntryType.sale || type == EntryType.stockIn || type == EntryType.damage);
  /// real number of pieces this entry moves
  int get pieces => (canUseBoxes && inBoxes) ? qty * pack : qty;

  EntryType get type => widget.type;
  bool get needsProduct => type != EntryType.payment;
  bool get needsCustomer => type == EntryType.sale || type == EntryType.emptyReturn || type == EntryType.payment;

  List<Product> get choices =>
      (type == EntryType.emptyReturn || type == EntryType.fill) ? st.products.where((p) => p.returnable).toList() : st.products;

  Product? get product => st.productById(productId);

  @override
  void initState() {
    super.initState();
    productId = widget.productId;
    customerId = widget.customerId;
    if (productId == null && choices.length == 1) productId = choices.first.id;
    if (productId == null && choices.isNotEmpty && type != EntryType.damage) productId = choices.first.id;
    if (type == EntryType.adjust && product != null) qty = st.stockOf(product!).full;
    if (type == EntryType.payment) qty = 0;
    inBoxes = type == EntryType.stockIn; // stock usually comes in boxes
    _autoMoney();
  }

  void _autoMoney() {
    final p = product;
    if (type == EntryType.sale && p != null) {
      final bill = p.price * pieces;
      if (!amountTouched) amountCtl.text = bill > 0 ? bill.toStringAsFixed(0) : '';
      if (!paidTouched) {
        // walk-in pays cash; regular customers may pay later
        paidCtl.text = amountCtl.text;
      }
    }
    if (type == EntryType.stockIn && p != null && !amountTouched) {
      final c = p.cost * pieces;
      amountCtl.text = c > 0 ? c.toStringAsFixed(0) : '';
    }
  }

  double _d(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  Color get color => entryColor(type);

  Future<void> _save() async {
    if (saving) return;
    final p = product;
    var q = pieces;
    if (type == EntryType.adjust && p != null) q = qty - st.stockOf(p).full;
    final e = Entry(
      id: newId(),
      date: DateTime.now(),
      type: type,
      productId: needsProduct ? productId : null,
      customerId: needsCustomer ? customerId : null,
      qty: q,
      emptyBack: (type == EntryType.sale && (p?.returnable ?? false)) ? emptyBack : 0,
      amount: (type == EntryType.sale || type == EntryType.stockIn) ? _d(amountCtl) : 0,
      paid: (type == EntryType.sale || type == EntryType.payment) ? _d(paidCtl) : 0,
      note: noteCtl.text.trim(),
    );
    if (type == EntryType.adjust && q == 0) {
      Navigator.pop(context);
      return;
    }
    final err = StockRules.hardError(st, e);
    if (err != null) {
      await _explain(err, p);
      return;
    }
    final warn = StockRules.softWarning(st, e);
    if (warn != null && !await confirm(context, t(warn), yes: t('saveAnyway'))) return;
    setState(() => saving = true);
    await st.addEntry(e);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    await _successDialog(p);
    if (mounted) Navigator.pop(context);
  }

  /// Clear message + a button that fixes the problem.
  Future<void> _explain(String err, Product? p) async {
    final info = p == null ? null : st.stockOf(p);
    switch (err) {
      case 'errNotEnoughStock':
        await showProblem(
          context,
          '${t('errNotEnoughStock')}\n\n${t('inStock', {'n': info?.full ?? 0})}',
          actionLabel: t('addStockNow'),
          onAction: () => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => EntryScreen(type: EntryType.stockIn, productId: p?.id))),
        );
        break;
      case 'errNotEnoughEmpty':
        await showProblem(context, '${t('errNotEnoughEmpty')}\n\n${t('emptyInGodown', {'n': info?.empty ?? 0})}');
        break;
      case 'errPickProduct':
        await showProblem(
          context,
          st.products.isEmpty ? t('errNoItems') : t('errPickProduct'),
          actionLabel: st.products.isEmpty ? t('addProduct') : null,
          onAction: st.products.isEmpty
              ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductEditScreen()))
              : null,
        );
        break;
      case 'errPickCustomer':
        await showProblem(context, t('errPickCustomer'), actionLabel: t('pickCustomer'), onAction: _pickCustomer);
        break;
      default:
        await showProblem(context, t(err));
    }
  }

  Future<void> _successDialog(Product? p) async {
    String? after;
    if (p != null) {
      final i = st.stockOf(p);
      after = t('inStock', {'n': i.full});
      if (i.level == StockLevel.low || i.level == StockLevel.out) {
        after = '$after\n${t('orderNow', {'n': i.suggestedOrder})}';
      }
    }
    var open = true;
    var timerStarted = false;
    await showDialog(
      context: context,
      builder: (c) {
        if (!timerStarted) {
          timerStarted = true;
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (open && c.mounted) Navigator.of(c).pop();
          });
        }
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.ok, size: 90),
              const SizedBox(height: 8),
              Text(t('saved'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              if (after != null) ...[
                const SizedBox(height: 8),
                Text(after, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
              ],
            ]),
          ),
        );
      },
    );
    open = false;
  }

  Future<void> _pickCustomer() async {
    final id = await pickCustomerSheet(context, allowNone: type == EntryType.sale);
    if (id == null) return;
    setState(() {
      customerId = id.isEmpty ? null : id;
      _autoMoney();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StoreBuilder(builder: (context, _) {
      final p = product;
      final info = p == null ? null : st.stockOf(p);
      final c = st.customerById(customerId);
      return Scaffold(
        appBar: AppBar(
          backgroundColor: color,
          title: Row(children: [Icon(entryIcon(type)), const SizedBox(width: 10), Text(entryLabel(type))]),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
          if (needsProduct) ...[
            SectionTitle(t('pickProduct')),
            if (choices.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.add_circle_rounded, color: AppColors.water, size: 34),
                  title: Text(t('addProduct'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductEditScreen())),
                ),
              )
            else
              SizedBox(
                height: 172,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: choices.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final x = choices[i];
                    final sel = x.id == productId;
                    return GestureDetector(
                      onTap: () => setState(() {
                        productId = x.id;
                        if (type == EntryType.adjust) qty = st.stockOf(x).full;
                        if (x.packSize <= 1) inBoxes = false;
                        _autoMoney();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 128,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? color : Colors.transparent, width: 3),
                          boxShadow: sel ? [BoxShadow(color: color.withValues(alpha: .25), blurRadius: 12)] : null,
                        ),
                        child: Column(children: [
                          ProductAvatar(x, size: 50),
                          const SizedBox(height: 6),
                          Text(x.name,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, fontWeight: sel ? FontWeight.w900 : FontWeight.w600)),
                          if (x.price > 0)
                            Text('₹${money(x.price)}', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.level(st.stockOf(x).level).withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('${st.stockOf(x).full}',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.level(st.stockOf(x).level))),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            if (info != null) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _Pill(t('inStock', {'n': info.full}), AppColors.level(info.level)),
                if (p!.returnable) _Pill(t('emptyInGodown', {'n': info.empty}), AppColors.water),
              ]),
            ],
          ],
          if (needsCustomer) ...[
            SectionTitle(t('pickCustomer')),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF12A594).withValues(alpha: .15),
                  child: const Icon(Icons.person_rounded, color: Color(0xFF12A594), size: 30),
                ),
                title: Text(c?.name ?? t('noCustomer'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                subtitle: c == null
                    ? null
                    : Text([
                        if (st.customerInfo(c).jarsHeld != 0) t('jarsHeld', {'n': st.customerInfo(c).jarsHeld}),
                        if (st.customerInfo(c).due.abs() > .5) t('due', {'amt': money(st.customerInfo(c).due)}),
                      ].join('  •  ')),
                trailing: const Icon(Icons.expand_more_rounded, size: 32),
                onTap: _pickCustomer,
              ),
            ),
          ],
          if (type != EntryType.payment) ...[
            SectionTitle(type == EntryType.adjust ? t('countNow') : t('quantity')),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  if (canUseBoxes) ...[
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(value: false, icon: const Icon(Icons.local_drink_rounded), label: Text(t('bottles'), style: const TextStyle(fontSize: 16))),
                        ButtonSegment(value: true, icon: const Icon(Icons.inventory_2_rounded), label: Text(t('boxes'), style: const TextStyle(fontSize: 16))),
                      ],
                      selected: {inBoxes},
                      onSelectionChanged: (v) => setState(() {
                        inBoxes = v.first;
                        _autoMoney();
                      }),
                    ),
                    const SizedBox(height: 14),
                  ],
                  QtyPicker(
                    value: qty,
                    min: type == EntryType.adjust ? 0 : 1,
                    color: color,
                    onChanged: (v) => setState(() {
                      qty = v;
                      _autoMoney();
                    }),
                  ),
                  if (canUseBoxes && inBoxes)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(t('equalsBottles', {'n': pieces}), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                    ),
                  if (type == EntryType.adjust && info != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(t('currentIs', {'n': info.full}), style: const TextStyle(fontSize: 16, color: Colors.blueGrey)),
                    ),
                ]),
              ),
            ),
          ],
          if (type == EntryType.sale && (p?.returnable ?? false)) ...[
            SectionTitle(t('emptyBackQ')),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: QtyPicker(value: emptyBack, color: const Color(0xFFF08C00), onChanged: (v) => setState(() => emptyBack = v)),
              ),
            ),
          ],
          if (type == EntryType.sale) ...[
            const SizedBox(height: 16),
            _money(amountCtl, t('billAmount'), () => setState(() {
                  amountTouched = true;
                  if (!paidTouched) paidCtl.text = amountCtl.text;
                })),
            const SizedBox(height: 12),
            _money(paidCtl, t('paidNow'), () => paidTouched = true),
          ],
          if (type == EntryType.payment) ...[
            const SizedBox(height: 16),
            _money(paidCtl, t('paidNow'), () => paidTouched = true, big: true),
          ],
          if (type == EntryType.stockIn) ...[
            const SizedBox(height: 16),
            _money(amountCtl, t('newStockCost'), () => amountTouched = true),
          ],
          const SizedBox(height: 12),
          TextField(controller: noteCtl, decoration: InputDecoration(labelText: t('note'), prefixIcon: const Icon(Icons.edit_note_rounded))),
        ]),
        bottomNavigationBar: SaveBar(onPressed: saving ? null : _save, color: color),
      );
    });
  }

  Widget _money(TextEditingController c, String label, VoidCallback onChanged, {bool big = false}) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\.]'))],
        style: TextStyle(fontSize: big ? 34 : 22, fontWeight: FontWeight.w800),
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.currency_rupee_rounded)),
        onChanged: (_) => onChanged(),
      );
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(30)),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
      );
}
