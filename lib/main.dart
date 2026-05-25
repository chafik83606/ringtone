import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'config/app_config.dart';
import 'services/pro_service.dart';
import 'services/ad_service.dart';
import 'screens/home_screen.dart';
import 'screens/pro_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();

  if (AppConfig.purchasesConfigured) {
    await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(
      PurchasesConfiguration(AppConfig.revenueCatApiKey),
    );
  }

  final proService = ProService();
  await proService.init();
  final adService = AdService();
  await adService.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: proService),
        Provider.value(value: adService),
      ],
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
