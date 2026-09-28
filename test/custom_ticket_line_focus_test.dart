import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hello_world_app/screens/custom_ticket_edit_screen.dart';
import 'package:hello_world_app/services/custom_ticket/custom_ticket.dart';
import 'package:hello_world_app/services/custom_ticket/custom_ticket_store.dart';
import 'package:hello_world_app/services/print_service.dart';
import 'package:hello_world_app/services/printer_store.dart';

bool _fieldHasFocus(WidgetTester tester, Finder field) {
  final editable = find.descendant(
    of: field,
    matching: find.byType(EditableText),
  );
  final state = tester.state<EditableTextState>(editable);
  return state.widget.focusNode?.hasFocus ?? false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('editing PU and importe keeps focus in that field', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.localeTestValue = const Locale('es');
    tester.platformDispatcher.localesTestValue = const [Locale('es')];
    addTearDown(() {
      tester.platformDispatcher.clearLocaleTestValue();
      tester.platformDispatcher.clearLocalesTestValue();
    });

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = CustomTicketStore();
    final created = await store.create(name: 'Focus test');
    await store.save(
      created.copyWith(
        lines: const [
          CustomTicketLine(
            id: 'line-1',
            type: CustomTicketLineType.item,
            text: 'Cafe',
            qty: '1',
            unitPrice: '5.00',
            amount: '5.00',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        home: CustomTicketEditScreen(
          store: store,
          templateId: created.id,
          printerStore: PrinterStore(),
          printService: PrintService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pu = find.byKey(const ValueKey('pu-line-1'));
    final amt = find.byKey(const ValueKey('amt-line-1'));
    final desc = find.byKey(const ValueKey('desc-line-1'));
    expect(pu, findsOneWidget);
    expect(amt, findsOneWidget);
    expect(desc, findsOneWidget);

    await tester.ensureVisible(pu);
    await tester.pumpAndSettle();
    await tester.tap(pu);
    await tester.pump();
    await tester.enterText(pu, '7.5');
    await tester.pump();
    expect(_fieldHasFocus(tester, pu), isTrue);
    expect(_fieldHasFocus(tester, desc), isFalse);

    await tester.ensureVisible(amt);
    await tester.pumpAndSettle();
    await tester.tap(amt);
    await tester.pump();
    await tester.enterText(amt, '12');
    await tester.pump();
    expect(_fieldHasFocus(tester, amt), isTrue);
    expect(_fieldHasFocus(tester, desc), isFalse);
  });
}
