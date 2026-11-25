import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'entry_screen.dart';

const _teal = Color(0xFF12A594);

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    return StoreBuilder(builder: (context, st) {
      final list = st.customers.where((c) => q.isEmpty || '${c.name} ${c.phone} ${c.area}'.toLowerCase().contains(q.toLowerCase())).toList()
        ..sort((a, b) => st.customerInfo(b).jarsHeld.compareTo(st.customerInfo(a).jarsHeld));
      return Scaffold(
        appBar: AppBar(title: Text(t('customers'))),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          onPressed: () => editCustomer(context),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: Text(t('addCustomer'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: InputDecoration(hintText: t('searchHint'), prefixIcon: const Icon(Icons.search_rounded)),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(icon: Icons.groups_outlined, text: t('noData'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _CustomerTile(list[i]),
                  ),
          ),
        ]),
      );
    });
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer c;
  const _CustomerTile(this.c);
  @override
  Widget build(BuildContext context) {
    final ci = AppStore.instance.customerInfo(c);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: _teal.withValues(alpha: .15),
          child: Text(c.name.isEmpty ? '?' : c.name.characters.first.toUpperCase(),
              style: const TextStyle(color: _teal, fontSize: 22, fontWeight: FontWeight.w900)),
        ),
        title: Text(c.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        subtitle: Text([if (c.area.isNotEmpty) c.area, if (c.phone.isNotEmpty) c.phone].join('  •  ')),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (ci.jarsHeld != 0)
            Text(t('jarsHeld', {'n': ci.jarsHeld}), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.water)),
          if (ci.due.abs() > .5)
            Text(t('due', {'amt': money(ci.due)}), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.out)),
        ]),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: c.id))),
      ),
    );
  }
}

class CustomerDetailScreen extends StatelessWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return StoreBuilder(builder: (context, st) {
      final c = st.customerById(customerId);
      if (c == null) return const Scaffold();
      final ci = st.customerInfo(c);
      final hist = st.entriesSorted().where((e) => e.customerId == c.id).take(150).toList();
      void go(EntryType ty) => Navigator.push(context, MaterialPageRoute(builder: (_) => EntryScreen(type: ty, customerId: c.id)));
      final hasJars = st.products.any((p) => p.returnable);
      return Scaffold(
        appBar: AppBar(title: Text(c.name), actions: [
          IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => editCustomer(context, c)),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(child: _Big(t('jarsHeld', {'n': ''}).trim(), '${ci.jarsHeld}', AppColors.water, Icons.water_drop_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _Big(t('due', {'amt': ''}).replaceAll('₹', '').trim(), '₹${money(ci.due)}', AppColors.out, Icons.currency_rupee_rounded)),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _chip(t('sell'), EntryType.sale, () => go(EntryType.sale)),
            if (hasJars) _chip(t('emptyReturn'), EntryType.emptyReturn, () => go(EntryType.emptyReturn)),
            _chip(t('payment'), EntryType.payment, () => go(EntryType.payment)),
            if (c.phone.isNotEmpty)
              ActionChip(
                avatar: const Icon(Icons.call_rounded, color: AppColors.ok),
                label: Text(t('call'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                backgroundColor: Colors.white,
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: c.phone)),
              ),
            if (c.phone.isNotEmpty && (ci.jarsHeld > 0 || ci.due > .5))
              ActionChip(
                avatar: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                label: const Text('WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                backgroundColor: Colors.white,
                onPressed: () => _whatsApp(c, ci),
              ),
          ]),
          SectionTitle(t('history')),
          if (hist.isEmpty) EmptyState(text: t('noData')),
          for (final e in hist) Padding(padding: const EdgeInsets.only(bottom: 8), child: EntryTile(e)),
        ]),
      );
    });
  }

  Future<void> _whatsApp(Customer c, CustomerInfo ci) async {
    var phone = c.phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length == 10) phone = '91$phone';
    final shop = AppStore.instance.settings.businessName;
    final parts = <String>[
      'Namaste ${c.name} 🙏',
      if (ci.jarsHeld > 0) 'Empty jars with you: ${ci.jarsHeld}. Please return.',
      if (ci.due > .5) 'Pending amount: ₹${money(ci.due)}',
      if (shop.isNotEmpty) '- $shop',
    ];
    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(parts.join('\n'))}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _chip(String label, EntryType ty, VoidCallback onTap) => ActionChip(
        avatar: Icon(entryIcon(ty), color: entryColor(ty)),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        backgroundColor: Colors.white,
        onPressed: onTap,
      );
}

class _Big extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _Big(this.label, this.value, this.color, this.icon);
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: color))),
            Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 15)),
          ]),
        ),
      );
}

/// Add or edit a customer in a bottom sheet. Returns the customer id.
Future<String?> editCustomer(BuildContext context, [Customer? existing]) async {
  final st = AppStore.instance;
  final name = TextEditingController(text: existing?.name ?? '');
  final phone = TextEditingController(text: existing?.phone ?? '');
  final area = TextEditingController(text: existing?.area ?? '');
  final jars = TextEditingController(text: existing == null || existing.openingJars == 0 ? '' : '${existing.openingJars}');
  final due = TextEditingController(text: existing == null || existing.openingDue == 0 ? '' : existing.openingDue.toStringAsFixed(0));
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(existing == null ? t('addCustomer') : t('editCustomer'), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(controller: name, autofocus: existing == null, textCapitalization: TextCapitalization.words, style: const TextStyle(fontSize: 19), decoration: InputDecoration(labelText: t('customerName'), prefixIcon: const Icon(Icons.person_rounded))),
          const SizedBox(height: 10),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: t('phone'), prefixIcon: const Icon(Icons.call_rounded))),
          const SizedBox(height: 10),
          TextField(controller: area, decoration: InputDecoration(labelText: t('area'), prefixIcon: const Icon(Icons.place_rounded))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: jars, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))], decoration: InputDecoration(labelText: t('openingJars')))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: due, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\.]'))], decoration: InputDecoration(labelText: t('openingDue')))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            if (existing != null)
              IconButton(
                iconSize: 30,
                color: AppColors.out,
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  if (await confirm(c, '${t('delete')} ${existing.name}?', yes: t('delete'))) {
                    await st.deleteCustomer(existing);
                    if (c.mounted) Navigator.of(c).popUntil((r) => r.isFirst);
                  }
                },
              ),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _teal),
                onPressed: () async {
                  if (name.text.trim().isEmpty) return;
                  final cu = existing ?? Customer(id: newId(), name: '');
                  cu
                    ..name = name.text.trim()
                    ..phone = phone.text.trim()
                    ..area = area.text.trim()
                    ..openingJars = int.tryParse(jars.text.trim()) ?? 0
                    ..openingDue = double.tryParse(due.text.trim()) ?? 0;
                  await st.upsertCustomer(cu);
                  if (c.mounted) Navigator.pop(c, cu.id);
                },
                child: Text(t('save')),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
}

/// Searchable list to choose a customer. Returns id, '' for walk-in, null if closed.
Future<String?> pickCustomerSheet(BuildContext context, {bool allowNone = true}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => _CustomerPicker(allowNone: allowNone),
  );
}

class _CustomerPicker extends StatefulWidget {
  final bool allowNone;
  const _CustomerPicker({required this.allowNone});
  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final st = AppStore.instance;
    final list = st.customers.where((c) => q.isEmpty || '${c.name} ${c.phone} ${c.area}'.toLowerCase().contains(q.toLowerCase())).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return SizedBox(
      height: MediaQuery.of(context).size.height * .8,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom),
        child: Column(children: [
          TextField(
            autofocus: false,
            onChanged: (v) => setState(() => q = v),
            decoration: InputDecoration(hintText: t('searchHint'), prefixIcon: const Icon(Icons.search_rounded)),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const CircleAvatar(backgroundColor: _teal, child: Icon(Icons.person_add_alt_1_rounded, color: Colors.white)),
            title: Text(t('addCustomer'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _teal)),
            onTap: () async {
              final id = await editCustomer(context);
              if (id != null && context.mounted) Navigator.pop(context, id);
            },
          ),
          if (widget.allowNone)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.storefront_rounded)),
              title: Text(t('noCustomer'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, ''),
            ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final c = list[i];
                final ci = st.customerInfo(c);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _teal.withValues(alpha: .15),
                    child: Text(c.name.isEmpty ? '?' : c.name.characters.first.toUpperCase(), style: const TextStyle(color: _teal, fontWeight: FontWeight.w900)),
                  ),
                  title: Text(c.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  subtitle: c.area.isEmpty ? null : Text(c.area),
                  trailing: ci.jarsHeld != 0 ? Text(t('jarsHeld', {'n': ci.jarsHeld}), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.water)) : null,
                  onTap: () => Navigator.pop(context, c.id),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
