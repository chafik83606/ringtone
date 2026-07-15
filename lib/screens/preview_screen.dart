import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/export_service.dart';
import '../services/ringtone_service.dart';

const int _kIosMaxRingtoneSeconds = 30;

class PreviewScreen extends StatefulWidget {
  final String audioPath;

  const PreviewScreen({super.key, required this.audioPath});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final AudioPlayer _player = AudioPlayer();
  final RingtoneService _ringtoneService = RingtoneService();
  final ExportService _exportService = ExportService();
  bool _isPlaying = false;
  bool _isExporting = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  final Set<RingtoneType> _selectedTypes = {RingtoneType.ringtone};
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _loadDuration();
  }

  Future<void> _loadDuration() async {
    await _player.setSource(DeviceFileSource(widget.audioPath));
    final d = await _player.getDuration();
    if (d != null && mounted) setState(() => _duration = d);
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

  String _typeLabel(RingtoneType type) => switch (type) {
    RingtoneType.ringtone => 'Sonnerie',
    RingtoneType.notification => 'Notification',
    RingtoneType.alarm => 'Alarme',
  };

  String _applyButtonLabel() {
    if (_selectedTypes.length == 3) return 'Appliquer aux 3 sons';
    if (_selectedTypes.length == 1) {
      return 'Définir comme ${_typeLabel(_selectedTypes.first).toLowerCase()}';
    }
    final labels = _selectedTypes.map(_typeLabel).join(', ');
    return 'Appliquer ($labels)';
  }

  Future<void> _setAsRingtone() async {
    if (_selectedTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un type de son.')),
      );
      return;
    }

    final selectedLabels = _selectedTypes.map(_typeLabel).join(', ');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifier les sons du téléphone'),
        content: Text(
          'Cette action va modifier : $selectedLabels.\n\n'
          'Android peut vous demander une autorisation supplémentaire. '
          'Vous pourrez annuler ce changement à tout moment dans les réglages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isApplying = true);
    try {
      final applied = await _ringtoneService.setRingtoneForTypes(
        filePath: widget.audioPath,
        types: _selectedTypes,
      );
      if (!mounted) return;

      if (applied.isEmpty) {
        final openSettings = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Autorisation requise'),
            content: const Text(
              'Impossible de définir les sons. Android peut exiger '
              'l\'autorisation « Modifier les paramètres système » pour cette app.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Fermer'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ouvrir les réglages'),
              ),
            ],
          ),
        );
        if (openSettings == true) await openAppSettings();
        return;
      }

      final appliedLabels = applied.map(_typeLabel).join(', ');
      final partial = applied.length < _selectedTypes.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            partial
                ? 'Appliqué : $appliedLabels. Certains sons n\'ont pas pu être définis.'
                : 'Appliqué avec succès : $appliedLabels',
          ),
          backgroundColor: partial ? Colors.orange : Colors.green,
        ),
      );
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  void _toggleType(RingtoneType type, bool selected) {
    setState(() {
      if (selected) {
        _selectedTypes.add(type);
      } else if (_selectedTypes.length > 1) {
        _selectedTypes.remove(type);
      }
    });
  }

  void _selectAllTypes() {
    setState(() {
      _selectedTypes
        ..clear()
        ..addAll(RingtoneType.values);
    });
  }

  Future<bool> _confirmIosTruncation() async {
    if (!Platform.isIOS || _duration.inSeconds <= _kIosMaxRingtoneSeconds) {
      return true;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Limite iOS : 30 secondes'),
        content: Text(
          'Votre extrait dure ${_duration.inSeconds} s. iOS limite les '
          'sonneries à $_kIosMaxRingtoneSeconds s : seuls les '
          '$_kIosMaxRingtoneSeconds premières secondes seront exportées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exporter quand même'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _exportFile() async {
    if (!await _confirmIosTruncation()) return;

    setState(() => _isExporting = true);
    try {
      final ExportResult result;
      if (Platform.isIOS) {
        result = await _exportService.shareIosRingtone(widget.audioPath);
      } else {
        result = await _exportService.exportToMusicFolder(widget.audioPath);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.ok ? Colors.green : Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.audioPath.split(Platform.pathSeparator).last;
    final isAndroid = Platform.isAndroid;
    final isIos = Platform.isIOS;

    return Scaffold(
      appBar: AppBar(title: const Text('Aperçu & Sauvegarde')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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

            if (isAndroid) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Appliquer à :',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _selectAllTypes,
                    child: const Text('Tout sélectionner'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _selectedTypes.contains(RingtoneType.ringtone),
                onChanged: (v) =>
                    _toggleType(RingtoneType.ringtone, v ?? false),
                secondary: const Icon(Icons.phone),
                title: const Text('Sonnerie'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: _selectedTypes.contains(RingtoneType.notification),
                onChanged: (v) =>
                    _toggleType(RingtoneType.notification, v ?? false),
                secondary: const Icon(Icons.notifications),
                title: const Text('Notification'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: _selectedTypes.contains(RingtoneType.alarm),
                onChanged: (v) => _toggleType(RingtoneType.alarm, v ?? false),
                secondary: const Icon(Icons.alarm),
                title: const Text('Alarme'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isApplying ? null : _setAsRingtone,
                icon: _isApplying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ring_volume),
                label: Text(_applyButtonLabel()),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isExporting ? null : _exportFile,
                icon: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: const Text('Exporter vers Musique'),
              ),
            ],

            if (isIos && _duration.inSeconds > _kIosMaxRingtoneSeconds) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Durée : ${_duration.inSeconds} s — iOS tronquera '
                          'l\'export à $_kIosMaxRingtoneSeconds s maximum.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (isIos) ...[
              const SizedBox(height: 24),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Installation sur iPhone',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'iOS ne permet pas de définir la sonnerie directement '
                        'depuis une app. Exportez un fichier .m4r (max 30 s) '
                        'puis :',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Appuyez sur « Exporter et partager »\n'
                        '2. Enregistrez dans Fichiers\n'
                        '3. Réglages → Sons et vibrations → Sonnerie\n'
                        '   (ou synchronisez via Finder sur Mac)',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isExporting ? null : _exportFile,
                icon: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share),
                label: const Text('Exporter et partager (.m4r)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
