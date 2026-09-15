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
        _message = tr(
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
        _message = tr(
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
    final account = await RedPosPlayBilling.instance.signIn();
    if (!mounted) return;
    if (account == null) {
      setState(() {
        _busy = false;
        _message = RedPosPlayBilling.instance.lastError ??
            tr(
              'Elige una cuenta de Google para pagar.',
              'Choose a Google account to pay.',
            );
      });
      return;
    }
    setState(() => _email = account.email);
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
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await RedPosPlayBilling.instance.refresh();
    final adsFree = await RedPosLicenseStore.instance.isAdsFree();
    if (!mounted) return;
    setState(() => _busy = false);
    if (adsFree) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final account = await RedPosPlayBilling.instance.signIn();
    if (!mounted) return;
    if (account == null) {
      setState(() {
        _busy = false;
        _message = RedPosPlayBilling.instance.lastError ??
            tr(
              'Elige una cuenta de Google para restaurar la compra.',
              'Choose a Google account to restore the purchase.',
            );
      });
      return;
    }
    setState(() => _email = account.email);
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
                      'Primero inicia sesión con la misma cuenta de Google que usas en Play Store. '
                      'Así sabemos quién pagó y puedes restaurar la compra en otro teléfono.',
                      'First sign in with the same Google account you use in Play Store. '
                      'That way we know who paid and you can restore on another phone.',
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
                          : const Icon(Icons.login),
                      label: Text(
                        l(
                          'Entrar con Google y suscribirme',
                          'Sign in with Google and subscribe',
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
