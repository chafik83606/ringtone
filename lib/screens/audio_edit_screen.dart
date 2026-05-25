import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/pro_service.dart';
import '../services/audio_service.dart';
import '../services/ad_service.dart';
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
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _waveController = PlayerController();
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    final isPro = context.read<ProService>().isPro;
    if (isPro) return;
    final ad = await context.read<AdService>().loadBanner();
    if (mounted) setState(() => _bannerAd = ad);
  }

  @override
  void dispose() {
    _player.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    // Permission lecture audio
    final status = await Permission.audio.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Permission audio refusée')));
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    await _waveController.preparePlayer(
      path: path,
      shouldExtractWaveform: true,
      noOfSamples: 150,
    );

    final dur = _waveController.maxDuration / 1000.0;
    setState(() {
      _importedPath = path;
      _totalDuration = dur;
      _startSec = 0;
      _endSec = dur;
    });
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
    final adService = context.read<AdService>();
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
      if (outPath == null) throw Exception('Découpage échoué');

      if (!proService.isPro) {
        adService.showInterstitial();
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
      bottomNavigationBar: _bannerAd != null && !isPro
          ? SizedBox(height: 50, child: AdWidget(ad: _bannerAd!))
          : null,
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
              _SliderRow(
                label: 'Début',
                value: _startSec,
                min: 0,
                max: _totalDuration,
                onChanged: (v) => setState(() {
                  _startSec = v;
                  if (_startSec >= _endSec) _endSec = _startSec + 1;
                }),
              ),
              // Slider fin
              _SliderRow(
                label: 'Fin',
                value: _endSec,
                min: 0,
                max: _totalDuration,
                onChanged: (v) => setState(() {
                  _endSec = v;
                  if (_endSec <= _startSec) _startSec = _endSec - 1;
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
