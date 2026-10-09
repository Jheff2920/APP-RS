import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hello_world_app/models/paper_width.dart';
import 'package:hello_world_app/models/saved_printer.dart';
import 'package:hello_world_app/screens/custom_ticket_edit_screen.dart';
import 'package:hello_world_app/screens/custom_ticket_preview_screen.dart';
import 'package:hello_world_app/screens/custom_tickets_list_screen.dart';
import 'package:hello_world_app/screens/help_screen.dart';
import 'package:hello_world_app/screens/legal_screen.dart';
import 'package:hello_world_app/screens/print_history_screen.dart';
import 'package:hello_world_app/screens/printer_form_screen.dart';
import 'package:hello_world_app/screens/printer_list_screen.dart';
import 'package:hello_world_app/screens/privacy_data_screen.dart';
import 'package:hello_world_app/screens/redpos_subscribe_screen.dart';
import 'package:hello_world_app/screens/share_print_screen.dart';
import 'package:hello_world_app/screens/sunat_print_settings_screen.dart';
import 'package:hello_world_app/services/custom_ticket/custom_ticket.dart';
import 'package:hello_world_app/services/custom_ticket/custom_ticket_store.dart';
import 'package:hello_world_app/services/print_history_store.dart';
import 'package:hello_world_app/services/print_service.dart';
import 'package:hello_world_app/services/printer_store.dart';
import 'package:hello_world_app/services/redpos/redpos_license.dart';
import 'package:hello_world_app/theme.dart';

/// Matriz de responsividad: cada pantalla se monta en teléfonos pequeños y
/// grandes (vertical y horizontal), tablets y pantallas anchas, con letra
/// normal, grande y muy grande, con barras del sistema. Falla ante cualquier
/// desborde de Flex o texto cortado por el borde de la pantalla.
class _Device {
  const _Device(this.name, this.width, this.height);
  final String name;
  final double width;
  final double height;
}

const _devices = [
  _Device('tel 320x568', 320, 568),
  _Device('pos 320x480', 320, 480),
  _Device('tel 360x640', 360, 640),
  _Device('tel 412x915', 412, 915),
  _Device('tel horizontal 640x360', 640, 360),
  _Device('tel horizontal 915x412', 915, 412),
  _Device('plegable 700x840', 700, 840),
  _Device('tablet 600x960', 600, 960),
  _Device('tablet 800x1280', 800, 1280),
  _Device('tablet horizontal 1024x600', 1024, 600),
  _Device('tablet horizontal 1280x800', 1280, 800),
  _Device('pantalla grande 1920x1200', 1920, 1200),
];

const _systemBarBottom = 48.0;

const _scales = [1.0, 1.5, 2.0];

Future<void> _prepare(
  WidgetTester t,
  _Device d,
  double scale,
  Map<String, Object> prefs,
) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  RedPosLicenseStore.instance.resetForTest(prefs: p);
  final messenger = t.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/permissions/methods'),
    (call) async => switch (call.method) {
      'checkPermissionStatus' || 'checkServiceStatus' => 1,
      'requestPermissions' => <int, int>{},
      'shouldShowRequestPermissionRationale' => false,
      _ => null,
    },
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('boleta_print/printers_prefs'),
    (call) async => null,
  );
  // Bluetooth y USB nativos: sin dispositivos cercanos ni emparejados.
  messenger.setMockMethodCallHandler(
    const MethodChannel('boleta_print/bt_bond'),
    (call) async => switch (call.method) {
      'listBonded' => <dynamic>[],
      'startScan' => true,
      _ => null,
    },
  );
  messenger.setMockStreamHandler(
    const EventChannel('boleta_print/bt_bond_events'),
    MockStreamHandler.inline(onListen: (_, __) {}),
  );
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(d.width, d.height);
  // Barra de estado arriba y de navegación abajo (extremo a extremo).
  const bars = FakeViewPadding(top: 24, bottom: 48);
  t.view.padding = bars;
  t.view.viewPadding = bars;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  t.platformDispatcher.localeTestValue = const Locale('es');
  t.platformDispatcher.localesTestValue = const [Locale('es')];
}

void _reset(WidgetTester t) {
  t.view.reset();
  t.platformDispatcher.clearTextScaleFactorTestValue();
  t.platformDispatcher.clearLocaleTestValue();
  t.platformDispatcher.clearLocalesTestValue();
}

Widget _app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: boletaPrintTheme,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

SavedPrinter _printer(
  String id,
  String name,
  PrinterLinkType type,
  String address, {
  bool isDefault = false,
  PaperWidth paper = PaperWidth.mm80,
}) =>
    SavedPrinter(
      id: id,
      name: name,
      type: type,
      address: address,
      paper: paper,
      isDefault: isDefault,
    );

Future<void> _seedPrinters(int n) async {
  final store = PrinterStore();
  final all = [
    _printer('a', 'Caja principal', PrinterLinkType.network, '192.168.1.50',
        isDefault: true),
    _printer('b', 'Cocina HQ300 (segundo piso del local)',
        PrinterLinkType.bluetooth, '86:67:7A:02:34:8C',
        paper: PaperWidth.mm58),
    _printer('c', 'Impresora USB integrada', PrinterLinkType.usb, '1137:85'),
  ];
  for (final p in all.take(n)) {
    await store.upsert(p);
  }
}

String _historyJson() {
  final now = DateTime.now();
  Map<String, Object?> job(
    int minsAgo,
    String title,
    String status,
    String source, {
    String? error,
  }) =>
      {
        'id': '$minsAgo',
        'createdAt': now.subtract(Duration(minutes: minsAgo)).toIso8601String(),
        'title': title,
        'printerId': 'a',
        'printerName': 'Caja principal',
        'status': status,
        'source': source,
        'error': error,
      };
  return jsonEncode([
    job(3, 'B001-00012345.xml', 'success', 'share'),
    job(25, 'Página de prueba', 'success', 'test'),
    job(70, 'Factura F001-889 de un cliente con nombre largo.pdf', 'failed',
        'share',
        error: 'No se pudo conectar con la impresora (tiempo agotado).'),
    job(60 * 26, 'Ticket propio: Menú del día', 'success', 'custom_ticket'),
  ]);
}

/// Textos que sobresalen por los lados de la pantalla (cortados).
List<String> _clippedTexts(WidgetTester t, double width) {
  final out = <String>[];
  for (final e in find.byType(Text).evaluate()) {
    // Etiquetas y pistas de los campos: las maqueta y recorta el propio campo.
    if (e.findAncestorWidgetOfExactType<InputDecorator>() != null) continue;
    final box = e.renderObject;
    if (box is! RenderBox || !box.attached || !box.hasSize) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect.left < -1 || rect.right > width + 1) {
      final text = (e.widget as Text).data ?? '';
      out.add('«${text.length > 30 ? text.substring(0, 30) : text}» '
          '[${rect.left.round()}..${rect.right.round()}]');
    }
  }
  return out;
}

String _summary(FlutterErrorDetails d) {
  final lines = d.toString().split('\n');
  final head = lines.firstWhere((l) => l.contains('overflowed'),
      orElse: () => d.exceptionAsString().split('\n').first);
  final where = lines.firstWhere((l) => l.contains('lib/') || l.contains('lib\\'),
      orElse: () => '');
  return '$head ${where.trim()}'.trim();
}

typedef _Build = Future<Widget> Function(WidgetTester t);
typedef _After = Future<void> Function(WidgetTester t);

/// Toca un control como lo haría una persona: lo desplaza a la vista y
/// comprueba que nada lo tape antes de tocarlo.
Future<void> _tap(WidgetTester t, Finder f) async {
  if (f.evaluate().isEmpty) {
    // Las listas construyen perezosamente: hay que bajar hasta encontrarlo.
    await t.scrollUntilVisible(f, 150, maxScrolls: 60);
  }
  if (f.evaluate().isEmpty) {
    throw StateError('no se encontró ${f.describeMatch(Plurality.one)}');
  }
  await t.ensureVisible(f.first);
  await t.pump(const Duration(milliseconds: 100));
  if (f.hitTestable().evaluate().isEmpty) {
    throw StateError('no se puede tocar ${f.describeMatch(Plurality.one)} (tapado o fuera)');
  }
  await t.tap(f.hitTestable().first);
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

/// El control debe poder quedar por encima de la barra de navegación del
/// sistema: si está en una lista desplazable se baja hasta el final.
Future<void> _expectAboveSystemBar(WidgetTester t, Finder f) async {
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(f, 150, maxScrolls: 60);
  }
  if (f.evaluate().isEmpty) {
    throw StateError('no se encontró ${f.describeMatch(Plurality.one)}');
  }
  final scrollables = find.ancestor(
    of: f.first,
    matching: find.byType(Scrollable),
  );
  if (scrollables.evaluate().isNotEmpty) {
    final state = t.state<ScrollableState>(scrollables.first);
    state.position.jumpTo(state.position.maxScrollExtent);
    await t.pump(const Duration(milliseconds: 100));
  }
  final bottom = t.getRect(f.first).bottom;
  final limit = t.view.physicalSize.height - _systemBarBottom + 1;
  if (bottom > limit) {
    throw StateError(
      '${f.describeMatch(Plurality.one)} queda bajo la barra del sistema ($bottom > $limit)',
    );
  }
}

Future<void> _runMatrix(
  WidgetTester t,
  String screen,
  _Build build, {
  Map<String, Object> prefs = const {},
  Future<void> Function()? seed,
  _After? after,
  List<_Device> devices = _devices,
}) async {
  final failures = <String>[];
  final previous = FlutterError.onError;
  final caught = <FlutterErrorDetails>[];
  FlutterError.onError = caught.add;
  try {
    for (final d in devices) {
      for (final scale in _scales) {
        final label = '$screen | ${d.name} | letra x$scale';
        caught.clear();
        await _prepare(t, d, scale, {...prefs});
        if (seed != null) await t.runAsync(seed);
        try {
          await t.pumpWidget(const SizedBox());
          await t.pumpWidget(_app(await build(t)));
          for (var i = 0; i < 4; i++) {
            await t.pump(const Duration(milliseconds: 250));
          }
          if (after != null) await after(t);
          for (var i = 0; i < 4; i++) {
            await t.pump(const Duration(milliseconds: 250));
          }
          final clipped = _clippedTexts(t, d.width);
          if (clipped.isNotEmpty) {
            failures.add('$label: texto cortado ${clipped.take(3).join(', ')}');
          }
        } catch (e, st) {
          final where = st
              .toString()
              .split('\n')
              .where((l) => l.contains('widget_tester') || l.contains('_test.dart'))
              .take(2)
              .join(' <- ');
          failures.add('$label: excepción $e $where');
        }
        for (final c in caught.take(2)) {
          failures.add('$label: ${_summary(c)}');
        }
        await t.pumpWidget(const SizedBox());
        _reset(t);
      }
    }
  } finally {
    FlutterError.onError = previous;
  }
  expect(failures, isEmpty, reason: '\n${failures.join('\n')}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const timeout = Timeout(Duration(minutes: 8));

  testWidgets('autoprueba: la matriz detecta desbordes', (t) async {
    await expectLater(
      _runMatrix(
        t,
        'autoprueba',
        (_) async => Scaffold(
          body: Row(
            children: [Container(width: 900, height: 20, color: Colors.red)],
          ),
        ),
        devices: const [_Device('tel 320x568', 320, 568)],
      ),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('inicio vacío', (t) async {
    await _runMatrix(
      t,
      'inicio vacío',
      (_) async => PrinterListScreen(
        store: PrinterStore(),
        printService: PrintService(),
      ),
    );
  }, timeout: timeout);

  testWidgets('inicio con 1 impresora', (t) async {
    await _runMatrix(
      t,
      'inicio 1 impresora',
      (_) async => PrinterListScreen(
        store: PrinterStore(),
        printService: PrintService(),
      ),
      seed: () => _seedPrinters(1),
    );
  }, timeout: timeout);

  testWidgets('inicio con 3 impresoras, desbloqueado', (t) async {
    await _runMatrix(
      t,
      'inicio 3 impresoras',
      (_) async => PrinterListScreen(
        store: PrinterStore(),
        printService: PrintService(),
      ),
      prefs: {RedPosLicenseStore.playEntitlementKey: true},
      seed: () => _seedPrinters(3),
    );
  }, timeout: timeout);

  testWidgets('inicio: opciones de la impresora y desvincular', (t) async {
    PrinterListScreen home() => PrinterListScreen(
          store: PrinterStore(),
          printService: PrintService(),
        );
    await _runMatrix(
      t,
      'opciones impresora',
      (_) async => home(),
      seed: () => _seedPrinters(1),
      after: (t) async {
        await _tap(t, find.byTooltip('Opciones de la impresora'));
        await _expectAboveSystemBar(t, find.text('Desvincular'));
      },
    );
    await _runMatrix(
      t,
      'desvincular',
      (_) async => home(),
      seed: () => _seedPrinters(1),
      after: (t) async {
        await _tap(t, find.byTooltip('Opciones de la impresora'));
        await _tap(t, find.text('Desvincular'));
        await _tap(t, find.text('Cancelar'));
      },
    );
  }, timeout: timeout);

  testWidgets('inicio: vincular impresora (panel o pantalla)', (t) async {
    await _runMatrix(
      t,
      'vincular desde el inicio',
      (_) async => PrinterListScreen(
        store: PrinterStore(),
        printService: PrintService(),
      ),
      after: (t) async {
        await _tap(t, find.text('Vincular impresora'));
        // El formulario abierto debe dejar "Guardar" tocable y sobre la barra.
        await _expectAboveSystemBar(t, find.text('Guardar'));
      },
    );
  }, timeout: timeout);

  testWidgets('inicio: quitar publicidad y código de activación', (t) async {
    await _runMatrix(
      t,
      'quitar publicidad',
      (_) async => PrinterListScreen(
        store: PrinterStore(),
        printService: PrintService(),
      ),
      seed: () => _seedPrinters(1),
      after: (t) async {
        await _tap(t, find.text('Quitar'));
        await _expectAboveSystemBar(t, find.text('Licencia de por vida'));
        await _tap(t, find.text('Tengo un código'));
        await _expectAboveSystemBar(t, find.text('Activar'));
      },
    );
  }, timeout: timeout);

  testWidgets('formulario: impresora WiFi existente', (t) async {
    await _runMatrix(
      t,
      'formulario wifi',
      (t) async {
        final store = PrinterStore();
        final p = (await t.runAsync(() => store.loadAll()))!.first;
        return PrinterFormScreen(store: store, existing: p);
      },
      seed: () => _seedPrinters(1),
      after: (t) async {
        await _expectAboveSystemBar(t, find.text('Guardar'));
        await _expectAboveSystemBar(t, find.text('Probar'));
      },
    );
  }, timeout: timeout);

  testWidgets('formulario: impresora Bluetooth y USB', (t) async {
    await _runMatrix(
      t,
      'formulario bluetooth',
      (t) async {
        final store = PrinterStore();
        final all = (await t.runAsync(() => store.loadAll()))!;
        return PrinterFormScreen(store: store, existing: all[1]);
      },
      seed: () => _seedPrinters(3),
      after: (t) async {
        await _expectAboveSystemBar(t, find.text('Guardar'));
      },
    );
    await _runMatrix(
      t,
      'buscar impresora bluetooth',
      (t) async {
        final store = PrinterStore();
        final all = (await t.runAsync(() => store.loadAll()))!;
        return PrinterFormScreen(store: store, existing: all[1]);
      },
      seed: () => _seedPrinters(3),
      after: (t) async {
        await _tap(t, find.text('Buscar impresora'));
        await _expectAboveSystemBar(t, find.text('Buscar de nuevo'));
      },
    );
    await _runMatrix(
      t,
      'formulario usb',
      (t) async {
        final store = PrinterStore();
        final all = (await t.runAsync(() => store.loadAll()))!;
        return PrinterFormScreen(store: store, existing: all[2]);
      },
      seed: () => _seedPrinters(3),
    );
  }, timeout: timeout);

  testWidgets('formulario: impresora nueva', (t) async {
    await _runMatrix(
      t,
      'formulario nuevo',
      (_) async => PrinterFormScreen(store: PrinterStore()),
      after: (t) async {
        // «Bluetooth» / «WiFi» / «USB» deben quedar en una sola línea (en 360 dp
        // llegó a partirse como «Blueto-oth»).
        final scale = t.platformDispatcher.textScaleFactor;
        for (final label in ['Bluetooth', 'WiFi', 'USB']) {
          final h = t.getSize(find.text(label).first).height;
          if (h > 24 * scale) {
            throw StateError('«$label» se parte en varias líneas (alto $h)');
          }
        }
      },
    );
  }, timeout: timeout);

  testWidgets('compartir archivo', (t) async {
    await _runMatrix(
      t,
      'compartir',
      (_) async => SharePrintScreen(
        filePath: '/tmp/20123456789-03-B001-00012345.xml',
        printerStore: PrinterStore(),
        printService: PrintService(),
      ),
      seed: () => _seedPrinters(3),
    );
  }, timeout: timeout);

  testWidgets('historial y borrar historial', (t) async {
    await _runMatrix(
      t,
      'historial',
      (_) async => PrintHistoryScreen(history: PrintHistoryStore()),
      prefs: {'print_history_v1': _historyJson()},
    );
    await _runMatrix(
      t,
      'borrar historial',
      (_) async => PrintHistoryScreen(history: PrintHistoryStore()),
      prefs: {'print_history_v1': _historyJson()},
      after: (t) async {
        await _tap(t, find.byTooltip('Borrar historial'));
        await _tap(t, find.text('Cancelar'));
      },
    );
  }, timeout: timeout);

  testWidgets('ticket SUNAT: bloqueado y desbloqueado', (t) async {
    await _runMatrix(
      t,
      'sunat bloqueado',
      (_) async => const SunatPrintSettingsScreen(),
    );
    await _runMatrix(
      t,
      'sunat desbloqueado',
      (_) async => const SunatPrintSettingsScreen(),
      prefs: {RedPosLicenseStore.playEntitlementKey: true},
    );
  }, timeout: timeout);

  testWidgets('ayuda, datos y privacidad, legales', (t) async {
    await _runMatrix(
      t,
      'ayuda',
      (_) async => HelpScreen(store: PrinterStore()),
    );
    await _runMatrix(
      t,
      'datos y privacidad',
      (_) async => PrivacyDataScreen(store: PrinterStore()),
    );
    await _runMatrix(
      t,
      'borrar datos locales',
      (_) async => PrivacyDataScreen(store: PrinterStore()),
      after: (t) async {
        await _tap(t, find.text('Borrar datos locales'));
        await _tap(t, find.text('Cancelar'));
      },
    );
    await _runMatrix(
      t,
      'términos',
      (_) async => const LegalScreen.terms(),
    );
    await _runMatrix(
      t,
      'privacidad',
      (_) async => const LegalScreen.privacy(),
    );
  }, timeout: timeout);

  testWidgets('suscripción', (t) async {
    await _runMatrix(
      t,
      'suscripción',
      (_) async => RedPosSubscribeScreen(store: PrinterStore()),
    );
  }, timeout: timeout);

  testWidgets('tickets propios: lista, editor y vista previa', (t) async {
    late CustomTicketStore store;
    late String templateId;
    Future<void> seed() async {
      await _seedPrinters(2);
      store = CustomTicketStore();
      final a = await store.create(name: 'Menú del día');
      templateId = a.id;
      await store.save(a.copyWith(
        companyName: 'RESTAURANTE EL SABOR',
        showQr: true,
        lines: const [
          CustomTicketLine(
            type: CustomTicketLineType.item,
            text: 'Lomo saltado con papas y arroz de la casa',
            qty: '2',
            unitPrice: '18.00',
            amount: '36.00',
          ),
          CustomTicketLine(
            type: CustomTicketLineType.text,
            text: 'Gracias por su visita',
            center: true,
          ),
        ],
        showTotals: true,
      ));
      await store.create(name: 'Recibo simple');
    }

    final prefs = <String, Object>{
      RedPosLicenseStore.playEntitlementKey: true,
    };
    await _runMatrix(
      t,
      'tickets lista',
      (_) async => CustomTicketsListScreen(
        printerStore: PrinterStore(),
        printService: PrintService(),
        store: store,
      ),
      prefs: prefs,
      seed: seed,
    );
    await _runMatrix(
      t,
      'tickets editor',
      (_) async => CustomTicketEditScreen(
        store: store,
        templateId: templateId,
        printerStore: PrinterStore(),
        printService: PrintService(),
      ),
      prefs: prefs,
      seed: seed,
    );
    await _runMatrix(
      t,
      'tickets vista previa',
      (t) async {
        final loaded = (await t.runAsync(() => store.loadById(templateId)))!;
        return CustomTicketPreviewScreen(
          template: loaded,
          printerStore: PrinterStore(),
          printService: PrintService(),
        );
      },
      prefs: prefs,
      seed: seed,
    );
  }, timeout: timeout);
}
