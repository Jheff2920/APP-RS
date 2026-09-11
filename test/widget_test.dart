import 'dart:ui' show FakeViewPadding, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hello_world_app/app.dart';
import 'package:hello_world_app/platform_caps.dart';
import 'package:hello_world_app/services/print_service.dart';
import 'package:hello_world_app/services/printer_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Shows empty printers state', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = PrinterStore();
    final printService = PrintService();
    await tester.pumpWidget(
      BoletaPrintApp(store: store, printService: printService),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
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
      find.text('Términos y condiciones'),
      120,
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
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
