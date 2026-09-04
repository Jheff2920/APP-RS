import 'dart:async';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'screens/print_history_screen.dart';
import 'screens/printer_list_screen.dart';
import 'screens/share_print_screen.dart';
import 'services/print_service.dart';
import 'services/printer_store.dart';
import 'system_print_main.dart';

class BoletaPrintApp extends StatefulWidget {
  const BoletaPrintApp({
    super.key,
    required this.store,
    required this.printService,
  });

  final PrinterStore store;
  final PrintService printService;

  @override
  State<BoletaPrintApp> createState() => _BoletaPrintAppState();
}

class _BoletaPrintAppState extends State<BoletaPrintApp> {
  final _navKey = GlobalKey<NavigatorState>();
  StreamSubscription? _shareSub;
  bool _handlingShare = false;

  @override
  void initState() {
    super.initState();
    SystemPrintUiHandler.instance.bind(
      store: widget.store,
      printService: widget.printService,
      navKey: _navKey,
    );
    // Re-sincroniza prefs nativas (impresoras ya guardadas antes del PrintService).
    unawaited(widget.store.syncNativePrefs());
    _listenShares();
  }

  void _listenShares() {
    // App ya abierta.
    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) => _onShared(files),
      onError: (e) => debugPrint('share stream error: $e'),
    );

    // App abierta desde Compartir / cerrada.
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _onShared(files);
      ReceiveSharingIntent.instance.reset();
    });
  }

  Future<void> _onShared(List<SharedMediaFile> files) async {
    if (files.isEmpty || _handlingShare) return;
    final file = files.first;
    final path = file.path;
    if (path.isEmpty) return;

    _handlingShare = true;
    try {
      // Esperar a que el navigator este listo.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final nav = _navKey.currentState;
      if (nav == null) return;

      await nav.push(
        MaterialPageRoute(
          builder: (_) => SharePrintScreen(
            filePath: path,
            printerStore: widget.store,
            printService: widget.printService,
          ),
        ),
      );
    } finally {
      _handlingShare = false;
      ReceiveSharingIntent.instance.reset();
    }
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navKey,
      title: 'Boleta Print',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: PrinterListScreen(
        store: widget.store,
        printService: widget.printService,
      ),
      routes: {
        '/history': (_) => PrintHistoryScreen(
              history: widget.printService.history,
            ),
      },
    );
  }
}
