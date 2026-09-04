import 'dart:async';

import 'package:path/path.dart' as p;

import '../models/print_job_record.dart';
import '../models/saved_printer.dart';
import '../widgets/print_status_dialog.dart';
import 'escpos_pdf_print.dart';
import 'escpos_test_page.dart';
import 'print_history_store.dart';
import 'print_timing.dart';
import 'printer_permissions.dart';
import 'transports/printer_transport.dart';
import 'transports/printer_transport_factory.dart';

class PrintService {
  PrintService({PrintHistoryStore? history})
      : _history = history ?? PrintHistoryStore();

  final PrintHistoryStore _history;
  Future<void> _historyWrites = Future<void>.value();

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
      buildBytes: (_) => EscPosTestPage.build(printer),
    );
  }

  /// Imprime un archivo compartido (PDF o imagen).
  Future<void> printSharedFile({
    required SavedPrinter printer,
    required String filePath,
    void Function(PrintPhase phase)? onPhase,
    String source = 'share',
    bool requestPermissions = true,
    String? jobId,
  }) async {
    final name = p.basename(filePath);
    final lower = filePath.toLowerCase();

    await _runJob(
      printer: printer,
      title: name,
      source: source,
      jobId: jobId,
      onPhase: onPhase,
      requestPermissions: requestPermissions,
      buildBytes: (timing) async {
        if (lower.endsWith('.pdf')) {
          return EscPosPdfPrint.build(
            printer,
            filePath: filePath,
            timing: timing,
          );
        }
        if (_isImage(lower)) {
          return EscPosPdfPrint.buildImageFile(
            printer,
            filePath: filePath,
            timing: timing,
          );
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
    required Future<List<int>> Function(PrintTiming timing) buildBytes,
    String? jobId,
    void Function(PrintPhase phase)? onPhase,
    bool requestPermissions = true,
  }) async {
    void phase(PrintPhase p) => onPhase?.call(p);

    Future<void> paint() async {
      await Future<void>.delayed(Duration.zero);
    }

    final timing = PrintTiming.forPrinter(
      jobId: jobId,
      source: source,
      printer: printer,
    );
    final transport = PrinterTransportFactory.create(printer);
    var succeeded = false;
    int? byteCount;
    try {
      if (requestPermissions && printer.type == PrinterLinkType.bluetooth) {
        final ok = await PrinterPermissions.ensureBluetooth();
        if (!ok) {
          throw PrinterTransportException(
            'Faltan permisos de Bluetooth. Concedelos en Ajustes de la app.',
          );
        }
      }

      if (printer.address.trim().isEmpty) {
        throw PrinterTransportException(
          'La direccion de la impresora esta vacia.',
        );
      }

      phase(PrintPhase.preparing);
      await paint();
      final bytes = await timing.measure(
        'prepare',
        () => buildBytes(timing).timeout(
          const Duration(seconds: 90),
          onTimeout: () => throw PrinterTransportException(
            'Tiempo agotado preparando el ticket (PDF).',
          ),
        ),
      );
      byteCount = bytes.length;

      phase(PrintPhase.connecting);
      await paint();
      await timing.measure(
        'connect',
        () => transport.connect(printer).timeout(
              const Duration(seconds: 45),
              onTimeout: () => throw PrinterTransportException(
                'No se pudo conectar con la impresora (tiempo agotado).',
              ),
            ),
      );

      phase(PrintPhase.sending);
      await paint();
      await timing.measure(
        'write',
        () => transport.writeBytes(bytes),
        fields: {'bytes': bytes.length},
      );

      phase(PrintPhase.printing);
      await paint();
      succeeded = true;
      _recordHistory(
        title: title,
        printer: printer,
        status: PrintJobStatus.success,
        source: source,
      );
    } catch (e) {
      timing.event('error', fields: {'error_type': e.runtimeType.toString()});
      _recordHistory(
        title: title,
        printer: printer,
        status: PrintJobStatus.failed,
        source: source,
        error: e.toString(),
      );
      rethrow;
    } finally {
      try {
        await timing.measure('disconnect', transport.disconnect);
      } finally {
        timing.finish(ok: succeeded, bytes: byteCount);
      }
    }
  }

  void _recordHistory({
    required String title,
    required SavedPrinter printer,
    required PrintJobStatus status,
    required String source,
    String? error,
  }) {
    // Serializar escrituras evita perder registros sin bloquear el cierre visual.
    _historyWrites = _historyWrites.then((_) async {
      try {
        await _history.add(
          title: title,
          printerId: printer.id,
          printerName: printer.name,
          status: status,
          source: source,
          error: error,
        );
      } catch (_) {
        // El historial no debe convertir una impresión enviada en un fallo.
      }
    });
  }

  static bool _isImage(String path) {
    return path.endsWith('.png') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif');
  }
}
