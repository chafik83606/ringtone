import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:ringtone_set_plus/ringtone_set_plus.dart';

enum RingtoneType { ringtone, notification, alarm }

class RingtoneService {
  /// Définit [filePath] comme sonnerie du type choisi.
  /// Retourne true si succès.
  Future<bool> setRingtone({
    required String filePath,
    required RingtoneType type,
  }) async {
    if (!Platform.isAndroid) {
      debugPrint('Définition sonnerie non supportée sur iOS.');
      return false;
    }

    try {
      switch (type) {
        case RingtoneType.ringtone:
          await RingtoneSet.setRingtoneFromFile(File(filePath));
          break;
        case RingtoneType.notification:
          await RingtoneSet.setNotificationFromFile(File(filePath));
          break;
        case RingtoneType.alarm:
          await RingtoneSet.setAlarmFromFile(File(filePath));
          break;
      }
      return true;
    } catch (e) {
      debugPrint('Erreur définir sonnerie ($type) : $e');
      return false;
    }
  }

  /// Applique [filePath] à plusieurs types (sonnerie, notification, alarme).
  /// Retourne les types appliqués avec succès.
  Future<List<RingtoneType>> setRingtoneForTypes({
    required String filePath,
    required Set<RingtoneType> types,
  }) async {
    final applied = <RingtoneType>[];
    for (final type in types) {
      final ok = await setRingtone(filePath: filePath, type: type);
      if (ok) applied.add(type);
    }
    return applied;
  }
}
