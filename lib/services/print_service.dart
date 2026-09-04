import 'dart:async';

import 'package:path/path.dart' as p;

import '../models/print_job_record.dart';
import '../models/saved_printer.dart';
import '../widgets/print_status_dialog.dart';
import 'escpos_pdf_print.dart';
import 'escpos_test_page.dart';
import 'print_history_store.dart';
import 'printer_permissions.dart';
import 'transports/printer_transport.dart';
import 'transports/printer_transport_factory.dart';

class PrintService {
  PrintService({PrintHistoryStore? history})
      : _history = history ?? PrintHistoryStore();

  final PrintHistoryStore _history;

  PrintHistoryStore get history => _history;

  Future<void> printTestPage(
    SavedPrinter printer, {
    void Function(PrintPhase phase)? onPhase,
  }) async {
    await _runJob(
      printer: printer,
      title: 'Pagina de prueba',
      source: 'test',
      onPhase: onPhase,
      buildBytes: () => EscPosTestPage.build(printer),
    );
  }

  /// Imprime un archivo compartido (PDF o imagen).
  Future<void> printSharedFile({
    required SavedPrinter printer,
    required String filePath,
    void Function(PrintPhase phase)? onPhase,
    String source = 'share',
    bool requestPermissions = true,
  }) async {
    final name = p.basename(filePath);
    final lower = filePath.toLowerCase();

    await _runJob(
      printer: printer,
      title: name,
      source: source,
      onPhase: onPhase,
      requestPermissions: requestPermissions,
      buildBytes: () async {
        if (lower.endsWith('.pdf')) {
          return EscPosPdfPrint.build(printer, filePath: filePath);
        }
        if (_isImage(lower)) {
          return EscPosPdfPrint.buildImageFile(printer, filePath: filePath);
        }
        throw PrinterTransportException(
          'Formato no soportado aun. Usa PDF o imagen (PNG/JPG).',
        );
      },
    );
  }

  Future<void> _runJob({
    required SavedPrinter printer,
    required String title,
    required String source,
    required Future<List<int>> Function() buildBytes,
    void Function(PrintPhase phase)? onPhase,
    bool requestPermissions = true,
  }) async {
    void phase(PrintPhase p) => onPhase?.call(p);

    Future<void> paint() async {
      await Future<void>.delayed(Duration.zero);
    }

    if (requestPermissions && printer.type == PrinterLinkType.bluetooth) {
      final ok = await PrinterPermissions.ensureBluetooth();
      if (!ok) {
        throw PrinterTransportException(
          'Faltan permisos de Bluetooth. Concedelos en Ajustes de la app.',
        );
      }
    }

    if (printer.address.trim().isEmpty) {
      throw PrinterTransportException('La direccion de la impresora esta vacia.');
    }

    final transport = PrinterTransportFactory.create(printer);
    try {
      phase(PrintPhase.preparing);
      await paint();
      final bytes = await buildBytes().timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw PrinterTransportException(
          'Tiempo agotado preparando el ticket (PDF).',
        ),
      );

      phase(PrintPhase.connecting);
      await paint();
      await transport.connect(printer).timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw PrinterTransportException(
          'No se pudo conectar con la impresora (tiempo agotado).',
        ),
      );

      phase(PrintPhase.sending);
      await paint();
      await transport.writeBytes(bytes);

      phase(PrintPhase.printing);
      await paint();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      await _history.add(
        title: title,
        printerId: printer.id,
        printerName: printer.name,
        status: PrintJobStatus.success,
        source: source,
      );
    } catch (e) {
      await _history.add(
        title: title,
        printerId: printer.id,
        printerName: printer.name,
        status: PrintJobStatus.failed,
        source: source,
        error: e.toString(),
      );
      rethrow;
    } finally {
      await transport.disconnect();
    }
  }

  static bool _isImage(String path) {
    return path.endsWith('.png') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif');
  }
}
