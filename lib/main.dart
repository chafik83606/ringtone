import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/pro_service.dart';
import 'screens/home_screen.dart';
import 'screens/pro_screen.dart';

Future<void> _configureAudioSession() async {
  if (!Platform.isIOS && !Platform.isAndroid) return;

  await AudioPlayer.global.setAudioContext(
    AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {
          AVAudioSessionOptions.mixWithOthers,
          AVAudioSessionOptions.defaultToSpeaker,
        },
      ),
      android: const AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
      ),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _configureAudioSession();

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
