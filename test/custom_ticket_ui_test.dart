import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hello_world_app/screens/custom_ticket_edit_screen.dart';
import 'package:hello_world_app/screens/custom_tickets_list_screen.dart';
import 'package:hello_world_app/services/custom_ticket/custom_ticket.dart';
import 'package:hello_world_app/services/custom_ticket/custom_ticket_store.dart';
import 'package:hello_world_app/services/print_service.dart';
import 'package:hello_world_app/services/printer_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('edit screen has no title field', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await setView(tester);

    final store = CustomTicketStore();
    final created = await store.create(name: 'Sin titulo');
    await store.save(
      created.copyWith(
        title: 'OLD TITLE',
        companyName: 'MI TIENDA',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CustomTicketEditScreen(
          store: store,
          templateId: created.id,
          printerStore: PrinterStore(),
          printService: PrintService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('template-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('company-name')), findsOneWidget);
    expect(find.text('Título'), findsNothing);
    expect(find.text('Title'), findsNothing);
    expect(find.text('Se imprime centrado y en negrita.'), findsNothing);
    expect(find.text('Printed centered and bold.'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) {
          if (widget is! TextField) return false;
          final label = widget.decoration?.labelText;
          return label == 'Título' || label == 'Title';
        },
        skipOffstage: false,
      ),
      findsNothing,
    );
  });

  testWidgets('edit save stores company name as title', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await setView(tester);

    final store = CustomTicketStore();
    final created = await store.create(name: 'Persist');
    await store.save(created.copyWith(title: 'OLD TITLE'));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => CustomTicketEditScreen(
                      store: store,
                      templateId: created.id,
                      printerStore: PrinterStore(),
                      printService: PrintService(),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final company = find.byKey(const ValueKey('company-name'));
    expect(company, findsOneWidget);
    await tester.ensureVisible(company);
    await tester.enterText(company, 'BODEGA CENTRAL');
    await tester.pump();

    final save = find.byType(FilledButton);
    expect(save, findsWidgets);
    await tester.tap(save.last);
    await tester.pumpAndSettle();

    final loaded = await store.loadById(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.companyName, 'BODEGA CENTRAL');
    expect(loaded.title, 'BODEGA CENTRAL');
  });

  testWidgets('list shows company name instead of title', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await setView(tester);

    final store = CustomTicketStore();
    final created = await store.create(name: 'Plantilla 1');
    await store.save(
      created.copyWith(
        title: 'OLD TITLE',
        companyName: 'MI TIENDA SAC',
        lines: const [
          CustomTicketLine(
            type: CustomTicketLineType.item,
            text: 'Cafe',
            qty: '1',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CustomTicketsListScreen(
          printerStore: PrinterStore(),
          printService: PrintService(),
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plantilla 1'), findsOneWidget);
    expect(find.textContaining('MI TIENDA SAC'), findsOneWidget);
    expect(find.textContaining('OLD TITLE'), findsNothing);
  });

  testWidgets('Incluir IGV toggle hides tax fields and persists false',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await setView(tester);

    final store = CustomTicketStore();
    final created = await store.create(name: 'Sin IGV biz');
    await store.save(
      created.copyWith(
        lines: const [
          CustomTicketLine(
            type: CustomTicketLineType.item,
            text: 'Servicio',
            qty: '1',
            unitPrice: '100',
            amount: '100',
          ),
        ],
        showTotals: true,
        includeIgv: true,
        subtotal: '100.00',
        tax: '18.00',
        total: '118.00',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => CustomTicketEditScreen(
                      store: store,
                      templateId: created.id,
                      printerStore: PrinterStore(),
                      printService: PrintService(),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final igvToggle = find.textContaining('Incluir IGV').evaluate().isNotEmpty
        ? find.textContaining('Incluir IGV')
        : find.textContaining('Include IGV');
    expect(igvToggle, findsOneWidget);
    expect(
      find.text('Op. Gravada').evaluate().isNotEmpty ||
          find.text('Taxable ops').evaluate().isNotEmpty,
      isTrue,
    );

    await tester.ensureVisible(igvToggle);
    await tester.tap(igvToggle);
    await tester.pumpAndSettle();

    expect(find.text('Op. Gravada'), findsNothing);
    expect(find.text('Taxable ops'), findsNothing);
    expect(find.text('IGV 18%'), findsNothing);
    expect(find.text('VAT 18%'), findsNothing);
    expect(
      find.textContaining('Sin IGV').evaluate().isNotEmpty ||
          find.textContaining('No IGV').evaluate().isNotEmpty,
      isTrue,
    );

    final save = find.byType(FilledButton);
    await tester.ensureVisible(save.last);
    await tester.tap(save.last);
    await tester.pumpAndSettle();

    final loaded = await store.loadById(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.includeIgv, isFalse);
    expect(loaded.total, '100.00');
    expect(loaded.tax, isEmpty);
    expect(loaded.subtotal, isEmpty);
  });
}
