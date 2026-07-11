import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

enum SynthInstrument { piano, sine, bell }

class AudioService {
  /// Découpe [inputPath] entre [startSec] et [endSec].
  /// Si [fadeIn]/[fadeOut] sont > 0 (pro), applique un fondu.
  /// Retourne le chemin du fichier résultat ou null si erreur.
  Future<String?> trimAudio({
    required String inputPath,
    required double startSec,
    required double endSec,
    double fadeInSec = 0,
    double fadeOutSec = 0,
    int bitrate = 96, // 96 = gratuit, 320 = pro
  }) async {
    final source = File(inputPath);
    if (!await source.exists()) {
      debugPrint('Trim input missing: $inputPath');
      return null;
    }

    final workDir = await getTemporaryDirectory();
    final ext = p.extension(inputPath);
    final safeExt = ext.isNotEmpty ? ext : '.mp3';
    final safeInput = p.join(
      workDir.path,
      'input_${DateTime.now().millisecondsSinceEpoch}$safeExt',
    );
    await source.copy(safeInput);

    final outPath = p.join(
      workDir.path,
      'trim_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );
    final duration = endSec - startSec;

    final args = <String>[
      '-y',
      '-i',
      safeInput,
      '-ss',
      startSec.toStringAsFixed(3),
      '-t',
      duration.toStringAsFixed(3),
    ];

    if (fadeInSec > 0 || fadeOutSec > 0) {
      final fadeParts = <String>[];
      if (fadeInSec > 0) fadeParts.add('afade=t=in:st=0:d=$fadeInSec');
      if (fadeOutSec > 0) {
        final fadeStart = max(0.0, duration - fadeOutSec);
        fadeParts.add('afade=t=out:st=$fadeStart:d=$fadeOutSec');
      }
      args.addAll(['-af', fadeParts.join(',')]);
    }

    args.addAll(['-c:a', 'libmp3lame', '-b:a', '${bitrate}k', outPath]);

    try {
      final session = await FFmpegKit.executeWithArguments(args);
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc) && await File(outPath).exists()) {
        return outPath;
      }
      final logs = await session.getAllLogsAsString();
      debugPrint('FFmpeg trim error: $logs');
      return null;
    } on MissingPluginException catch (e) {
      debugPrint('FFmpeg plugin unavailable: $e');
      return null;
    } catch (e) {
      debugPrint('FFmpeg trim exception: $e');
      return null;
    } finally {
      if (await File(safeInput).exists()) {
        await File(safeInput).delete();
      }
    }
  }

  /// Génère un fichier WAV à partir d'une séquence de fréquences (piano virtuel).
  /// Chaque [notes] est une liste de (fréquence Hz, durée ms).
  Future<String?> synthesizePiano({
    required List<({double freq, int durationMs})> notes,
    SynthInstrument instrument = SynthInstrument.piano,
    int sampleRate = 44100,
    double amplitude = 0.5,
    int bitrate = 96,
  }) async {
    if (notes.isEmpty) return null;

    final dir = await getApplicationDocumentsDirectory();
    final wavPath = p.join(
      dir.path,
      'piano_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    final outPath = p.join(
      dir.path,
      'piano_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );

    final wavBytes = _buildPianoWave(
      notes: notes,
      instrument: instrument,
      sampleRate: sampleRate,
      amplitude: amplitude,
    );
    await File(wavPath).writeAsBytes(wavBytes, flush: true);

    final cmd =
        '-y -i "$wavPath" -codec:a libmp3lame -b:a ${bitrate}k "$outPath"';

    try {
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) {
        await deleteFile(wavPath);
        return outPath;
      }
      final logs = await session.getAllLogsAsString();
      debugPrint('FFmpeg synth error: $logs');
      return wavPath;
    } on MissingPluginException catch (e) {
      debugPrint('FFmpeg plugin unavailable, fallback to WAV: $e');
      return wavPath;
    } catch (e) {
      debugPrint('FFmpeg synth exception, fallback to WAV: $e');
      return wavPath;
    }
  }

  /// Génère les bytes WAV d'une composition pour une préécoute sans export.
  Uint8List buildCompositionPreviewWav({
    required List<({double freq, int durationMs})> notes,
    SynthInstrument instrument = SynthInstrument.piano,
    int sampleRate = 44100,
    double amplitude = 0.5,
  }) {
    return _buildPianoWave(
      notes: notes,
      instrument: instrument,
      sampleRate: sampleRate,
      amplitude: amplitude,
    );
  }

  /// Convertit [inputPath] en sonnerie iOS (.m4r, AAC, max [maxSeconds]s).
  Future<String?> convertToIosRingtone({
    required String inputPath,
    int maxSeconds = 30,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final outPath = p.join(
      dir.path,
      'ringtone_${DateTime.now().millisecondsSinceEpoch}.m4r',
    );

    final cmd =
        '-y -i "$inputPath" -t $maxSeconds -c:a aac -b:a 128k -f ipod "$outPath"';

    try {
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) {
        return outPath;
      }
      final logs = await session.getAllLogsAsString();
      debugPrint('FFmpeg m4r error: $logs');
      return null;
    } on MissingPluginException catch (e) {
      debugPrint('FFmpeg plugin unavailable for m4r: $e');
      return null;
    }
  }

  /// Supprime un fichier temporaire.
  Future<void> deleteFile(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  Uint8List _buildPianoWave({
    required List<({double freq, int durationMs})> notes,
    required SynthInstrument instrument,
    required int sampleRate,
    required double amplitude,
  }) {
    final pcm = BytesBuilder(copy: false);

    for (final note in notes) {
      final sampleCount = max(1, note.durationMs * sampleRate ~/ 1000);
      final releaseSamples = max(1, (sampleCount * 0.16).round());
      final attackSamples = max(1, (sampleCount * 0.02).round());
      final decaySamples = max(1, (sampleCount * 0.10).round());

      for (int index = 0; index < sampleCount; index++) {
        final time = index / sampleRate;
        final normalized = index / sampleCount;
        final envelope = _adsrEnvelope(
          index: index,
          sampleCount: sampleCount,
          attackSamples: attackSamples,
          decaySamples: decaySamples,
          releaseSamples: releaseSamples,
        );
        final decay = exp(-3.2 * normalized);
        final value =
            _instrumentSample(instrument, note.freq, time) *
            envelope *
            decay *
            amplitude;
        final clamped = value.clamp(-1.0, 1.0);
        final sample = (clamped * 32767).round();
        final data = ByteData(2)..setInt16(0, sample, Endian.little);
        pcm.add(data.buffer.asUint8List());
      }

      final gapSamples = max(1, sampleRate ~/ 80);
      for (int index = 0; index < gapSamples; index++) {
        final silence = ByteData(2)..setInt16(0, 0, Endian.little);
        pcm.add(silence.buffer.asUint8List());
      }
    }

    final pcmBytes = pcm.toBytes();
    return _wrapAsWav(
      pcmBytes: pcmBytes,
      sampleRate: sampleRate,
      channels: 1,
      bitsPerSample: 16,
    );
  }

  Uint8List buildSingleNotePreviewWav({
    required double freq,
    required int durationMs,
    required SynthInstrument instrument,
    int sampleRate = 44100,
    double amplitude = 0.45,
  }) {
    return _buildPianoWave(
      notes: [(freq: freq, durationMs: durationMs)],
      instrument: instrument,
      sampleRate: sampleRate,
      amplitude: amplitude,
    );
  }

  double _adsrEnvelope({
    required int index,
    required int sampleCount,
    required int attackSamples,
    required int decaySamples,
    required int releaseSamples,
  }) {
    if (index < attackSamples) {
      return index / attackSamples;
    }

    if (index < attackSamples + decaySamples) {
      final decayProgress = (index - attackSamples) / decaySamples;
      return 1.0 - (0.28 * decayProgress);
    }

    final releaseStart = sampleCount - releaseSamples;
    if (index >= releaseStart) {
      final releaseProgress = (index - releaseStart) / releaseSamples;
      return 0.72 * (1.0 - releaseProgress);
    }

    return 0.72;
  }

  double _pianoLikeSample(double frequency, double time) {
    const double pi2 = pi * 2;
    final fundamental = sin(pi2 * frequency * time);
    final second = 0.55 * sin(pi2 * frequency * 2 * time);
    final third = 0.22 * sin(pi2 * frequency * 3 * time);
    final fourth = 0.09 * sin(pi2 * frequency * 4 * time);
    final fifth = 0.04 * sin(pi2 * frequency * 5 * time);
    final body = 0.08 * sin(pi2 * frequency * 0.5 * time);
    return (fundamental + second + third + fourth + fifth + body) / 1.98;
  }

  double _sineSample(double frequency, double time) {
    const double pi2 = pi * 2;
    return sin(pi2 * frequency * time);
  }

  double _bellSample(double frequency, double time) {
    const double pi2 = pi * 2;
    final carrier = sin(pi2 * frequency * time);
    final mod = sin(pi2 * frequency * 2.7 * time);
    final overtone = sin(pi2 * frequency * 5.1 * time);
    final shimmer = sin(pi2 * frequency * 8.3 * time);
    return (0.6 * carrier + 0.25 * mod + 0.1 * overtone + 0.05 * shimmer);
  }

  double _instrumentSample(
    SynthInstrument instrument,
    double frequency,
    double time,
  ) {
    switch (instrument) {
      case SynthInstrument.piano:
        return _pianoLikeSample(frequency, time);
      case SynthInstrument.sine:
        return _sineSample(frequency, time);
      case SynthInstrument.bell:
        return _bellSample(frequency, time);
    }
  }

  Uint8List _wrapAsWav({
    required Uint8List pcmBytes,
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
  }) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final fileSize = 44 + pcmBytes.length;
    final header = ByteData(44);

    void setAscii(int offset, String value) {
      for (int i = 0; i < value.length; i++) {
        header.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    setAscii(0, 'RIFF');
    header.setUint32(4, fileSize - 8, Endian.little);
    setAscii(8, 'WAVE');
    setAscii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    setAscii(36, 'data');
    header.setUint32(40, pcmBytes.length, Endian.little);

    return Uint8List.fromList([...header.buffer.asUint8List(), ...pcmBytes]);
  }
}
