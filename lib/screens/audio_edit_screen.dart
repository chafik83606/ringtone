import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/pro_service.dart';
import '../services/audio_service.dart';
import 'preview_screen.dart';

class AudioEditScreen extends StatefulWidget {
  const AudioEditScreen({super.key});

  @override
  State<AudioEditScreen> createState() => _AudioEditScreenState();
}

class _AudioEditScreenState extends State<AudioEditScreen> {
  String? _importedPath;
  double _totalDuration = 0;
  double _startSec = 0;
  double _endSec = 0;
  double _fadeIn = 0;
  double _fadeOut = 0;
  bool _isProcessing = false;

  final AudioPlayer _player = AudioPlayer();
  late PlayerController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = PlayerController();
  }

  @override
  void dispose() {
    _player.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (Platform.isAndroid) {
      final status = await Permission.audio.request();
      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission audio refusée')),
        );
        return;
      }
    }

    if (!mounted) return;

    final rightsConfirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Droits sur le fichier audio'),
        content: const Text(
          'Vous devez posséder les droits d\'utilisation de ce fichier, '
          'ou disposer d\'une autorisation du titulaire.\n\n'
          'N\'importez pas de musique protégée sans autorisation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('J\'ai les droits'),
          ),
        ],
      ),
    );
    if (rightsConfirmed != true || !mounted) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg', 'mpeg', 'mp4'],
        allowMultiple: false,
        withData: Platform.isIOS,
      );
      if (result == null || result.files.isEmpty) return;

      final path = await _resolvePickedFilePath(result.files.single);
      if (path == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de lire le fichier sélectionné.'),
          ),
        );
        return;
      }

      await _waveController.preparePlayer(
        path: path,
        shouldExtractWaveform: true,
        noOfSamples: 150,
      );

      final dur = _waveController.maxDuration / 1000.0;
      if (!mounted) return;
      setState(() {
        _importedPath = path;
        _totalDuration = dur;
        _startSec = 0;
        _endSec = dur;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur à l\'import : $e')),
      );
    }
  }

  /// Sur iOS, [PlatformFile.path] est souvent null — copie vers un fichier temporaire.
  Future<String?> _resolvePickedFilePath(PlatformFile file) async {
    if (file.path != null && file.path!.isNotEmpty) {
      return file.path;
    }
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      final dir = await getTemporaryDirectory();
      final name = file.name.isNotEmpty
          ? file.name
          : 'import_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final outPath = p.join(dir.path, name);
      await File(outPath).writeAsBytes(file.bytes!);
      return outPath;
    }
    return null;
  }

  double get _trimDuration => _endSec - _startSec;

  Future<void> _preview() async {
    if (_importedPath == null) return;
    await _player.stop();
    await _player.play(
      DeviceFileSource(_importedPath!),
      position: Duration(milliseconds: (_startSec * 1000).toInt()),
    );
    // Arrêt auto à la fin de l'extrait
    Future.delayed(
      Duration(milliseconds: (_trimDuration * 1000).toInt()),
      () => _player.stop(),
    );
  }

  Future<void> _processTrim() async {
    if (_importedPath == null) return;
    final proService = context.read<ProService>();
    final navigator = Navigator.of(context);

    // Vérification limite gratuit
    if (!proService.isPro && _trimDuration > ProService.freeMaxSeconds) {
      _showProGate(
        'La version gratuite limite l\'extrait à ${ProService.freeMaxSeconds}s.',
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final svc = AudioService();
      final outPath = await svc.trimAudio(
        inputPath: _importedPath!,
        startSec: _startSec,
        endSec: _endSec,
        fadeInSec: proService.isPro ? _fadeIn : 0,
        fadeOutSec: proService.isPro ? _fadeOut : 0,
        bitrate: proService.isPro ? 320 : 96,
      );
      if (outPath == null) {
        throw Exception(
          'Découpage impossible. Réessayez ou importez un autre fichier audio (MP3, M4A, WAV).',
        );
      }

      if (mounted) {
        navigator.push(
          MaterialPageRoute(builder: (_) => PreviewScreen(audioPath: outPath)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showProGate(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fonctionnalité Pro'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/pro');
            },
            child: const Text('Voir Pro'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final proService = context.watch<ProService>();
    final isPro = proService.isPro;

    return Scaffold(
      appBar: AppBar(title: const Text('Édition audio')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bouton import
            FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Importer un fichier audio'),
            ),
            if (_importedPath != null) ...[
              const SizedBox(height: 8),
              Text(
                _importedPath!.split(Platform.pathSeparator).last,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 24),

            // Waveform
            if (_importedPath != null) ...[
              const Text(
                'Forme d\'onde',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              AudioFileWaveforms(
                playerController: _waveController,
                size: Size(MediaQuery.of(context).size.width - 32, 80),
                waveformType: WaveformType.fitWidth,
              ),
              const SizedBox(height: 24),

              // Slider début
              _TrimSliderRow(
                label: 'Début',
                value: _startSec,
                min: 0,
                max: _totalDuration,
                onChanged: (v) => setState(() {
                  _startSec = v;
                  if (_startSec >= _endSec - 0.25) {
                    _endSec = (_startSec + 0.25).clamp(0, _totalDuration);
                  }
                }),
              ),
              // Slider fin
              _TrimSliderRow(
                label: 'Fin',
                value: _endSec,
                min: 0,
                max: _totalDuration,
                onChanged: (v) => setState(() {
                  _endSec = v;
                  if (_endSec <= _startSec + 0.25) {
                    _startSec = (_endSec - 0.25).clamp(0, _totalDuration);
                  }
                }),
              ),

              // Info durée
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Durée extrait : ${_trimDuration.toStringAsFixed(1)}s',
                    style: TextStyle(
                      color:
                          (!isPro && _trimDuration > ProService.freeMaxSeconds)
                          ? Colors.red
                          : Colors.grey.shade700,
                    ),
                  ),
                  if (!isPro)
                    Text(
                      'Max gratuit : ${ProService.freeMaxSeconds}s',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Fondu (pro seulement)
              if (isPro) ...[
                const Divider(),
                const Text(
                  'Options Pro',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.amber,
                  ),
                ),
                _SliderRow(
                  label: 'Fondu entrée (s)',
                  value: _fadeIn,
                  min: 0,
                  max: 3,
                  onChanged: (v) => setState(() => _fadeIn = v),
                ),
                _SliderRow(
                  label: 'Fondu sortie (s)',
                  value: _fadeOut,
                  min: 0,
                  max: 3,
                  onChanged: (v) => setState(() => _fadeOut = v),
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: const Text('Fondu entrée/sortie'),
                  subtitle: const Text('Disponible en Pro'),
                  trailing: const Icon(Icons.lock, size: 18),
                  dense: true,
                ),
              ],

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _preview,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Aperçu'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isProcessing ? null : _processTrim,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.content_cut),
                      label: const Text('Découper'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 80),
              Icon(
                Icons.audio_file_outlined,
                size: 80,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              const Text(
                'Importez un fichier audio pour commencer',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrimSliderRow extends StatelessWidget {
  static const _stepSec = 0.25;

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _TrimSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  void _nudge(double delta) {
    onChanged((value + delta).clamp(min, max));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              '$label : ${value.toStringAsFixed(2)}s',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          _NudgeButton(
            icon: Icons.remove,
            onStep: () => _nudge(-_stepSec),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          _NudgeButton(
            icon: Icons.add,
            onStep: () => _nudge(_stepSec),
          ),
        ],
      ),
    );
  }
}

class _NudgeButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onStep;

  const _NudgeButton({required this.icon, required this.onStep});

  @override
  State<_NudgeButton> createState() => _NudgeButtonState();
}

class _NudgeButtonState extends State<_NudgeButton> {
  Timer? _repeatTimer;

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  void _startRepeat() {
    widget.onStep();
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => widget.onStep(),
    );
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onStep,
      onLongPressStart: (_) => _startRepeat(),
      onLongPressEnd: (_) => _stopRepeat(),
      onLongPressCancel: _stopRepeat,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(widget.icon, size: 20, color: Colors.deepPurple),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label : ${value.toStringAsFixed(1)}s',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
