import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../l10n/app_lang.dart';
import '../services/printer_store.dart';
import '../services/redpos/redpos_license.dart';
import '../services/redpos/redpos_play_billing.dart';
import '../widgets/redpos_unlock_actions.dart';

class RedPosSubscribeScreen extends StatefulWidget {
  const RedPosSubscribeScreen({super.key, required this.store});

  final PrinterStore store;

  @override
  State<RedPosSubscribeScreen> createState() => _RedPosSubscribeScreenState();
}

class _RedPosSubscribeScreenState extends State<RedPosSubscribeScreen> {
  ProductDetails? _product;
  var _loading = true;
  var _busy = false;
  String? _message;
  String? _email;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await RedPosPlayBilling.instance.start(store: widget.store);
    final product = await RedPosPlayBilling.instance.loadMonthlyProduct();
    final email = await RedPosLicenseStore.instance.googleEmail();
    if (!mounted) return;
    setState(() {
      _product = product;
      _email = email;
      _loading = false;
      if (product == null) {
        _message = RedPosPlayBilling.instance.lastError ??
            tr(
              'La suscripción mensual aún no está publicada en Play Console. '
              'Mientras tanto usa un código RedPOS o pide la licencia de por vida por correo.',
              'The monthly subscription is not live in Play Console yet. '
              'Use a RedPOS code or request a lifetime license by email.',
            );
      }
    });
  }

  Future<void> _subscribe() async {
    final product = _product;
    if (product == null) {
      setState(() {
        _message = RedPosPlayBilling.instance.lastError ??
            tr(
              'La suscripción mensual aún no está publicada en Play Console. '
              'Mientras tanto usa un código RedPOS o pide la licencia de por vida por correo.',
              'The monthly subscription is not live in Play Console yet. '
              'Use a RedPOS code or request a lifetime license by email.',
            );
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final account = await RedPosPlayBilling.instance.trySilentSignIn();
    if (!mounted) return;
    if (account != null) setState(() => _email = account.email);
    final error = await RedPosPlayBilling.instance.buyMonthly(
      product,
      account: account,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _message = error;
      });
      return;
    }
    setState(() {
      _message = tr(
        'Esperando la confirmación de Google Play…',
        'Waiting for Google Play to confirm…',
      );
    });
    final confirmed = await RedPosPlayBilling.instance.waitForPurchaseOutcome();
    if (!confirmed) {
      await RedPosPlayBilling.instance.refresh(allowRevoke: false);
    }
    final adsFree = await RedPosLicenseStore.instance.isAdsFree();
    if (!mounted) return;
    setState(() => _busy = false);
    if (adsFree) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _message = RedPosPlayBilling.instance.lastError ??
          tr(
            'Google Play no activó la suscripción. Si te cobraron, pulsa Restaurar.',
            'Google Play did not activate the subscription. If you were charged, tap Restore.',
          );
    });
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final account = await RedPosPlayBilling.instance.trySilentSignIn();
    if (!mounted) return;
    if (account != null) setState(() => _email = account.email);
    await RedPosPlayBilling.instance.restore(account: account);
    final adsFree = await RedPosLicenseStore.instance.isAdsFree();
    if (!mounted) return;
    setState(() => _busy = false);
    if (adsFree) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _message = tr(
        'No hay una suscripción vigente en esta cuenta de Google.',
        'There is no active subscription on this Google account.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = L.of(context);
    final price = _product?.price;
    return Scaffold(
      appBar: AppBar(
        title: Text(l('Suscripción mensual', 'Monthly subscription')),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: math.min(600, constraints.maxWidth),
              height: constraints.maxHeight,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                scrollCacheExtent: const ScrollCacheExtent.pixels(280),
                children: [
                  Text(
                    l(
                      'Google Play cobra con la cuenta que ya está en este aparato '
                      '(la misma con la que instalaste la prueba). '
                      'Para restaurar en otro teléfono, entra a Play Store con ese Gmail y pulsa Restaurar.',
                      'Google Play charges the account already on this device '
                      '(the same one you used to install the test). '
                      'To restore on another phone, open Play Store with that Gmail and tap Restore.',
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.verified_outlined),
                      title: Text(
                        l(
                          'RedPOS Service sin publicidad',
                          'RedPOS Service ad-free',
                        ),
                      ),
                      subtitle: Text(
                        price == null
                            ? l(
                                'Precio mensual (se muestra al publicar el producto en Play)',
                                'Monthly price (shown when the Play product is live)',
                              )
                            : l(
                                '$price al mes, cobrado por Google Play',
                                '$price per month, billed by Google Play',
                              ),
                      ),
                    ),
                  ),
                  if (_email != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      l('Cuenta: $_email', 'Account: $_email'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    FilledButton.icon(
                      onPressed: _busy || _product == null ? null : _subscribe,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.shopping_bag_outlined),
                      label: Text(
                        l(
                          'Suscribirme con Google Play',
                          'Subscribe with Google Play',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _busy ? null : _restore,
                      child: Text(
                        l(
                          'Ya pagué: restaurar compra',
                          'I already paid: restore purchase',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => openLifetimeLicenseMail(context),
                      child: Text(
                        l(
                          'Prefiero licencia de por vida',
                          'I prefer a lifetime license',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
