import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  await AppStore.instance.load();
  runApp(const JalStockApp());
}

class JalStockApp extends StatelessWidget {
  const JalStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        navigatorKey: navKey,
        title: 'JalStock',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // make text a little bigger for easy reading, but never too big
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          final scale = mq.textScaler.scale(1.0).clamp(1.0, 1.3).toDouble();
          return MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear(scale)), child: child!);
        },
        home: StoreBuilder(builder: (c, st) => st.settings.onboarded ? const HomeScreen() : const OnboardingScreen()),
    );
  }
}
