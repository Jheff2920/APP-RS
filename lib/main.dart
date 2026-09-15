import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'services/print_service.dart';
import 'services/printer_store.dart';
import 'services/redpos/redpos_play_billing.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Play Billing exige escuchar purchaseStream antes de mostrar la UI.
  unawaited(RedPosPlayBilling.instance.start());
  final store = PrinterStore();
  final printService = PrintService();
  runApp(BoletaPrintApp(store: store, printService: printService));
}
