import 'package:flutter/material.dart';

import '../l10n.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'import_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;
  final nameCtl = TextEditingController();

  AppStore get st => AppStore.instance;

  Future<void> _finish(String how) async {
    st.settings.businessName = nameCtl.text.trim();
    st.settings.onboarded = true;
    if (how == 'sample') await st.loadStarterProducts();
    await st.changed();
    if (how == 'excel') {
      // app root now shows Home; open import on top of it
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navKey.currentState?.push(MaterialPageRoute(builder: (_) => const ImportScreen()));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: waterGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: switch (step) {
                0 => _lang(),
                1 => _name(),
                _ => _start(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() => Column(children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(30)),
          child: const Icon(Icons.water_drop_rounded, size: 60, color: Colors.white),
        ),
        const SizedBox(height: 14),
        Text(t('appName'), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 28),
      ]);

  Widget _bigChoice({required IconData icon, required String title, String? sub, required VoidCallback onTap, bool selected = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: selected ? Colors.white : Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Icon(icon, size: 40, color: selected ? AppColors.water : Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: selected ? AppColors.deep : Colors.white)),
                  if (sub != null)
                    Text(sub, style: TextStyle(fontSize: 15, color: selected ? Colors.blueGrey : Colors.white70)),
                ]),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: selected ? AppColors.water : Colors.white70),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _lang() => ListView(key: const ValueKey(0), children: [
        _logo(),
        Text(t('chooseLang'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, color: Colors.white)),
        const SizedBox(height: 20),
        for (final l in languages.entries)
          _bigChoice(
            icon: Icons.translate_rounded,
            title: l.value,
            selected: st.settings.lang == l.key,
            onTap: () async {
              await st.setLang(l.key);
              setState(() => step = 1);
            },
          ),
      ]);

  Widget _name() => ListView(key: const ValueKey(1), children: [
        _logo(),
        Text(t('welcome'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 24),
        TextField(
          controller: nameCtl,
          style: const TextStyle(fontSize: 22),
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: t('businessName'), prefixIcon: const Icon(Icons.storefront_rounded)),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.deep),
          onPressed: () => setState(() => step = 2),
          child: Text(t('next')),
        ),
      ]);

  Widget _start() => ListView(key: const ValueKey(2), children: [
        _logo(),
        Text(t('startHow'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        _bigChoice(icon: Icons.upload_file_rounded, title: t('startExcel'), sub: t('startExcelSub'), onTap: () => _finish('excel')),
        _bigChoice(icon: Icons.water_drop_rounded, title: t('startSample'), sub: t('startSampleSub'), onTap: () => _finish('sample')),
        _bigChoice(icon: Icons.add_rounded, title: t('startEmpty'), onTap: () => _finish('empty')),
      ]);
}
