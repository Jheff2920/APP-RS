import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../brand.dart';
import '../models/print_job_record.dart';
import '../models/saved_printer.dart';
import '../widgets/print_status_dialog.dart';
import 'escpos_pdf_print.dart';
import 'escpos_test_page.dart';
import 'drawer_wait.dart';
import 'print_history_store.dart';
import 'print_timing.dart';
import 'printer_permissions.dart';
import 'sunat/sunat_escpos_print.dart';
import 'sunat/sunat_ubl_parser.dart';
import 'sunat/sunat_xml_source.dart';
import 'transports/printer_transport.dart';
import 'transports/printer_transport_factory.dart';
import 'usb_printer_channel.dart';
import 'redpos/redpos_ad_escpos.dart';
import 'redpos/redpos_license.dart';

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

  /// Imprime un archivo compartido (PDF, imagen o XML SUNAT).
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
        if (await _isSunatXml(filePath) || lower.endsWith('.zip')) {
          return _buildSunatTicket(printer, filePath);
        }
        throw PrinterTransportException(
          'Formato no soportado. Usa PDF, imagen (PNG/JPG) o XML SUNAT.',
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
      final bytesFuture = timing.measure(
        'prepare',
        () => buildBytes(timing).timeout(
          const Duration(seconds: 90),
          onTimeout: () => throw PrinterTransportException(
            'Tiempo agotado preparando el ticket (PDF).',
          ),
        ),
      );
      final connectFuture = timing.measure(
        'connect',
        () => transport.connect(printer).timeout(
              const Duration(seconds: 45),
              onTimeout: () => throw PrinterTransportException(
                'No se pudo conectar con la impresora (tiempo agotado).',
              ),
            ),
      );
      final bytes = await bytesFuture;
      byteCount = bytes.length;
      final adsFree = await RedPosLicenseStore.instance.isAdsFree();
      final payload = RedPosAdEscPos.maybeWrap(
        bytes,
        printer: printer,
        adsFree: adsFree,
      );
      byteCount = payload.length;
      phase(PrintPhase.connecting);
      await paint();
      await connectFuture;

      phase(PrintPhase.sending);
      await paint();
      await timing.measure(
        'write',
        () => transport.writeBytes(payload),
        fields: {'bytes': payload.length},
      );

      final kick = printer.cashDrawer.kickBytes(
        usb: printer.type == PrinterLinkType.usb,
      );
      if (kick.isNotEmpty) {
        await Future<void>.delayed(
          DrawerWait.forPrinter(printer, bytes.length),
        );
        await timing.measure('drawer', () async {
          try {
            if (printer.type == PrinterLinkType.usb) {
              final gpio = await UsbPrinterChannel.openCashBox();
              if (gpio) return;
            }
            await transport.writeBytes(kick);
          } catch (_) {
            // El ticket ya salió; la gaveta no debe marcar el trabajo como fallido.
          }
        });
      }

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

  static Future<List<int>> _buildSunatTicket(
    SavedPrinter printer,
    String filePath,
  ) async {
    try {
      final xml = await SunatXmlSource.load(filePath);
      final ticket = SunatUblParser.parse(xml);
      return await SunatEscPosPrint.build(printer, ticket);
    } on SunatXmlException catch (e) {
      throw PrinterTransportException(e.message);
    } on FileSystemException {
      throw PrinterTransportException(
        'No se pudo leer el XML. En Android 10+ comparte el archivo '
        'o usa Abrir con ${AppBrand.name} (no la ruta de Descargas).',
      );
    } catch (e) {
      throw PrinterTransportException('No se pudo armar el ticket SUNAT: $e');
    }
  }

  static Future<bool> _isSunatXml(String path) async {
    if (path.toLowerCase().endsWith('.xml')) return true;
    if (path.toLowerCase().endsWith('.zip')) return true;
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      final raf = await file.open();
      try {
        final n = await raf.length() < 400 ? await raf.length() : 400;
        final bytes = await raf.read(n);
        final head = utf8.decode(bytes, allowMalformed: true).trimLeft();
        return head.startsWith('<?xml') ||
            head.startsWith('PK') ||
            head.contains('<Invoice') ||
            head.contains('<CreditNote') ||
            head.contains('<DebitNote') ||
            head.contains('<DespatchAdvice') ||
            head.contains('<Retention') ||
            head.contains('<Perception');
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
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
