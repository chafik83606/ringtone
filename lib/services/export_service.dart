import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'audio_service.dart';

class ExportService {
  final AudioService _audioService = AudioService();

  /// Exporte vers Musique/RingtoneMaker (Android).
  Future<ExportResult> exportToMusicFolder(String sourcePath) async {
    if (!Platform.isAndroid) {
      return ExportResult.failure('Disponible uniquement sur Android.');
    }

    try {
      final musicDir = Directory('/storage/emulated/0/Music/RingtoneMaker');
      if (!await musicDir.exists()) await musicDir.create(recursive: true);
      final extension = p.extension(sourcePath).isEmpty
          ? '.wav'
          : p.extension(sourcePath);
      final fileName =
          'ringtone_${DateTime.now().millisecondsSinceEpoch}$extension';
      final dest = '${musicDir.path}/$fileName';
      await File(sourcePath).copy(dest);
      return ExportResult.success(
        'Enregistré dans Musique/RingtoneMaker : $fileName',
      );
    } catch (e) {
      debugPrint('Export Android échoué : $e');
      return ExportResult.failure(
        'Export limité par Android. Fichier local : $sourcePath',
      );
    }
  }

  /// Convertit en .m4r et ouvre la feuille de partage iOS.
  Future<ExportResult> shareIosRingtone(String sourcePath) async {
    if (!Platform.isIOS) {
      return ExportResult.failure('Disponible uniquement sur iOS.');
    }

    final m4rPath = await _audioService.convertToIosRingtone(
      inputPath: sourcePath,
    );
    if (m4rPath == null) {
      return ExportResult.failure('Conversion en sonnerie iOS échouée.');
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(m4rPath, mimeType: 'audio/x-m4a', name: p.basename(m4rPath)),
          ],
          subject: 'Sonnerie Ringtone Maker',
        ),
      );
      return ExportResult.success(
        'Fichier .m4r prêt. Enregistrez-le via Fichiers, puis '
        'Réglages → Sons et vibrations → Sonnerie.',
      );
    } catch (e) {
      debugPrint('Partage iOS échoué : $e');
      return ExportResult.failure('Partage impossible : $e');
    }
  }
}

class ExportResult {
  final bool ok;
  final String message;

  const ExportResult._(this.ok, this.message);

  factory ExportResult.success(String message) => ExportResult._(true, message);
  factory ExportResult.failure(String message) =>
      ExportResult._(false, message);
}
