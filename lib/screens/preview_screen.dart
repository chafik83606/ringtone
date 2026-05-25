import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import '../services/ringtone_service.dart';

class PreviewScreen extends StatefulWidget {
  final String audioPath;

  const PreviewScreen({super.key, required this.audioPath});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final AudioPlayer _player = AudioPlayer();
  final RingtoneService _ringtoneService = RingtoneService();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  RingtoneType _selectedType = RingtoneType.ringtone;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(DeviceFileSource(widget.audioPath));
    }
  }

  Future<void> _setAsRingtone() async {
    if (!Platform.isAndroid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La definition comme sonnerie systeme sera activee plus tard. Pour l\'instant, cette action est reservee a Android.',
          ),
        ),
      );
      return;
    }

    final ok = await _ringtoneService.setRingtone(
      filePath: widget.audioPath,
      type: _selectedType,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Sonnerie définie avec succès !'
              : 'Échec de la définition de la sonnerie',
        ),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _exportFile() async {
    if (!Platform.isAndroid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le flux d\'export iOS n\'est pas encore active. Gardez ce garde-fou jusqu\'a l\'ajout de la cible iOS.',
          ),
        ),
      );
      return;
    }

    final permission = await Permission.manageExternalStorage.request();
    if (!permission.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Permission de stockage requise pour enregistrer dans Musique.',
          ),
        ),
      );
      return;
    }

    final musicDir = Directory('/storage/emulated/0/Music/RingtoneMaker');
    if (!await musicDir.exists()) await musicDir.create(recursive: true);
    final extension = p.extension(widget.audioPath).isEmpty
        ? '.wav'
        : p.extension(widget.audioPath);
    final fileName =
        'ringtone_${DateTime.now().millisecondsSinceEpoch}$extension';
    final dest = '${musicDir.path}/$fileName';
    await File(widget.audioPath).copy(dest);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Enregistré dans Musique/RingtoneMaker : $fileName'),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.audioPath.split('/').last;
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(title: const Text('Aperçu & Sauvegarde')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Player card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.music_note,
                      size: 48,
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: _position.inMilliseconds
                          .clamp(0, _duration.inMilliseconds)
                          .toDouble(),
                      max: _duration.inMilliseconds.toDouble().clamp(
                        1,
                        double.infinity,
                      ),
                      onChanged: (v) {
                        _player.seek(Duration(milliseconds: v.toInt()));
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    IconButton.filled(
                      onPressed: _togglePlay,
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      iconSize: 32,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Définir comme :',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<RingtoneType>(
              segments: const [
                ButtonSegment(
                  value: RingtoneType.ringtone,
                  label: Text('Sonnerie'),
                  icon: Icon(Icons.phone),
                ),
                ButtonSegment(
                  value: RingtoneType.notification,
                  label: Text('Notif.'),
                  icon: Icon(Icons.notifications),
                ),
                ButtonSegment(
                  value: RingtoneType.alarm,
                  label: Text('Alarme'),
                  icon: Icon(Icons.alarm),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (s) =>
                  setState(() => _selectedType = s.first),
            ),

            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: isAndroid ? _setAsRingtone : null,
              icon: const Icon(Icons.ring_volume),
              label: Text(
                isAndroid
                    ? 'Définir comme sonnerie'
                    : 'Sonnerie système: Android uniquement',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _exportFile,
              icon: const Icon(Icons.download),
              label: const Text('Exporter vers Musique'),
            ),
          ],
        ),
      ),
    );
  }
}
