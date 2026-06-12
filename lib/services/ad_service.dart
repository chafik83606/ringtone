import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/app_config.dart';
import 'tracking_service.dart';

class AdService {
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isBannerLoaded = false;
  bool _isInterstitialLoaded = false;

  bool get isBannerLoaded => _isBannerLoaded;

  Future<void> initialize() async {
    if (Platform.isIOS) {
      await TrackingService.requestIfNeeded();
    }
    await MobileAds.instance.initialize();
    if (AppConfig.usesTestAdIds) {
      debugPrint('AdMob : IDs de test actifs — remplacez-les avant publication.');
    }
  }

  Future<AdRequest> _buildAdRequest() async {
    if (Platform.isIOS) {
      final personalized = await TrackingService.allowsPersonalizedAds;
      return AdRequest(nonPersonalizedAds: !personalized);
    }
    return const AdRequest();
  }

  /// Charge une bannière publicitaire.
  Future<BannerAd?> loadBanner() async {
    final request = await _buildAdRequest();
    final ad = BannerAd(
      adUnitId: AppConfig.bannerAdUnitId,
      size: AdSize.banner,
      request: request,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isBannerLoaded = true;
          _bannerAd = ad as BannerAd;
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed: $error');
          ad.dispose();
        },
      ),
    );
    await ad.load();
    _bannerAd = ad;
    return ad;
  }

  BannerAd? get bannerAd => _bannerAd;

  Future<void> loadInterstitial() async {
    final request = await _buildAdRequest();
    await InterstitialAd.load(
      adUnitId: AppConfig.interstitialAdUnitId,
      request: request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoaded = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed: $error');
          _isInterstitialLoaded = false;
        },
      ),
    );
  }

  void showInterstitial() {
    if (_isInterstitialLoaded && _interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      _isInterstitialLoaded = false;
    }
  }

  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
  }
}
