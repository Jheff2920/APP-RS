import 'package:flutter/material.dart';

import 'app.dart';
import 'services/print_service.dart';
import 'services/printer_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = PrinterStore();
  final printService = PrintService();
  runApp(BoletaPrintApp(store: store, printService: printService));
}
