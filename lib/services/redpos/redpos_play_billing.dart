import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../printer_store.dart';
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

  Future<void> refresh({String? applicationUserName}) async {
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
      await _applyEntitlement(active);
    } catch (e) {
      debugPrint('play billing refresh: $e');
    }
  }

  Future<ProductDetails?> loadMonthlyProduct() async {
    if (!isAndroid) return null;
    if (!await _iap.isAvailable()) return null;
    final response = await _iap.queryProductDetails({productId});
    if (response.productDetails.isEmpty) return null;
    return response.productDetails.first;
  }

  /// Login Google obligatorio antes de cobrar o restaurar.
  Future<RedPosGoogleAccount?> signIn() async {
    lastError = null;
    if (!isAndroid) {
      lastError = tr(
        'La suscripción de Play es solo en Android.',
        'Play subscriptions are Android only.',
      );
      return null;
    }
    try {
      if (!_googleReady) {
        final webId = RedPosConfig.googleServerClientId.trim();
        debugPrint('google sign in web client: ${webId.length} chars');
        await GoogleSignIn.instance.initialize(
          serverClientId: webId.isEmpty ? null : webId,
        );
        _googleReady = true;
      }
      GoogleSignInAccount? account;
      try {
        account =
            await GoogleSignIn.instance.attemptLightweightAuthentication();
      } catch (e) {
        debugPrint('google lightweight: $e');
      }
      if (account == null) {
        if (!GoogleSignIn.instance.supportsAuthenticate()) {
          lastError = tr(
            'Este aparato no puede iniciar sesión con Google.',
            'This device cannot sign in with Google.',
          );
          return null;
        }
        account = await GoogleSignIn.instance.authenticate(
          scopeHint: const ['email', 'openid', 'profile'],
        );
      }
      final signedIn = RedPosGoogleAccount(
        email: account.email,
        displayName: account.displayName,
      );
      await RedPosLicenseStore.instance.setGoogleEmail(signedIn.email);
      return signedIn;
    } on GoogleSignInException catch (e) {
      debugPrint('google sign in: $e');
      lastError = _signInError(e);
      return null;
    } catch (e) {
      debugPrint('google sign in: $e');
      lastError = tr(
        'No se pudo iniciar sesión con Google. Elige una cuenta para pagar o restaurar.',
        'Could not sign in with Google. Choose an account to pay or restore.',
      );
      return null;
    }
  }

  String _signInError(GoogleSignInException e) {
    final detail = (e.description ?? '').trim();
    final configIssue = e.code == GoogleSignInExceptionCode.clientConfigurationError ||
        (e.code == GoogleSignInExceptionCode.canceled && detail.isEmpty);
    if (configIssue) {
      return tr(
        'No se pudo abrir el inicio de sesión de Google. En Cloud Console hace falta un cliente OAuth Android con el paquete com.redpos.service y la SHA-1 de Play App Signing (Integridad de la app). Luego reintenta.',
        'Google sign-in could not start. In Cloud Console add an Android OAuth client for package com.redpos.service and the Play App Signing SHA-1 (App integrity). Then try again.',
      );
    }
    if (e.code == GoogleSignInExceptionCode.canceled ||
        e.code == GoogleSignInExceptionCode.interrupted) {
      return tr(
        'Inicio de sesión cancelado. Elige la misma cuenta de Google que usas en Play Store para poder pagar y restaurar.',
        'Sign-in canceled. Choose the same Google account you use in Play Store to pay and restore.',
      );
    }
    return '${tr('No se pudo iniciar sesión con Google', 'Could not sign in with Google')} (${e.code.name}'
        '${detail.isEmpty ? '' : ': $detail'}).';
  }

  Future<String?> buyMonthly(
    ProductDetails product, {
    required RedPosGoogleAccount account,
  }) async {
    if (!isAndroid) {
      return tr(
        'La suscripción de Play es solo en Android.',
        'Play subscriptions are Android only.',
      );
    }
    if (!await _iap.isAvailable()) {
      return tr(
        'Google Play no está disponible en este aparato.',
        'Google Play is not available on this device.',
      );
    }
    await RedPosLicenseStore.instance.setGoogleEmail(account.email);
    final userName = obfuscatedAccountId(account.email);
    final offerToken =
        product is GooglePlayProductDetails ? product.offerToken : null;
    final started = await _iap.buyNonConsumable(
      purchaseParam: GooglePlayPurchaseParam(
        productDetails: product,
        applicationUserName: userName,
        offerToken: offerToken,
      ),
    );
    if (!started) {
      return tr('No se pudo iniciar el pago.', 'Could not start payment.');
    }
    return null;
  }

  Future<void> restore({required RedPosGoogleAccount account}) async {
    if (!isAndroid) return;
    if (!await _iap.isAvailable()) return;
    await RedPosLicenseStore.instance.setGoogleEmail(account.email);
    await _iap.restorePurchases(
      applicationUserName: obfuscatedAccountId(account.email),
    );
    await refresh(applicationUserName: obfuscatedAccountId(account.email));
  }

  static String obfuscatedAccountId(String email) {
    return sha256.convert(utf8.encode(email.trim().toLowerCase())).toString();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    var active = false;
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;
      if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        lastError = purchase.error?.message ??
            tr('Pago cancelado.', 'Payment canceled.');
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
    if (active) await _applyEntitlement(true);
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
