import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/pro_service.dart';
import 'audio_edit_screen.dart';
import 'piano_screen.dart';
import 'pro_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isPro = context.watch<ProService>().isPro;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringtone Maker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'À propos',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          if (!isPro)
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProScreen()),
              ),
              icon: const Icon(Icons.star, color: Colors.amber),
              label: const Text('PRO', style: TextStyle(color: Colors.amber)),
            ),
          if (isPro)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.verified, color: Colors.amber),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Créez votre sonnerie',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Importez un fichier audio ou composez votre mélodie',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            if (Platform.isIOS) ...[
              const SizedBox(height: 12),
              Text(
                'Sur iPhone : export .m4r puis installation via Réglages → Sons',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            if (!isPro) ...[
              const SizedBox(height: 8),
              Text(
                'Version gratuite : extrait 20 s, 16 notes piano, publicités',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 48),
            _HomeCard(
              icon: Icons.music_note,
              title: 'Importer et découper',
              subtitle: 'Choisissez un fichier audio et extrayez un extrait',
              color: Colors.deepPurple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AudioEditScreen()),
              ),
            ),
            const SizedBox(height: 16),
            _HomeCard(
              icon: Icons.piano,
              title: 'Composer au piano',
              subtitle: 'Jouez des notes et créez votre mélodie',
              color: Colors.indigo,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PianoScreen()),
              ),
            ),
            if (!isPro) ...[
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProScreen()),
                ),
                icon: const Icon(Icons.star, color: Colors.amber),
                label: const Text('Passer à la version Pro'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
