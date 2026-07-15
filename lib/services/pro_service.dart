import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

const String _kProKey = 'is_pro';

enum ProPlan { monthly, annual, lifetime }

class ProService extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Completer<bool>? _purchaseCompleter;

  bool _isPro = false;
  bool _isLoading = false;
  bool _storeAvailable = false;
  String? _lastError;
  final Map<String, ProductDetails> _products = {};

  String _monthlyPriceLabel = '1,99 €/mois';
  String _annualPriceLabel = '9,99 €/an';
  String _lifetimePriceLabel = '39,90 €';

  bool get isPro => _isPro;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get storeAvailable => _storeAvailable;
  bool get productsReady => _products.isNotEmpty;
  String get monthlyPriceLabel => _monthlyPriceLabel;
  String get annualPriceLabel => _annualPriceLabel;
  String get lifetimePriceLabel => _lifetimePriceLabel;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool(_kProKey) ?? false;
    notifyListeners();

    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) {
      _lastError = 'Boutique indisponible sur cet appareil.';
      notifyListeners();
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) {
        _lastError = 'Erreur achats : $e';
        _finishPurchaseFlow(false);
        notifyListeners();
      },
    );

    await _loadProducts();
    await restorePurchases(silent: true);
  }

  Future<void> disposeService() async {
    await _subscription?.cancel();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(AppConfig.proProductIds);
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Produits introuvables : ${response.notFoundIDs}');
      }
      if (response.error != null) {
        _lastError = response.error!.message;
      }

      _products
        ..clear()
        ..addEntries(
          response.productDetails.map((product) => MapEntry(product.id, product)),
        );
      _updatePriceLabels();
      notifyListeners();
    } catch (e) {
      _lastError = 'Chargement des prix indisponible : $e';
      notifyListeners();
    }
  }

  void _updatePriceLabels() {
    final monthly = _products[AppConfig.monthlyProductId];
    final annual = _products[AppConfig.annualProductId];
    final lifetime = _products[AppConfig.lifetimeProductId];

    if (monthly != null) _monthlyPriceLabel = '${monthly.price}/mois';
    if (annual != null) _annualPriceLabel = '${annual.price}/an';
    if (lifetime != null) _lifetimePriceLabel = lifetime.price;
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _isLoading = true;
          notifyListeners();
          break;
        case PurchaseStatus.error:
          _lastError = purchase.error?.message ?? 'Achat échoué';
          _finishPurchaseFlow(false);
          break;
        case PurchaseStatus.canceled:
          _lastError = 'Achat annulé';
          _finishPurchaseFlow(false);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (AppConfig.proProductIds.contains(purchase.productID)) {
            await _setPro(true);
            _lastError = null;
            _finishPurchaseFlow(true);
          }
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<bool> purchasePro(ProPlan plan) async {
    if (!_storeAvailable) {
      _lastError = 'Boutique indisponible sur cet appareil.';
      notifyListeners();
      return false;
    }

    final productId = _productIdForPlan(plan);
    final product = _products[productId];
    if (product == null) {
      _lastError =
          'Produit « $productId » introuvable. '
          'Vérifiez qu\'il est actif dans ${AppConfig.isAndroid ? 'Google Play Console' : 'App Store Connect'}.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _lastError = null;
    _purchaseCompleter = Completer<bool>();
    notifyListeners();

    final started = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!started) {
      _lastError = 'Impossible de lancer l\'achat.';
      _finishPurchaseFlow(false);
      return false;
    }

    try {
      return await _purchaseCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          _lastError = 'Délai d\'achat dépassé.';
          return false;
        },
      );
    } finally {
      _isLoading = false;
      _purchaseCompleter = null;
      notifyListeners();
    }
  }

  Future<bool> restorePurchases({bool silent = false}) async {
    if (!_storeAvailable) {
      if (!silent) {
        _lastError = 'Boutique indisponible sur cet appareil.';
        notifyListeners();
      }
      return false;
    }

    _isLoading = true;
    if (!silent) _lastError = null;
    notifyListeners();

    try {
      await _iap.restorePurchases();
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!silent && !_isPro) {
        _lastError = 'Aucun achat Pro trouvé sur ce compte.';
      }
      return _isPro;
    } catch (e) {
      if (!silent) _lastError = 'Restauration échouée : $e';
      debugPrint('Restauration échouée : $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _finishPurchaseFlow(bool success) {
    _isLoading = false;
    final completer = _purchaseCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(success);
    }
    _purchaseCompleter = null;
    notifyListeners();
  }

  Future<void> _setPro(bool value) async {
    _isPro = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kProKey, value);
    notifyListeners();
  }

  String _productIdForPlan(ProPlan plan) => switch (plan) {
    ProPlan.monthly => AppConfig.monthlyProductId,
    ProPlan.annual => AppConfig.annualProductId,
    ProPlan.lifetime => AppConfig.lifetimeProductId,
  };

  static const int freeMaxSeconds = 20;
  static const int freePianoRows = 4;
  static const int freePianoCols = 4;

  static const int proMaxSeconds = 600;
  static const int proPianoRows = 8;
  static const int proPianoCols = 16;

  int get maxTrimSeconds => _isPro ? proMaxSeconds : freeMaxSeconds;
  int get pianoRows => _isPro ? proPianoRows : freePianoRows;
  int get pianoCols => _isPro ? proPianoCols : freePianoCols;
}
