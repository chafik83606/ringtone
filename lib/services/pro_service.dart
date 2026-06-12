import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/app_config.dart';

const String _kProKey = 'is_pro';

enum ProPlan { monthly, annual, lifetime }

class ProService extends ChangeNotifier {
  bool _isPro = false;
  bool _isLoading = false;
  String? _lastError;
  String _monthlyPriceLabel = '1,99 €/mois';
  String _annualPriceLabel = '9,99 €/an';
  String _lifetimePriceLabel = '39,90 €';

  bool get isPro => _isPro;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get purchasesConfigured => AppConfig.purchasesConfigured;
  String get monthlyPriceLabel => _monthlyPriceLabel;
  String get annualPriceLabel => _annualPriceLabel;
  String get lifetimePriceLabel => _lifetimePriceLabel;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool(_kProKey) ?? false;
    notifyListeners();

    if (AppConfig.purchasesConfigured) {
      await _checkEntitlement();
      await _loadStorePrices();
    }
  }

  Future<void> _loadStorePrices() async {
    try {
      final offerings = await Purchases.getOfferings();
      final offering =
          offerings.all[AppConfig.revenueCatOfferingId] ?? offerings.current;
      if (offering == null) return;

      final monthly = _selectPackageFromOffering(offering, ProPlan.monthly);
      final annual = _selectPackageFromOffering(offering, ProPlan.annual);
      final lifetime = _selectPackageFromOffering(offering, ProPlan.lifetime);

      if (monthly != null) {
        _monthlyPriceLabel = '${monthly.storeProduct.priceString}/mois';
      }
      if (annual != null) {
        _annualPriceLabel = '${annual.storeProduct.priceString}/an';
      }
      if (lifetime != null) {
        _lifetimePriceLabel = lifetime.storeProduct.priceString;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Chargement des prix store indisponible: $e');
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
    }
  }

  Future<bool> purchasePro(ProPlan plan) async {
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
      final pkg = _selectPackage(offering, plan);
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

  static const int freeMaxSeconds = 20;
  static const int freePianoRows = 4;
  static const int freePianoCols = 4;

  static const int proMaxSeconds = 600;
  static const int proPianoRows = 8;
  static const int proPianoCols = 16;

  int get maxTrimSeconds => _isPro ? proMaxSeconds : freeMaxSeconds;
  int get pianoRows => _isPro ? proPianoRows : freePianoRows;
  int get pianoCols => _isPro ? proPianoCols : freePianoCols;

  Package? _selectPackage(Offering? offering, ProPlan plan) {
    final pkg = _selectPackageFromOffering(offering, plan);
    if (pkg != null) return pkg;

    _lastError = switch (plan) {
      ProPlan.monthly => 'Aucun abonnement mensuel trouve dans RevenueCat.',
      ProPlan.annual => 'Aucun abonnement annuel trouve dans RevenueCat.',
      ProPlan.lifetime => 'Aucun achat a vie trouve dans RevenueCat.',
    };
    return null;
  }

  Package? _selectPackageFromOffering(Offering? offering, ProPlan plan) {
    if (offering == null) return null;

    final preferredProductId = switch (plan) {
      ProPlan.monthly => AppConfig.monthlyProductId,
      ProPlan.annual => AppConfig.annualProductId,
      ProPlan.lifetime => AppConfig.lifetimeProductId,
    };

    if (preferredProductId.isNotEmpty) {
      for (final package in offering.availablePackages) {
        if (package.storeProduct.identifier == preferredProductId) {
          return package;
        }
      }
    }

    return switch (plan) {
      ProPlan.monthly => offering.monthly,
      ProPlan.annual => offering.annual,
      ProPlan.lifetime => offering.lifetime,
    };
  }
}
