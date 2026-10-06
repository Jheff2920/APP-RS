import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../models/print_job_record.dart';
import '../models/saved_printer.dart';
import '../services/print_history_store.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';

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
              style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
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
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: EmptyMessage(
                      icon: Icons.history_rounded,
                      title: l('Aún no hay impresiones', 'No prints yet'),
                      body: l(
                        'Aquí aparecerá cada ticket que imprimas, con la hora '
                            'y si salió bien.',
                        'Every ticket you print will show up here, with the '
                            'time and whether it worked.',
                      ),
                    ),
                  ),
                )
              : _groupedList(context),
    );
  }

  Widget _groupedList(BuildContext context) {
    final days = <String, List<PrintJobRecord>>{};
    for (final j in _jobs) {
      days.putIfAbsent(dayHeading(context, j.createdAt), () => []).add(j);
    }
    return PageList(
      children: [
        for (final entry in days.entries) ...[
          SectionLabel(entry.key),
          SectionGroup(
            dividerIndent: 68,
            children: [
              for (final j in entry.value)
                RepaintBoundary(child: _JobRow(job: j)),
            ],
          ),
        ],
      ],
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.job});

  final PrintJobRecord job;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tt = Theme.of(context).textTheme;
    final (icon, color) = switch (job.status) {
      PrintJobStatus.success => (Icons.check_rounded, AppColors.ok),
      PrintJobStatus.failed => (Icons.close_rounded, const Color(0xFFB3261E)),
      PrintJobStatus.queued => (Icons.schedule_rounded, AppColors.warn),
    };
    final source = switch (job.source) {
      'share' => l('Archivo', 'File'),
      'test' => l('Prueba', 'Test'),
      'custom_ticket' => l('Ticket propio', 'Custom ticket'),
      'system' || 'system-headless' => l('Imprimir de Android', 'Android print'),
      _ => l('App', 'App'),
    };
    final error = job.error?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, color: color, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        job.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      shortTime(context, job.createdAt),
                      style: tt.bodySmall?.copyWith(
                        color: AppColors.inkSoft,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  job.printerName.isEmpty
                      ? '${job.status.label}, $source'
                      : '${job.printerName}, $source',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
                if (job.status == PrintJobStatus.failed &&
                    error != null &&
                    error.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    error,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: color),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
