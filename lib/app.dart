import 'dart:async';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'platform_caps.dart';
import 'screens/print_history_screen.dart';
import 'screens/printer_list_screen.dart';
import 'screens/share_print_screen.dart';
import 'services/incoming_files.dart';
import 'services/print_service.dart';
import 'services/printer_store.dart';
import 'services/shared_incoming.dart';
import 'system_print_main.dart';
import 'theme.dart';

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
  StreamSubscription? _incomingSub;
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
    if (PlatformCaps.usesShareIntent) {
      _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (files) => _onShared(files),
        onError: (e) => debugPrint('share stream error: $e'),
      );
      ReceiveSharingIntent.instance.getInitialMedia().then((files) {
        _onShared(files);
        ReceiveSharingIntent.instance.reset();
      });
    }

    _incomingSub = IncomingFiles.stream.listen(_openSharedPath);
    unawaited(IncomingFiles.takePending().then((path) {
      if (path != null) unawaited(_openSharedPath(path));
    }));
  }

  Future<void> _onShared(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;
    final resolved = await _resolveSharedPath(files.first.path);
    if (resolved.isEmpty) return;
    await _openSharedPath(resolved);
  }

  Future<void> _openSharedPath(String path) async {
    if (path.isEmpty || _handlingShare) return;
    _handlingShare = true;
    try {
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
      if (PlatformCaps.usesShareIntent) {
        ReceiveSharingIntent.instance.reset();
      }
    }
  }

  Future<String> _resolveSharedPath(String sharedPath) async {
    final copied = await SharedIncoming.copyFromIntent();
    if (copied != null &&
        copied.isNotEmpty &&
        await SharedIncoming.isReadable(copied)) {
      return copied;
    }
    if (await SharedIncoming.isReadable(sharedPath)) return sharedPath;
    return copied ?? sharedPath;
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    _incomingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navKey,
      title: 'Boleta Print',
      theme: boletaPrintTheme,
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
