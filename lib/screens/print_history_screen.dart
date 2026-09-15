import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../l10n/app_lang.dart';
import '../models/print_job_record.dart';
import '../models/saved_printer.dart';
import '../services/print_history_store.dart';
import '../widgets/boleta_page.dart';

class PrintHistoryScreen extends StatefulWidget {
  const PrintHistoryScreen({
    super.key,
    required this.history,
    this.printer,
  });

  final PrintHistoryStore history;
  final SavedPrinter? printer;

  @override
  State<PrintHistoryScreen> createState() => _PrintHistoryScreenState();
}

class _PrintHistoryScreenState extends State<PrintHistoryScreen> {
  List<PrintJobRecord> _jobs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final jobs = await widget.history.loadAll(printerId: widget.printer?.id);
    if (!mounted) return;
    setState(() {
      _jobs = jobs;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final loc = L.of(ctx);
        return AlertDialog(
          title: Text(loc('Borrar historial', 'Clear history')),
          content: Text(
            widget.printer == null
                ? loc(
                    '¿Borrar todo el historial de impresión?',
                    'Clear all print history?',
                  )
                : loc(
                    '¿Borrar el historial de "${widget.printer!.name}"?',
                    'Clear history for "${widget.printer!.name}"?',
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc('Cancelar', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(loc('Borrar', 'Clear')),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await widget.history.clear(printerId: widget.printer?.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final title = widget.printer == null
        ? l('Historial de impresión', 'Print history')
        : l(
            'Historial · ${widget.printer!.name}',
            'History · ${widget.printer!.name}',
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: l('Borrar historial', 'Clear history'),
            onPressed: _jobs.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : BoletaPage(
              child: _jobs.isEmpty
                  ? Center(
                      child: Text(
                        l(
                          'Sin trabajos de impresión todavía.',
                          'No print jobs yet.',
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      scrollCacheExtent: const ScrollCacheExtent.pixels(280),
                      itemCount: _jobs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final j = _jobs[index];
                        final icon = switch (j.status) {
                          PrintJobStatus.success => Icons.check_circle,
                          PrintJobStatus.failed => Icons.error,
                          PrintJobStatus.queued => Icons.hourglass_bottom,
                        };
                        final color = switch (j.status) {
                          PrintJobStatus.success => Colors.green,
                          PrintJobStatus.failed => Colors.red,
                          PrintJobStatus.queued => Colors.orange,
                        };
                        return Card(
                          child: RepaintBoundary(
                            child: ListTile(
                              leading: Icon(icon, color: color),
                              title: Text(j.title),
                              subtitle: Text(
                                '${j.printerName}\n'
                                '${j.status.label} · ${j.source} · '
                                '${j.createdAt.toLocal()}',
                              ),
                              isThreeLine: true,
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
