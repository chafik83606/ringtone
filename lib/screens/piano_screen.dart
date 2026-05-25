import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/piano_note.dart';
import '../services/pro_service.dart';
import '../services/audio_service.dart';
import '../services/ad_service.dart';
import 'preview_screen.dart';

// Fréquences des notes (Do3 → Si4)
const Map<String, double> _noteFrequencies = {
  'C3': 130.81,
  'D3': 146.83,
  'E3': 164.81,
  'F3': 174.61,
  'G3': 196.00,
  'A3': 220.00,
  'B3': 246.94,
  'C4': 261.63,
  'D4': 293.66,
  'E4': 329.63,
  'F4': 349.23,
  'G4': 392.00,
  'A4': 440.00,
  'B4': 493.88,
  'C#3': 138.59,
  'D#3': 155.56,
  'F#3': 185.00,
  'G#3': 207.65,
  'A#3': 233.08,
  'C#4': 277.18,
  'D#4': 311.13,
  'F#4': 369.99,
  'G#4': 415.30,
  'A#4': 466.16,
};

const List<String> _whiteKeys = [
  'C3',
  'D3',
  'E3',
  'F3',
  'G3',
  'A3',
  'B3',
  'C4',
  'D4',
  'E4',
  'F4',
  'G4',
  'A4',
  'B4',
];
const List<String> _blackKeys = [
  'C#3',
  'D#3',
  '',
  'F#3',
  'G#3',
  'A#3',
  '',
  'C#4',
  'D#4',
  '',
  'F#4',
  'G#4',
  'A#4',
  '',
];

const int _defaultDurationMs = 500;

class PianoScreen extends StatefulWidget {
  const PianoScreen({super.key});

  @override
  State<PianoScreen> createState() => _PianoScreenState();
}

class _PianoScreenState extends State<PianoScreen> {
  final List<PianoNote> _sequence = [];
  final AudioService _audioService = AudioService();
  final List<AudioPlayer> _notePlayers = List.generate(
    6,
    (_) => AudioPlayer()..setReleaseMode(ReleaseMode.stop),
  );
  final AudioPlayer _compositionPlayer = AudioPlayer();
  int _playerCursor = 0;
  bool _isProcessing = false;
  bool _isPreviewing = false;
  SynthInstrument _selectedInstrument = SynthInstrument.piano;

  @override
  void dispose() {
    _compositionPlayer.dispose();
    for (final player in _notePlayers) {
      player.dispose();
    }
    super.dispose();
  }

  SynthInstrument _effectiveInstrument(bool isPro) {
    if (!isPro && _selectedInstrument != SynthInstrument.piano) {
      return SynthInstrument.piano;
    }
    return _selectedInstrument;
  }

  Future<void> _playNote(String name) async {
    final freq = _noteFrequencies[name];
    if (freq == null) return;

    final isPro = context.read<ProService>().isPro;
    final bytes = _audioService.buildSingleNotePreviewWav(
      freq: freq,
      durationMs: 220,
      instrument: _effectiveInstrument(isPro),
    );
    final player = _notePlayers[_playerCursor % _notePlayers.length];
    _playerCursor++;
    await player.play(BytesSource(bytes));

    _addNote(name, freq);
  }

  void _addNote(String name, double freq) {
    final proService = context.read<ProService>();
    final limit = proService.isPro
        ? proService.pianoRows * proService.pianoCols
        : ProService.freePianoRows * ProService.freePianoCols;

    if (_sequence.length >= limit) {
      if (!proService.isPro) {
        _showProGate('La version gratuite limite la séquence à $limit notes.');
      }
      return;
    }
    setState(() {
      _sequence.add(
        PianoNote(name: name, frequency: freq, durationMs: _defaultDurationMs),
      );
    });
  }

  void _removeNote(int index) {
    setState(() => _sequence.removeAt(index));
  }

  Future<void> _previewComposition() async {
    if (_sequence.isEmpty || _isProcessing) return;
    final isPro = context.read<ProService>().isPro;
    setState(() => _isPreviewing = true);
    try {
      await _compositionPlayer.stop();
      final notes = _sequence
          .map((n) => (freq: n.frequency, durationMs: n.durationMs))
          .toList();
      final bytes = _audioService.buildCompositionPreviewWav(
        notes: notes,
        instrument: _effectiveInstrument(isPro),
      );
      await _compositionPlayer.play(BytesSource(bytes));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de préécoute : $e')));
      }
    } finally {
      if (mounted) setState(() => _isPreviewing = false);
    }
  }

  Future<void> _exportComposition() async {
    if (_sequence.isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      final isPro = context.read<ProService>().isPro;
      final adService = context.read<AdService>();
      final navigator = Navigator.of(context);
      final notes = _sequence
          .map((n) => (freq: n.frequency, durationMs: n.durationMs))
          .toList();
      final outPath = await _audioService.synthesizePiano(
        notes: notes,
        instrument: _effectiveInstrument(isPro),
        bitrate: isPro ? 320 : 96,
      );
      if (outPath == null) throw Exception('Export échoué');

      if (!isPro) {
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
    final isPro = context.watch<ProService>().isPro;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Piano virtuel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Effacer tout',
            onPressed: () => setState(() => _sequence.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  _InstrumentChip(
                    label: 'Piano',
                    selected: _selectedInstrument == SynthInstrument.piano,
                    onTap: () => setState(
                      () => _selectedInstrument = SynthInstrument.piano,
                    ),
                  ),
                  _InstrumentChip(
                    label: 'Cloche',
                    selected: _selectedInstrument == SynthInstrument.bell,
                    locked: !isPro,
                    onTap: () {
                      if (!isPro) {
                        _showProGate(
                          'Les instruments supplémentaires sont réservés à Pro.',
                        );
                        return;
                      }
                      setState(
                        () => _selectedInstrument = SynthInstrument.bell,
                      );
                    },
                  ),
                  _InstrumentChip(
                    label: 'Sinus',
                    selected: _selectedInstrument == SynthInstrument.sine,
                    locked: !isPro,
                    onTap: () {
                      if (!isPro) {
                        _showProGate(
                          'Les instruments supplémentaires sont réservés à Pro.',
                        );
                        return;
                      }
                      setState(
                        () => _selectedInstrument = SynthInstrument.sine,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Séquence de notes enregistrées
          if (_sequence.isNotEmpty)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _sequence.length,
                separatorBuilder: (context, index) => const SizedBox(width: 4),
                itemBuilder: (context, i) {
                  final note = _sequence[i];
                  return GestureDetector(
                    onLongPress: () => _removeNote(i),
                    child: Chip(
                      label: Text(
                        note.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => _removeNote(i),
                      backgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
                    ),
                  );
                },
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Appuyez sur les touches pour composer votre mélodie',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),

          if (!isPro) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(
                value: _sequence.isEmpty
                    ? 0
                    : _sequence.length /
                          (ProService.freePianoRows * ProService.freePianoCols),
                backgroundColor: Colors.grey.shade200,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Text(
                '${_sequence.length}/${ProService.freePianoRows * ProService.freePianoCols} notes (gratuit)',
                style: const TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ),
          ],

          const Divider(height: 1),

          // Clavier piano
          Expanded(child: _PianoKeyboard(onNotePressed: _playNote)),

          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sequence.isEmpty || _isProcessing
                            ? null
                            : _previewComposition,
                        icon: _isPreviewing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: const Text('Préécouter'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _sequence.isEmpty || _isProcessing
                            ? null
                            : _exportComposition,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_alt),
                        label: const Text('Exporter'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstrumentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _InstrumentChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (locked) ...[
            const SizedBox(width: 6),
            const Icon(Icons.lock, size: 14),
          ],
        ],
      ),
      onSelected: (_) => onTap(),
    );
  }
}

class _PianoKeyboard extends StatelessWidget {
  final ValueChanged<String> onNotePressed;

  const _PianoKeyboard({required this.onNotePressed});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final whiteKeyWidth = constraints.maxWidth / _whiteKeys.length;
        final whiteKeyHeight = constraints.maxHeight;
        final blackKeyWidth = whiteKeyWidth * 0.6;
        final blackKeyHeight = whiteKeyHeight * 0.6;

        return Stack(
          children: [
            // Touches blanches
            Row(
              children: _whiteKeys.map((name) {
                return GestureDetector(
                  onTapDown: (_) => onNotePressed(name),
                  child: Container(
                    width: whiteKeyWidth,
                    height: whiteKeyHeight,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // Touches noires
            ...List.generate(_blackKeys.length, (i) {
              final name = _blackKeys[i];
              if (name.isEmpty) return const SizedBox();
              final left =
                  whiteKeyWidth * i + whiteKeyWidth - blackKeyWidth / 2;
              return Positioned(
                left: left,
                top: 0,
                child: GestureDetector(
                  onTapDown: (_) => onNotePressed(name),
                  child: Container(
                    width: blackKeyWidth,
                    height: blackKeyHeight,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 7,
                        color: Colors.white60,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
