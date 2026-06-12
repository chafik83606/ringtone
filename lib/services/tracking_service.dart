import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';

class TrackingService {
  /// Demande ATT sur iOS avant le chargement des publicités.
  static Future<void> requestIfNeeded() async {
    if (!Platform.isIOS) return;

    try {
      var status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        status = await AppTrackingTransparency.requestTrackingAuthorization();
      }
      debugPrint('ATT status: $status');
    } catch (e) {
      debugPrint('ATT request failed: $e');
    }
  }

  static Future<bool> get allowsPersonalizedAds async {
    if (!Platform.isIOS) return true;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      return status == TrackingStatus.authorized;
    } catch (_) {
      return false;
    }
  }
}
