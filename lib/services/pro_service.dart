import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/app_config.dart';

const String _kProKey = 'is_pro';
const String kEntitlementId = 'pro'; // à créer dans RevenueCat

class ProService extends ChangeNotifier {
  bool _isPro = false;
  bool _isLoading = false;
  String? _lastError;

  bool get isPro => _isPro;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get purchasesConfigured => AppConfig.purchasesConfigured;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool(_kProKey) ?? false;
    notifyListeners();

    if (AppConfig.purchasesConfigured) {
      await _checkEntitlement();
    }
  }

  Future<void> _checkEntitlement() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlement =
          customerInfo.entitlements.all[AppConfig.revenueCatEntitlementId];
      _isPro = entitlement?.isActive ?? false;
      _lastError = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kProKey, _isPro);
      notifyListeners();
    } catch (e) {
      _lastError = 'Verification RevenueCat indisponible: $e';
      // pas de connexion → on garde la valeur locale
    }
  }

  Future<bool> purchasePro({bool subscription = false}) async {
    if (!AppConfig.purchasesConfigured) {
      _lastError =
          'Configurez RC_ANDROID_API_KEY / RC_IOS_API_KEY avant l\'achat.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final offerings = await Purchases.getOfferings();
      final offering =
          offerings.all[AppConfig.revenueCatOfferingId] ?? offerings.current;
      final pkg = _selectPackage(offering, subscription);
      if (pkg == null) return false;

      final customerInfo = await Purchases.purchasePackage(pkg);
      _isPro =
          customerInfo
              .entitlements
              .all[AppConfig.revenueCatEntitlementId]
              ?.isActive ??
          false;
      _lastError = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kProKey, _isPro);
      return _isPro;
    } catch (e) {
      _lastError = 'Achat echoue: $e';
      debugPrint('Achat échoué : $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> restorePurchases() async {
    if (!AppConfig.purchasesConfigured) {
      _lastError = 'RevenueCat n\'est pas configure.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final customerInfo = await Purchases.restorePurchases();
      _isPro =
          customerInfo
              .entitlements
              .all[AppConfig.revenueCatEntitlementId]
              ?.isActive ??
          false;
      _lastError = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kProKey, _isPro);
      return _isPro;
    } catch (e) {
      _lastError = 'Restauration echouee: $e';
      debugPrint('Restauration échouée : $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Limites gratuit
  static const int freeMaxSeconds = 20;
  static const int freePianoRows = 4;
  static const int freePianoCols = 4;

  // Limites pro
  static const int proMaxSeconds = 600;
  static const int proPianoRows = 8;
  static const int proPianoCols = 16;

  int get maxTrimSeconds => _isPro ? proMaxSeconds : freeMaxSeconds;
  int get pianoRows => _isPro ? proPianoRows : freePianoRows;
  int get pianoCols => _isPro ? proPianoCols : freePianoCols;

  Package? _selectPackage(Offering? offering, bool subscription) {
    if (offering == null) {
      _lastError = 'Aucune offering RevenueCat disponible.';
      return null;
    }

    final preferredProductId = subscription
        ? AppConfig.monthlyProductId
        : AppConfig.lifetimeProductId;

    if (preferredProductId.isNotEmpty) {
      for (final package in offering.availablePackages) {
        if (package.storeProduct.identifier == preferredProductId) {
          return package;
        }
      }
    }

    final fallback = subscription ? offering.monthly : offering.lifetime;
    if (fallback != null) {
      return fallback;
    }

    _lastError = subscription
        ? 'Aucun package mensuel trouve dans l\'offering RevenueCat.'
        : 'Aucun package lifetime trouve dans l\'offering RevenueCat.';
    return null;
  }
}
