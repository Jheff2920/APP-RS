import 'package:flutter_test/flutter_test.dart';
import 'package:hello_world_app/legal/legal_copy.dart';
import 'package:hello_world_app/l10n/app_lang.dart';
import 'package:hello_world_app/models/paper_width.dart';
import 'package:hello_world_app/models/print_job_record.dart';
import 'package:hello_world_app/models/saved_printer.dart';
import 'package:hello_world_app/services/custom_ticket/custom_ticket_store.dart';
import 'package:hello_world_app/services/print_history_store.dart';
import 'package:hello_world_app/services/printer_store.dart';
import 'package:hello_world_app/services/privacy_data_wipe.dart';
import 'package:hello_world_app/services/redpos/redpos_license.dart';
import 'package:hello_world_app/services/sunat/sunat_print_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wipeLocal clears printers, history, tickets, sunat and license prefs',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final printers = PrinterStore(prefs: prefs);
    await printers.upsert(
      SavedPrinter(
        id: 'p1',
        name: 'Test',
        type: PrinterLinkType.network,
        address: '192.168.1.10',
        paper: PaperWidth.mm80,
      ),
    );
    expect((await printers.loadAll()).length, 1);

    final history = PrintHistoryStore(prefs: prefs);
    await history.add(
      title: 'job',
      printerId: 'p1',
      printerName: 'Test',
      status: PrintJobStatus.success,
    );
    expect((await history.loadAll()).length, 1);

    final tickets = CustomTicketStore(prefs: prefs);
    await tickets.create(name: 'Demo');
    expect((await tickets.loadAll()).length, 1);

    final sunat = SunatPrintStore(prefs: prefs);
    await sunat.save(const SunatPrintSettings());
    expect(prefs.containsKey(SunatPrintStore.settingsKey), isTrue);

    final license = RedPosLicenseStore(prefs: prefs);
    await license.setPlayEntitlement(true);
    await license.setGoogleEmail('buyer@gmail.com');
    expect(await license.isAdsFree(reloadDisk: false), isTrue);

    final result = await PrivacyDataWipe(
      printerStore: printers,
      historyStore: history,
      ticketStore: tickets,
      sunatStore: sunat,
      licenseStore: license,
      prefs: prefs,
    ).wipeLocal();

    expect(result.ok, isTrue);
    expect(await printers.loadAll(), isEmpty);
    expect(await history.loadAll(), isEmpty);
    expect(await tickets.loadAll(), isEmpty);
    expect(prefs.containsKey(SunatPrintStore.settingsKey), isFalse);
    expect(prefs.containsKey(SunatPrintStore.logoKey), isFalse);
    expect(await license.isAdsFree(reloadDisk: false), isFalse);
    expect(await license.googleEmail(reloadDisk: false), isNull);
  });

  test('privacy policy states no generative AI', () {
    final sections = LegalCopy.privacy(const L(false));
    final ai = sections.firstWhere((s) => s.title.contains('Inteligencia'));
    expect(ai.body.toLowerCase(), contains('no utiliza inteligencia artificial generativa'));
    final summary = LegalCopy.privacySummary(const L(false));
    expect(
      summary.any((s) => s.body.contains('no utiliza inteligencia artificial generativa')),
      isTrue,
    );
  });

  test('wipe known keys stay stable for Play disclosures', () {
    expect(
      PrivacyDataWipe.knownKeys,
      containsAll([
        'saved_printers_v1',
        'print_history_v1',
        CustomTicketStore.templatesKey,
        SunatPrintStore.settingsKey,
        SunatPrintStore.logoKey,
        RedPosLicenseStore.playEntitlementKey,
        RedPosLicenseStore.googleEmailKey,
      ]),
    );
  });
}
