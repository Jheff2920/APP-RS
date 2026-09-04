import 'package:flutter/material.dart';

import '../models/print_job_record.dart';
import '../models/saved_printer.dart';
import '../services/print_history_store.dart';

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
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar historial'),
        content: Text(
          widget.printer == null
              ? '¿Borrar todo el historial de impresion?'
              : '¿Borrar el historial de "${widget.printer!.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.history.clear(printerId: widget.printer?.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.printer == null
        ? 'Historial de impresion'
        : 'Historial · ${widget.printer!.name}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Borrar historial',
            onPressed: _jobs.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
              ? const Center(
                  child: Text('Sin trabajos de impresion todavia.'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
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
                    );
                  },
                ),
    );
  }
}
