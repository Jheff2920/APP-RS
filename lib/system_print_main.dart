import 'dart:async';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'models/saved_printer.dart';
import 'services/escpos_pdf_print.dart';
import 'services/print_service.dart';
import 'services/printer_permissions.dart';
import 'services/printer_store.dart';
import 'services/transports/printer_transport.dart';
import 'widgets/print_status_dialog.dart';

/// Entrypoint headless: PrintService rasteriza PDF → archivo `.bin` ESC/POS.
@pragma('vm:entry-point')
void systemPrintMain() {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('boleta_print/system_print');
  final store = PrinterStore();

  channel.setMethodCallHandler((call) async {
    if (call.method != 'rasterize') {
      throw PlatformException(code: 'unsupported', message: call.method);
    }
    final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
    final filePath = args['filePath'] as String? ?? '';
    final printerId = args['printerId'] as String? ?? '';
    if (filePath.isEmpty) {
      throw PlatformException(code: 'bad_args', message: 'filePath vacio');
    }

    final printer = PrinterStore.findByIdOrDefault(
      await store.loadAll(),
      printerId,
    );
    if (printer == null) {
      throw PlatformException(
        code: 'no_printer',
        message: 'No hay impresoras vinculadas',
      );
    }

    final lower = filePath.toLowerCase();
    final bytes = lower.endsWith('.pdf')
        ? await EscPosPdfPrint.build(printer, filePath: filePath)
        : await EscPosPdfPrint.buildImageFile(printer, filePath: filePath);

    final dir = await getTemporaryDirectory();
    final out = File(
      '${dir.path}/escpos_${DateTime.now().millisecondsSinceEpoch}.bin',
    );
    await out.writeAsBytes(bytes, flush: true);
    return out.path;
  });

  unawaited(channel.invokeMethod<void>('engineReady'));
}

/// Fallback UI si no hay permiso de overlay (abre MainActivity).
class SystemPrintUiHandler {
  SystemPrintUiHandler._();

  static final SystemPrintUiHandler instance = SystemPrintUiHandler._();

  static const _channel = MethodChannel('boleta_print/system_print_ui');

  PrinterStore? _store;
  PrintService? _printService;
  GlobalKey<NavigatorState>? _navKey;
  bool _attached = false;
  bool _busy = false;
  String? _activeToken;

  void bind({
    required PrinterStore store,
    required PrintService printService,
    required GlobalKey<NavigatorState> navKey,
  }) {
    _store = store;
    _printService = printService;
    _navKey = navKey;
    _attach();
    unawaited(_drainPending());
  }

  void _attach() {
    if (_attached) return;
    _attached = true;
    _channel.setMethodCallHandler(_onCall);
  }

  Future<void> _drainPending() async {
    try {
      final pending = await _channel.invokeMethod<Map>('takePendingSystemPrint');
      if (pending == null) return;
      await _runSystemPrint(Map<String, dynamic>.from(pending));
    } catch (e) {
      debugPrint('takePendingSystemPrint: $e');
    }
  }

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method == 'runSystemPrint') {
      final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
      unawaited(_runSystemPrint(args));
      return null;
    }
    throw PlatformException(code: 'unsupported', message: call.method);
  }

  Future<void> _runSystemPrint(Map<String, dynamic> args) async {
    final token = args['token'] as String? ?? '';
    if (_busy || (token.isNotEmpty && token == _activeToken)) return;
    _busy = true;
    _activeToken = token.isEmpty ? null : token;
    final rawPath = args['filePath'] as String? ?? '';
    final printerId = args['printerId'] as String? ?? '';

    try {
      if (rawPath.isEmpty) {
        throw PrinterTransportException('Archivo vacio');
      }
      final store = _store;
      final printService = _printService;
      if (store == null || printService == null) {
        throw PrinterTransportException('App no lista');
      }

      final printer = PrinterStore.findByIdOrDefault(
        await store.loadAll(),
        printerId,
      );
      if (printer == null) {
        throw PrinterTransportException('No hay impresoras vinculadas');
      }

      final src = File(rawPath);
      if (!await src.exists()) {
        throw PrinterTransportException('No se encontro el PDF');
      }
      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/boleta_ui_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await src.copy(filePath);

      if (printer.type == PrinterLinkType.bluetooth) {
        final ok = await PrinterPermissions.ensureBluetooth();
        if (!ok) {
          throw PrinterTransportException('Faltan permisos de Bluetooth');
        }
      }

      BuildContext? ctx;
      for (var i = 0; i < 40; i++) {
        ctx = _navKey?.currentContext;
        if (ctx != null && ctx.mounted) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final context = ctx;
      if (context != null && context.mounted) {
        await runWithPrintStatusDialog(
          context: context,
          printerName: printer.name,
          job: (setPhase) => printService.printSharedFile(
            printer: printer,
            filePath: filePath,
            source: 'system',
            onPhase: setPhase,
            requestPermissions: false,
          ),
        );
      } else {
        await printService.printSharedFile(
          printer: printer,
          filePath: filePath,
          source: 'system',
          requestPermissions: false,
        );
      }

      await _notify(token: token, ok: true);
    } on PrinterTransportException catch (e) {
      await _notify(token: token, ok: false, message: e.message);
    } catch (e) {
      await _notify(token: token, ok: false, message: '$e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _notify({
    required String token,
    required bool ok,
    String? message,
  }) async {
    try {
      await _channel.invokeMethod('notifyPrintResult', {
        'token': token,
        'ok': ok,
        'message': message,
      });
    } catch (e) {
      debugPrint('notifyPrintResult: $e');
    }
  }
}
