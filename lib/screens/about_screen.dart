import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir : $url')),
      );
    }
  }

  Future<void> _openEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConfig.supportEmail,
      query: 'subject=Ringtone Maker',
    );
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Contact : ${AppConfig.supportEmail}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = _info == null
        ? '…'
        : '${_info!.version} (${_info!.buildNumber})';

    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.music_note, size: 64, color: Colors.deepPurple),
          const SizedBox(height: 12),
          const Text(
            'Ringtone Maker',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Version $version',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Fonctionnalités'),
          const _Bullet(
            'Importez un fichier audio (MP3, WAV…) et découpez un extrait.',
          ),
          const _Bullet(
            'Composez une mélodie au piano virtuel et exportez-la.',
          ),
          if (Platform.isAndroid)
            const _Bullet(
              'Définissez directement la sonnerie, la notification ou l\'alarme.',
            ),
          if (Platform.isIOS)
            const _Bullet(
              'Exportez un fichier .m4r (max 30 s) et installez-le via '
              'Réglages → Sons et vibrations → Sonnerie.',
            ),
          const SizedBox(height: 16),
          const _SectionTitle('Version gratuite'),
          const _Bullet('Extrait jusqu\'à 20 secondes.'),
          const _Bullet('16 notes maximum au piano.'),
          const _Bullet('Qualité 96 kbps, publicités affichées.'),
          const SizedBox(height: 16),
          const _SectionTitle('Version Pro'),
          const _Bullet('Extrait jusqu\'à 10 minutes, 320 kbps.'),
          const _Bullet('Fondu entrée/sortie, instruments Cloche et Sinus.'),
          const _Bullet('Sans publicités.'),
          const SizedBox(height: 16),
          const _SectionTitle('Droits d\'auteur'),
          const _Bullet(
            'Utilisez uniquement des fichiers dont vous possédez les droits '
            'ou une autorisation du titulaire.',
          ),
          const SizedBox(height: 24),
          if (AppConfig.hasPrivacyPolicy)
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Politique de confidentialité'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _openUrl(AppConfig.privacyPolicyUrl),
            )
          else
            ListTile(
              leading: Icon(Icons.privacy_tip_outlined, color: Colors.orange.shade700),
              title: const Text('Politique de confidentialité'),
              subtitle: Text(AppConfig.privacyPolicyUrl),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _openUrl(AppConfig.privacyPolicyUrl),
            ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Contact'),
            subtitle: Text(AppConfig.supportEmail),
            onTap: _openEmail,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(fontSize: 14)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
