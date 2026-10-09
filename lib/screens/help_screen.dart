import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brand.dart';
import '../l10n/app_lang.dart';
import '../services/printer_store.dart';
import '../services/redpos/redpos_config.dart';
import '../services/redpos/redpos_links.dart';
import '../theme.dart';
import '../widgets/redpos_unlock_actions.dart';
import '../widgets/ui_kit.dart';
import 'legal_screen.dart';
import 'privacy_data_screen.dart';
import 'sunat_print_settings_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, required this.store});

  final PrinterStore store;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final whatsapp = RedPosConfig.whatsappUri;
    final l = L.of(context);

    void push(Widget page) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => page),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l('Ayuda y soporte', 'Help & support'))),
      body: PageList(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(
              l(
                'Si no imprime o tienes dudas del código de activación o la '
                    'suscripción, escríbenos. Imprimir nunca se bloquea.',
                'If it does not print, or you have questions about the '
                    'activation code or subscription, write us. Printing is '
                    'never blocked.',
              ),
              style: tt.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
          ),
          SectionLabel(l('Contacto', 'Contact')),
          SectionGroup(
            dividerIndent: 68,
            children: [
              NavRow(
                icon: Icons.mail_outline_rounded,
                title: l('Correo', 'Email'),
                subtitle: RedPosConfig.supportEmail,
                onTap: () => openRedPosLink(context, RedPosConfig.mailtoUri),
                onLongPress: () => _copy(
                  context,
                  RedPosConfig.supportEmail,
                  l('Correo copiado', 'Email copied'),
                ),
              ),
              if (whatsapp != null)
                NavRow(
                  icon: Icons.chat_outlined,
                  color: AppColors.ok,
                  title: 'WhatsApp',
                  subtitle: RedPosConfig.whatsappDigits,
                  onTap: () => openRedPosLink(context, whatsapp),
                ),
              NavRow(
                icon: Icons.language_rounded,
                title: l('Web', 'Website'),
                subtitle: RedPosConfig.siteUrl,
                onTap: () => openRedPosLink(
                  context,
                  Uri.parse(RedPosConfig.siteUrlWithScheme),
                ),
              ),
              NavRow(
                icon: Icons.schedule_rounded,
                color: AppColors.inkSoft,
                title: l('Horario', 'Hours'),
                subtitle: l.english
                    ? RedPosConfig.supportHoursEn
                    : RedPosConfig.supportHours,
              ),
            ],
          ),
          SectionLabel(l('Si no imprime', 'If it does not print')),
          Card(
            child: SectionBody(
              children: [
                _Tip(
                  l(
                    'Revisa que la impresora esté encendida, con papel y '
                        'vinculada por Bluetooth, WiFi o USB.',
                    'Check the printer is on, has paper, and is paired over '
                        'Bluetooth, WiFi or USB.',
                  ),
                ),
                _Tip(
                  l(
                    'En Android, permite «Mostrar sobre otras apps» y deja '
                        '${AppBrand.name} activo en Ajustes, Impresión.',
                    'On Android, allow “Display over other apps” and keep '
                        '${AppBrand.name} on in Settings, Printing.',
                  ),
                ),
                _Tip(
                  l(
                    'Si apagaste un equipo USB, vuelve a aceptar el permiso USB.',
                    'After powering off a USB device, accept the USB prompt again.',
                  ),
                  last: true,
                ),
              ],
            ),
          ),
          SectionLabel(l('Funciones', 'Features')),
          SectionGroup(
            dividerIndent: 68,
            children: [
              NavRow(
                icon: Icons.receipt_long_outlined,
                title: l('Configurar ticket SUNAT', 'SUNAT ticket settings'),
                subtitle: l(
                  'Formato, logo y nota por defecto. Al compartir un XML '
                      'puedes cambiar la nota de ese ticket.',
                  'Format, logo and default note. When sharing an XML you can '
                      'change the note for that ticket.',
                ),
                onTap: () => push(SunatPrintSettingsScreen(printerStore: store)),
              ),
              NavRow(
                icon: Icons.edit_note_rounded,
                title: l('Tickets propios', 'Custom tickets'),
                subtitle: l(
                  'En el inicio, Herramientas: arma tickets con logo, '
                      'productos, totales, QR o código de barras.',
                  'On the home screen, Tools: build tickets with logo, '
                      'products, totals, QR or barcode.',
                ),
                showChevron: false,
              ),
            ],
          ),
          SectionLabel(
            l(
              'Código de activación, suscripción y licencia',
              'Activation code, subscription and license',
            ),
          ),
          SectionGroup(
            dividerIndent: 68,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Text(
                  l(
                    'El código de activación quita la publicidad sin iniciar '
                        'sesión. La suscripción mensual se paga en Google Play; '
                        'si la cancelas vuelven los avisos, pero imprimir sigue '
                        'disponible.',
                    'The activation code removes ads without signing in. The '
                        'monthly subscription is paid in Google Play; if you '
                        'cancel it, ads return but printing still works.',
                  ),
                  style: tt.bodyMedium?.copyWith(color: AppColors.inkSoft),
                ),
              ),
              NavRow(
                icon: Icons.autorenew_rounded,
                title: l('Suscripción mensual', 'Monthly subscription'),
                onTap: () => openMonthlySubscription(context, store),
              ),
              NavRow(
                icon: Icons.all_inclusive_rounded,
                title: l('Licencia de por vida', 'Lifetime license'),
                onTap: () => openLifetimeLicenseMail(context),
              ),
            ],
          ),
          SectionLabel(l('Legal', 'Legal')),
          SectionGroup(
            dividerIndent: 68,
            children: [
              NavRow(
                icon: Icons.shield_outlined,
                title: l('Datos y privacidad', 'Data & privacy'),
                onTap: () => push(PrivacyDataScreen(store: store)),
              ),
              NavRow(
                icon: Icons.article_outlined,
                title: l('Términos y condiciones', 'Terms and conditions'),
                onTap: () => push(const LegalScreen.terms()),
              ),
              NavRow(
                icon: Icons.privacy_tip_outlined,
                title: l('Política de privacidad', 'Privacy policy'),
                onTap: () => push(const LegalScreen.privacy()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _copy(
    BuildContext context,
    String value,
    String message,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.text, {this.last = false});

  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 20,
              color: AppColors.ok,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
