import 'dart:io';

class AppConfig {
  const AppConfig._();

  static const String revenueCatAndroidApiKey = String.fromEnvironment(
    'RC_ANDROID_API_KEY',
  );
  static const String revenueCatIosApiKey = String.fromEnvironment(
    'RC_IOS_API_KEY',
  );
  static const String revenueCatEntitlementId = String.fromEnvironment(
    'RC_ENTITLEMENT_ID',
    defaultValue: 'pro',
  );
  static const String revenueCatOfferingId = String.fromEnvironment(
    'RC_OFFERING_ID',
    defaultValue: 'default',
  );
  static const String monthlyProductId = String.fromEnvironment(
    'RC_MONTHLY_PRODUCT_ID',
  );
  static const String lifetimeProductId = String.fromEnvironment(
    'RC_LIFETIME_PRODUCT_ID',
  );

  static const String androidBannerAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const String androidInterstitialAdUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );
  static const String iosBannerAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );
  static const String iosInterstitialAdUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );

  static bool get isIos => Platform.isIOS;
  static bool get isAndroid => Platform.isAndroid;

  static String get revenueCatApiKey =>
      isIos ? revenueCatIosApiKey : revenueCatAndroidApiKey;

  static bool get purchasesConfigured => revenueCatApiKey.isNotEmpty;

  static String get bannerAdUnitId =>
      isIos ? iosBannerAdUnitId : androidBannerAdUnitId;

  static String get interstitialAdUnitId =>
      isIos ? iosInterstitialAdUnitId : androidInterstitialAdUnitId;
}
