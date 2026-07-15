import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/pro_service.dart';
import 'screens/home_screen.dart';
import 'screens/pro_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final proService = ProService();
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
