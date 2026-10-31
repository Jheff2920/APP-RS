import 'dart:ui' show Locale, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

import 'package:hello_world_app/app.dart';
import 'package:hello_world_app/platform_caps.dart';
import 'package:hello_world_app/services/print_service.dart';
import 'package:hello_world_app/services/printer_store.dart';
import 'package:hello_world_app/services/redpos/redpos_license.dart';

Future<void> _settleApp(WidgetTester tester) async {
  // App startup synchronizes the catalog and hydrates the license asynchronously.
  for (var i = 0; i < 10; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _UnavailableStore extends InAppPurchasePlatform {
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();
  @override
  Future<bool> isAvailable() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Initialize the facade before replacing its platform implementation.
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    InAppPurchase.instance;
    debugDefaultTargetPlatformOverride = previousPlatform;
    InAppPurchasePlatform.instance = _UnavailableStore();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
        const EventChannel('receive_sharing_intent/events-media'),
        MockStreamHandler.inline(onListen: (_, __) {}));
    messenger.setMockMethodCallHandler(
        const MethodChannel('receive_sharing_intent/messages'),
        (call) async => call.method == 'getInitialMedia' ? '[]' : null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (call) async => call.method == 'requestPermissions' ? <int, int>{} : 1);
    messenger.setMockMethodCallHandler(
        const MethodChannel('boleta_print/printers_prefs'),
        (call) async => null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('boleta_print/system_print_ui'),
        (call) async => null);
    SharedPreferences.setMockInitialValues({});
    RedPosLicenseStore.instance
        .resetForTest(prefs: await SharedPreferences.getInstance());
  });

  testWidgets('Shows empty printers state', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.localeTestValue = const Locale('es');
    tester.platformDispatcher.localesTestValue = const [Locale('es')];
    addTearDown(() {
      tester.platformDispatcher.clearLocaleTestValue();
      tester.platformDispatcher.clearLocalesTestValue();
    });
    final store = PrinterStore();
    final printService = PrintService();
    await tester.pumpWidget(
      BoletaPrintApp(store: store, printService: printService),
    );
    await _settleApp(tester);
    expect(find.textContaining('Sin impresoras'), findsOneWidget);
    expect(find.text('RedPOS Service'), findsOneWidget);
    expect(find.textContaining('WiFi / Red'), findsOneWidget);
    expect(find.text('Abrir archivo'), findsOneWidget);
    await tester.tap(find.byTooltip('Ayuda y legal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ayuda y soporte'));
    await tester.pumpAndSettle();
    expect(find.text('Ayuda y soporte'), findsWidgets);
    expect(find.text('jcefe.2920@gmail.com'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Datos y privacidad'),
      120,
    );
    expect(find.text('Datos y privacidad'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Términos y condiciones'),
      80,
    );
    expect(find.text('Términos y condiciones'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Política de privacidad'),
      80,
    );
    expect(find.text('Política de privacidad'), findsOneWidget);
  });

  testWidgets('Empty printers state does not overflow with keyboard',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.localeTestValue = const Locale('es');
    tester.platformDispatcher.localesTestValue = const [Locale('es')];
    addTearDown(() {
      tester.platformDispatcher.clearLocaleTestValue();
      tester.platformDispatcher.clearLocalesTestValue();
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 360);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });
    await tester.pumpWidget(
      BoletaPrintApp(store: PrinterStore(), printService: PrintService()),
    );
    await _settleApp(tester);
    expect(find.textContaining('Sin impresoras'), findsOneWidget);
    expect(find.text('Abrir archivo'), findsWidgets);
  });

  test('PlatformCaps USB and PrintService are Android-only', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(PlatformCaps.supportsUsb, isTrue);
    expect(PlatformCaps.supportsSystemPrint, isTrue);
    expect(PlatformCaps.prefersNetworkDefault, isFalse);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(PlatformCaps.supportsUsb, isFalse);
    expect(PlatformCaps.supportsSystemPrint, isFalse);
    expect(PlatformCaps.prefersNetworkDefault, isTrue);
    expect(PlatformCaps.usesShareIntent, isFalse);

    debugDefaultTargetPlatformOverride = null;
  });
}
