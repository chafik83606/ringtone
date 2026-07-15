import 'dart:io';

class AppConfig {
  const AppConfig._();

  static const String monthlyProductId = String.fromEnvironment(
    'MONTHLY_PRODUCT_ID',
    defaultValue: 'ringtone_pro_monthly',
  );
  static const String annualProductId = String.fromEnvironment(
    'ANNUAL_PRODUCT_ID',
    defaultValue: 'ringtone_pro_annual',
  );
  static const String lifetimeProductId = String.fromEnvironment(
    'LIFETIME_PRODUCT_ID',
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

  static Set<String> get proProductIds => {
    monthlyProductId,
    annualProductId,
    lifetimeProductId,
  };

  static bool get hasPrivacyPolicy => privacyPolicyUrl.isNotEmpty;
}
