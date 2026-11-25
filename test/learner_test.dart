import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jal_stock/excel/excel_learner.dart';
import 'package:jal_stock/excel/xlsx_io.dart';
import 'package:jal_stock/models.dart';
import 'package:jal_stock/rules.dart';
import 'package:jal_stock/store.dart';

void main() {
  test('xlsx writer and reader round trip', () {
    final w = XlsxWriter()
      ..addSheet('Stock', [
        ['Item', 'Stock', 'Rate'],
        ['20 Litre Jar', 150, 40],
        ['પાણી & <box>', 12, null],
      ]);
    final sheets = XlsxReader.readAny(w.encode(), 'x.xlsx');
    expect(sheets.single.name, 'Stock');
    expect(sheets.single.rows[1][0], '20 Litre Jar');
    expect(sheets.single.rows[1][1], 150);
    expect(sheets.single.rows[2][0], 'પાણી & <box>');
  });

  test('header words in English / Gujarati / Hinglish', () {
    expect(fieldForHeader('Item Name'), Field.product);
    expect(fieldForHeader('Grahak Name'), Field.customer);
    expect(fieldForHeader('Khali Jar'), Field.empty);
    expect(fieldForHeader('Kharid Bhav'), Field.cost);
    expect(fieldForHeader('Sale Price'), Field.price);
    expect(fieldForHeader('Jar Baki'), Field.jars);
    expect(fieldForHeader('Udhar'), Field.due);
    expect(fieldForHeader('તારીખ'), Field.date);
    expect(ExcelLearner.parseType('Vechan'), EntryType.sale);
    expect(ExcelLearner.parseType('Khali Pacha'), EntryType.emptyReturn);
    expect(ExcelLearner.parseType('Leak / Damage'), EntryType.damage);
    expect(ExcelLearner.parseDate('25/11/2026'), DateTime(2026, 11, 25));
    expect(ExcelLearner.parseDate(46351), DateTime(2026, 11, 25));
  });

  test('learn sample shop Excel and apply rules', () async {
    final bytes = File('sample/Sample_Water_Shop.xlsx').readAsBytesSync();
    final st = AppStore.instance;
    final plan = ExcelLearner.learn(XlsxReader.readAny(bytes, 'Sample_Water_Shop.xlsx'), st.settings);
    expect(plan.products.length, 4);
    expect(plan.customers.length, 6); // suppliers are NOT customers
    expect(plan.entries.length, greaterThan(100));
    expect(plan.products[normKey('20 Litre Jar')]!.returnable, isTrue);

    await ExcelLearner.apply(st, plan, replace: true);
    final jar = st.productByName('20 Litre Jar')!;
    expect(st.stockOf(jar).full, 140); // matches "stock now" in the Excel
    expect(st.stockOf(jar).empty, 35);
    expect(st.stockOf(jar).minStock, greaterThan(0)); // learned from sales
    final ml500 = st.productByName('500 ml Bottle Box (24)')!;
    expect(st.stockOf(ml500).full, 9);

    // the Grahak sheet says jars "now": history must end at those numbers
    final sheetJars = XlsxReader.readAny(bytes, 'x.xlsx').firstWhere((s) => s.name == 'Grahak').rows[1][3];
    final ramesh = st.customerByName('Ramesh Tea Stall')!;
    expect(st.customerInfo(ramesh).jarsHeld, sheetJars);

    // hard rule: cannot sell more than stock
    final e = Entry(id: 'z', date: DateTime.now(), type: EntryType.sale, productId: jar.id, qty: 9999);
    expect(StockRules.hardError(st, e), 'errNotEnoughStock');
  });
}
