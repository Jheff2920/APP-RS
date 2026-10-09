import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../printer_store.dart';
import '../../brand.dart';
import '../../l10n/app_lang.dart';
import 'redpos_config.dart';
import 'redpos_license.dart';

class RedPosGoogleAccount {
  const RedPosGoogleAccount({required this.email, this.displayName});
  final String email;
  final String? displayName;
}

/// Google Play Billing: suscripción mensual que quita anuncios.
class RedPosPlayBilling {
  RedPosPlayBilling({InAppPurchase? iap}) : _iap = iap ?? InAppPurchase.instance;

  static final instance = RedPosPlayBilling();

  static String get productId => RedPosConfig.playMonthlyProductId;

  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  PrinterStore? _store;
  Completer<bool>? _purchaseWait;
  var _googleReady = false;
  String? lastError;

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  Future<void> start({PrinterStore? store}) async {
    if (store != null) _store = store;
    if (!isAndroid) return;
    _sub ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => debugPrint('play billing stream: $e'),
    );
    await refresh();
  }

  Future<void> refresh({
    String? applicationUserName,
    bool allowRevoke = true,
  }) async {
    if (!isAndroid) return;
    if (!await _iap.isAvailable()) return;
    try {
      var userName = applicationUserName;
      if (userName == null) {
        final email = await RedPosLicenseStore.instance.googleEmail();
        if (email != null) userName = obfuscatedAccountId(email);
      }
      final addition =
          _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final past = await addition.queryPastPurchases(
        applicationUserName: userName,
      );
      if (past.error != null) {
        debugPrint('queryPastPurchases: ${past.error}');
        lastError = past.error?.message;
        return;
      }
      var active = false;
      for (final purchase in past.pastPurchases) {
        if (_isActiveSub(purchase)) {
          active = true;
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        }
      }
      if (active) {
        await _applyEntitlement(true);
      } else if (allowRevoke) {
        await _applyEntitlement(false);
      }
    } catch (e) {
      debugPrint('play billing refresh: $e');
    }
  }

  Future<ProductDetails?> loadMonthlyProduct() async {
    lastError = null;
    if (!isAndroid) {
      lastError = tr(
        'La suscripción de Play es solo en Android.',
        'Play subscriptions are Android only.',
      );
      return null;
    }
    if (!await _iap.isAvailable()) {
      lastError = tr(
        'No se puede cobrar desde este equipo. Instala ${AppBrand.name} desde '
        'Google Play e inténtalo de nuevo.',
        'Payments are not available on this device. Install ${AppBrand.name} '
        'from Google Play and try again.',
      );
      return null;
    }
    final response = await _iap.queryProductDetails({productId});
    if (response.error != null) {
      lastError = tr(
        'Google Play no pudo cargar la suscripción. Inténtalo de nuevo en unos minutos.',
        'Google Play could not load the subscription. Try again in a few minutes.',
      );
      return null;
    }
    if (response.productDetails.isEmpty ||
        response.notFoundIDs.contains(productId)) {
      lastError = tr(
        'La suscripción no está disponible ahora. Instala ${AppBrand.name} desde '
        'Google Play con la misma cuenta e inténtalo de nuevo. Si sigue igual, '
        'escríbenos desde Ayuda.',
        'The subscription is not available right now. Install ${AppBrand.name} '
        'from Google Play with the same account and try again. If it keeps '
        'happening, write to us from Help.',
      );
      return null;
    }
    for (final product in response.productDetails) {
      if (product is GooglePlayProductDetails &&
          (product.offerToken?.isNotEmpty ?? false)) {
        return product;
      }
    }
    return response.productDetails.first;
  }

  Future<void> _ensureGoogle() async {
    if (_googleReady) return;
    final webId = RedPosConfig.googleServerClientId.trim();
    await GoogleSignIn.instance.initialize(
      serverClientId: webId.isEmpty ? null : webId,
    );
    _googleReady = true;
  }

  /// Solo si Google ya tiene sesión. No abre el selector: Credential Manager
  /// lo marca como “cancelado” tras elegir la cuenta si falta la SHA-1 de Play.
  Future<RedPosGoogleAccount?> trySilentSignIn() async {
    if (!isAndroid) return null;
    try {
      await _ensureGoogle();
      final account =
          await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (account == null) return null;
      return _remember(account);
    } catch (e) {
      debugPrint('google silent: $e');
      return null;
    }
  }

  Future<RedPosGoogleAccount> _remember(GoogleSignInAccount account) async {
    final signedIn = RedPosGoogleAccount(
      email: account.email,
      displayName: account.displayName,
    );
    final stored =
        await RedPosLicenseStore.instance.setGoogleEmail(signedIn.email);
    if (!stored) {
      debugPrint('google email persist failed for ${signedIn.email}');
    }
    return signedIn;
  }

  Future<String?> buyMonthly(
    ProductDetails product, {
    RedPosGoogleAccount? account,
  }) async {
    if (!isAndroid) {
      return tr(
        'La suscripción de Play es solo en Android.',
        'Play subscriptions are Android only.',
      );
    }
    if (!await _iap.isAvailable()) {
      return tr(
        'Google Play no está disponible en este equipo.',
        'Google Play is not available on this device.',
      );
    }
    var userName = account == null
        ? null
        : obfuscatedAccountId(account.email);
    if (account != null) {
      await RedPosLicenseStore.instance.setGoogleEmail(account.email);
    } else {
      final email = await RedPosLicenseStore.instance.googleEmail();
      if (email != null) userName = obfuscatedAccountId(email);
    }
    final offerToken =
        product is GooglePlayProductDetails ? product.offerToken : null;
    if (product is GooglePlayProductDetails &&
        (offerToken == null || offerToken.isEmpty)) {
      return tr(
        'Google Play no mostró la oferta de la suscripción. Inténtalo de nuevo en unos minutos.',
        'Google Play did not show the subscription offer. Try again in a few minutes.',
      );
    }
    lastError = null;
    _resetPurchaseWait();
    final started = await _iap.buyNonConsumable(
      purchaseParam: GooglePlayPurchaseParam(
        productDetails: product,
        applicationUserName: userName,
        offerToken: offerToken,
      ),
    );
    if (!started) {
      _finishPurchaseWait(false);
      return tr('No se pudo iniciar el pago.', 'Could not start payment.');
    }
    return null;
  }

  /// Espera el evento de [purchaseStream] tras [buyMonthly].
  Future<bool> waitForPurchaseOutcome({
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final wait = _purchaseWait;
    if (wait == null) return false;
    try {
      return await wait.future.timeout(
        timeout,
        onTimeout: () {
          lastError = tr(
            'Google Play no confirmó el pago a tiempo. Si te cobraron, pulsa Restaurar.',
            'Google Play did not confirm the payment in time. If you were charged, tap Restore.',
          );
          return false;
        },
      );
    } finally {
      if (identical(_purchaseWait, wait)) _purchaseWait = null;
    }
  }

  void _resetPurchaseWait() {
    final previous = _purchaseWait;
    if (previous != null && !previous.isCompleted) {
      previous.complete(false);
    }
    _purchaseWait = Completer<bool>();
  }

  void _finishPurchaseWait(bool ok) {
    final wait = _purchaseWait;
    if (wait != null && !wait.isCompleted) wait.complete(ok);
  }

  Future<void> restore({RedPosGoogleAccount? account}) async {
    if (!isAndroid) return;
    if (!await _iap.isAvailable()) return;
    String? userName;
    if (account != null) {
      await RedPosLicenseStore.instance.setGoogleEmail(account.email);
      userName = obfuscatedAccountId(account.email);
    } else {
      final email = await RedPosLicenseStore.instance.googleEmail();
      if (email != null) userName = obfuscatedAccountId(email);
    }
    await _iap.restorePurchases(applicationUserName: userName);
    await refresh(applicationUserName: userName, allowRevoke: false);
  }

  static String obfuscatedAccountId(String email) {
    return sha256.convert(utf8.encode(email.trim().toLowerCase())).toString();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    var sawOurs = false;
    var active = false;
    var failed = false;
    for (final purchase in purchases) {
      if (purchase.productID != productId) continue;
      sawOurs = true;
      if (purchase.status == PurchaseStatus.pending) continue;
      if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        lastError = purchase.error?.message ??
            tr('Pago cancelado.', 'Payment canceled.');
        failed = true;
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }
      if (_isActiveSub(purchase)) {
        active = true;
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
    if (active) {
      await _applyEntitlement(true);
      _finishPurchaseWait(true);
      return;
    }
    if (sawOurs && failed) _finishPurchaseWait(false);
  }

  bool _isActiveSub(PurchaseDetails purchase) {
    if (purchase.productID != productId) return false;
    return purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored;
  }

  Future<void> _applyEntitlement(bool active) async {
    await RedPosLicenseStore.instance.setPlayEntitlement(active);
    final store = _store;
    if (store != null) {
      await RedPosLicenseStore.instance.applyToPrinters(store);
    }
  }
}
