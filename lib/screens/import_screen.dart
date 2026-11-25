import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../excel/excel_learner.dart';
import '../excel/export.dart';
import '../excel/xlsx_io.dart';
import '../l10n.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final st = AppStore.instance;
  bool busy = false;
  String? fileName;
  ImportPlan? plan;
  String? error;

  Future<void> _pick() async {
    setState(() {
      error = null;
      plan = null;
    });
    final res = await FilePicker.platform.pickFiles(
      type: FileType.any, // some phones hide .xlsx with custom filters
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    setState(() {
      busy = true;
      fileName = f.name;
    });
    try {
      List<int>? bytes = f.bytes;
      if (bytes == null && f.path != null) bytes = await File(f.path!).readAsBytes();
      if (bytes == null) throw UnsupportedFileException('unknown');
      final sheets = XlsxReader.readAny(bytes, f.name);
      final p = ExcelLearner.learn(sheets, st.settings);
      setState(() {
        plan = p;
        if (p.isEmpty) error = t('nothingFound');
      });
    } on UnsupportedFileException catch (e) {
      setState(() => error = e.reason == 'xls' ? t('xlsOld') : t('importFail'));
    } catch (e) {
      debugPrint('Import error: $e');
      setState(() => error = t('importFail'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _apply(bool replace) async {
    final p = plan;
    if (p == null) return;
    if (replace && (st.products.isNotEmpty || st.entries.isNotEmpty)) {
      if (!await confirm(context, t('resetQ'), yes: t('applyReplace'))) return;
    }
    setState(() => busy = true);
    await ExcelLearner.apply(st, p, replace: replace);
    if (!mounted) return;
    toast(context, t('importDone'));
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final p = plan;
    final lang = st.settings.lang;
    return Scaffold(
      appBar: AppBar(title: Text(t('importTitle'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: const Color(0xFF2F9E44).withValues(alpha: .12), borderRadius: BorderRadius.circular(28)),
                child: const Icon(Icons.table_view_rounded, size: 52, color: Color(0xFF2F9E44)),
              ),
              const SizedBox(height: 14),
              Text(t('importHelp'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16.5, height: 1.4)),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2F9E44)),
                onPressed: busy ? null : _pick,
                icon: const Icon(Icons.folder_open_rounded, size: 28),
                label: Text(t('pickFile')),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => ExcelExport.template(),
                icon: const Icon(Icons.download_rounded),
                label: Text(t('downloadTemplate'), style: const TextStyle(fontSize: 16)),
              ),
            ]),
          ),
        ),
        if (busy) ...[
          const SizedBox(height: 30),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 12),
          Text(t('reading'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
        ],
        if (error != null) ...[
          const SizedBox(height: 16),
          Card(
            color: AppColors.out.withValues(alpha: .08),
            child: ListTile(
              leading: const Icon(Icons.error_rounded, color: AppColors.out, size: 32),
              title: Text(error!, style: const TextStyle(color: AppColors.out, fontWeight: FontWeight.w700, fontSize: 16)),
              subtitle: fileName == null ? null : Text(fileName!),
            ),
          ),
        ],
        if (p != null && !p.isEmpty && !busy) ...[
          SectionTitle('${t('foundTitle')} · ${fileName ?? ''}'),
          Row(children: [
            _count(Icons.inventory_2_rounded, t('foundProducts', {'n': p.products.length}), AppColors.water),
            const SizedBox(width: 10),
            _count(Icons.groups_rounded, t('foundCustomers', {'n': p.customers.length}), const Color(0xFF12A594)),
            const SizedBox(width: 10),
            _count(Icons.receipt_long_rounded, t('foundEntries', {'n': p.entries.length}), const Color(0xFF7048E8)),
          ]),
          SectionTitle(t('rulesLearned')),
          Card(
            child: Column(children: [
              for (final r in p.rules)
                ListTile(
                  leading: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7048E8)),
                  title: Text(r.product, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5)),
                  subtitle: Text([
                    if (p.products[normKey(r.product)]?.qty != null) t('inStock', {'n': p.products[normKey(r.product)]!.qty}),
                    if (r.autoOpening > 0) t('inStock', {'n': '≥${r.autoOpening}'}),
                    if (r.manual)
                      t('manualMin', {'n': r.min})
                    else if (r.min > 0)
                      t('learnedMin', {'avg': r.avgDaily.toStringAsFixed(1), 'n': r.min}),
                    if (p.products[normKey(r.product)]?.returnable ?? false) '💧 ${t('returnable')}',
                  ].join('\n')),
                ),
            ]),
          ),
          SectionTitle(t('columnsUnderstood')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in p.columns)
                  Chip(
                    avatar: const Icon(Icons.check_circle, color: AppColors.ok, size: 18),
                    label: Text('${c.header} → ${fieldLabel(c.field, lang)}', style: const TextStyle(fontSize: 14)),
                  ),
              ]),
            ),
          ),
          if (p.skipped > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(t('skippedRows', {'n': p.skipped}), style: const TextStyle(color: Colors.blueGrey)),
            ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: () => _apply(false),
            icon: const Icon(Icons.playlist_add_check_rounded, size: 30),
            label: Text(t('applyAdd')),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              foregroundColor: AppColors.out,
              side: const BorderSide(color: AppColors.out, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            onPressed: () => _apply(true),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: Text(t('applyReplace')),
          ),
        ],
      ]),
    );
  }

  Widget _count(IconData icon, String text, Color c) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(children: [
              Icon(icon, color: c, size: 30),
              const SizedBox(height: 6),
              Text(text, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: c, fontSize: 15.5)),
            ]),
          ),
        ),
      );
}
