import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models.dart';

class AppColors {
  static const deep = Color(0xFF0A3D62);
  static const water = Color(0xFF0E7CC9);
  static const aqua = Color(0xFF22B8CF);
  static const bg = Color(0xFFF3F8FC);
  static const ok = Color(0xFF2E9E5B);
  static const near = Color(0xFFF2A100);
  static const low = Color(0xFFE8590C);
  static const out = Color(0xFFD62828);

  static const products = [
    Color(0xFF0E7CC9),
    Color(0xFF12A594),
    Color(0xFF7048E8),
    Color(0xFFE64980),
    Color(0xFFF08C00),
    Color(0xFF2F9E44),
    Color(0xFF1C7ED6),
    Color(0xFFAE3EC9),
  ];

  static Color product(int i) => products[i.abs() % products.length];

  static Color level(StockLevel l) => switch (l) {
        StockLevel.ok => ok,
        StockLevel.near => near,
        StockLevel.low => low,
        StockLevel.out => out,
      };
}

const waterGradient = LinearGradient(
  colors: [AppColors.deep, AppColors.water, AppColors.aqua],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.water, surface: Colors.white),
    scaffoldBackgroundColor: AppColors.bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: const Color(0xFF14213D), displayColor: const Color(0xFF14213D)),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.deep,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.blueGrey.shade100)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.blueGrey.shade100)),
      labelStyle: const TextStyle(fontSize: 17),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.water,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(62),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: .5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, contentTextStyle: TextStyle(fontSize: 17)),
  );
}

IconData productIcon(Product p) {
  if (p.returnable) return Icons.water_drop_rounded;
  final u = p.unit.toLowerCase();
  if (u.contains('packet') || u.contains('pouch')) return Icons.local_mall_rounded;
  if (u.contains('bottle')) return Icons.local_drink_rounded;
  return Icons.inventory_2_rounded;
}

final _money = NumberFormat.decimalPattern('en_IN');
String money(num v) => _money.format(v.round());
String fmtDate(DateTime d) => DateFormat('d MMM yyyy, h:mm a').format(d);
String fmtDay(DateTime d) => DateFormat('d MMM yyyy').format(d);
