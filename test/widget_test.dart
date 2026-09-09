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
    expect(find.text('Boleta Print'), findsOneWidget);
    expect(find.textContaining('WiFi / Red'), findsOneWidget);
    expect(find.text('Abrir archivo'), findsOneWidget);
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
