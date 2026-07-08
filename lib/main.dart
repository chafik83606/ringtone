import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'config/app_config.dart';
import 'services/pro_service.dart';
import 'screens/home_screen.dart';
import 'screens/pro_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final proService = ProService();

  if (AppConfig.purchasesConfigured) {
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
    await Purchases.configure(
      PurchasesConfiguration(AppConfig.revenueCatApiKey),
    );
  }

  await proService.init();
  runApp(
    ChangeNotifierProvider.value(
      value: proService,
      child: const RingtoneMakerApp(),
    ),
  );
}

class RingtoneMakerApp extends StatelessWidget {
  const RingtoneMakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ringtone Maker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const HomeScreen(),
      routes: {'/pro': (_) => const ProScreen()},
    );
  }
}
