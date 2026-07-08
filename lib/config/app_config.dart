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
    defaultValue: 'ringtone_pro_monthly',
  );
  static const String annualProductId = String.fromEnvironment(
    'RC_ANNUAL_PRODUCT_ID',
    defaultValue: 'ringtone_pro_annual',
  );
  static const String lifetimeProductId = String.fromEnvironment(
    'RC_LIFETIME_PRODUCT_ID',
    defaultValue: 'ringtone_pro_lifetime',
  );

  /// URL publique de la politique de confidentialité (GitHub Pages).
  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://chafik83606.github.io/ringtone/privacy.html',
  );

  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'chakif.bakri@gmail.com',
  );

  static bool get isIos => Platform.isIOS;
  static bool get isAndroid => Platform.isAndroid;

  static String get revenueCatApiKey =>
      isIos ? revenueCatIosApiKey : revenueCatAndroidApiKey;

  static bool get purchasesConfigured => revenueCatApiKey.isNotEmpty;

  static bool get hasPrivacyPolicy => privacyPolicyUrl.isNotEmpty;
}
