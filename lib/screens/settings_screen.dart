import 'package:flutter/material.dart';

import '../l10n.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController name;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: AppStore.instance.settings.businessName);
  }

  @override
  Widget build(BuildContext context) {
    return StoreBuilder(builder: (context, st) {
      final s = st.settings;
      Widget stepper(String label, int value, int min, int max, int step, void Function(int) set) => Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                Expanded(child: Text(label, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600))),
                IconButton.filledTonal(
                  onPressed: value - step < min ? null : () async {
                    set(value - step);
                    await st.changed();
                  },
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 50,
                  child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ),
                IconButton.filledTonal(
                  onPressed: value + step > max ? null : () async {
                    set(value + step);
                    await st.changed();
                  },
                  icon: const Icon(Icons.add_rounded),
                ),
              ]),
            ),
          );

      return Scaffold(
        appBar: AppBar(title: Text(t('settings'))),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          SectionTitle(t('language')),
          Wrap(spacing: 10, children: [
            for (final l in languages.entries)
              ChoiceChip(
                label: Text(l.value, style: const TextStyle(fontSize: 18)),
                selected: s.lang == l.key,
                onSelected: (_) => st.setLang(l.key),
              ),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: name,
            decoration: InputDecoration(labelText: t('businessName'), prefixIcon: const Icon(Icons.storefront_rounded)),
            onChanged: (v) {
              s.businessName = v.trim();
              st.changed();
            },
          ),
          SectionTitle(t('rulesTitle')),
          stepper(t('leadDays'), s.leadDays, 1, 15, 1, (v) => s.leadDays = v),
          const SizedBox(height: 8),
          stepper(t('safety'), s.safetyPercent, 0, 100, 10, (v) => s.safetyPercent = v),
          const SizedBox(height: 8),
          stepper(t('jarDays'), s.jarReminderDays, 1, 60, 1, (v) => s.jarReminderDays = v),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              value: s.autoMinStock,
              title: Text(t('autoMin'), style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
              secondary: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7048E8)),
              onChanged: (v) {
                s.autoMinStock = v;
                st.changed();
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final k in ['rule1', 'rule2', 'rule3', 'rule4', 'rule5'])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.ok, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(t(k), style: const TextStyle(fontSize: 15.5))),
                    ]),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.out,
              side: const BorderSide(color: AppColors.out),
              minimumSize: const Size.fromHeight(54),
            ),
            onPressed: () async {
              if (await confirm(context, t('resetQ'), yes: t('delete'))) await st.resetAll();
            },
            icon: const Icon(Icons.delete_forever_rounded),
            label: Text(t('resetAll'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 20),
          const Center(child: Text('JalStock v1.0', style: TextStyle(color: Colors.blueGrey))),
        ]),
      );
    });
  }
}
