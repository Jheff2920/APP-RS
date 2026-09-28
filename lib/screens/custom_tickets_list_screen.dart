import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../services/custom_ticket/custom_ticket.dart';
import '../services/custom_ticket/custom_ticket_store.dart';
import '../services/print_service.dart';
import '../services/printer_store.dart';
import '../widgets/boleta_page.dart';
import 'custom_ticket_edit_screen.dart';
import 'custom_ticket_preview_screen.dart';

/// Lista de plantillas de tickets propios.
class CustomTicketsListScreen extends StatefulWidget {
  const CustomTicketsListScreen({
    super.key,
    required this.printerStore,
    required this.printService,
    this.store,
  });

  final PrinterStore printerStore;
  final PrintService printService;
  final CustomTicketStore? store;

  @override
  State<CustomTicketsListScreen> createState() =>
      _CustomTicketsListScreenState();
}

class _CustomTicketsListScreenState extends State<CustomTicketsListScreen> {
  late final CustomTicketStore _store = widget.store ?? CustomTicketStore();
  List<CustomTicketTemplate> _items = [];
  var _loading = true;
  var _creating = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final all = await _store.loadAll();
    if (!mounted) return;
    setState(() {
      _items = all;
      _loading = false;
    });
  }

  Future<void> _create() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final created = await _store.create();
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => CustomTicketEditScreen(
            store: _store,
            templateId: created.id,
            printerStore: widget.printerStore,
            printService: widget.printService,
          ),
        ),
      );
      await _reload();
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _openEdit(CustomTicketTemplate t) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CustomTicketEditScreen(
          store: _store,
          templateId: t.id,
          printerStore: widget.printerStore,
          printService: widget.printService,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _openPreview(CustomTicketTemplate t) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CustomTicketPreviewScreen(
          template: t,
          printerStore: widget.printerStore,
          printService: widget.printService,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(CustomTicketTemplate t) async {
    final l = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l('Eliminar plantilla', 'Delete template')),
        content: Text(
          l(
            '¿Eliminar "${t.name}"? Esta acción no se puede deshacer.',
            'Delete "${t.name}"? This cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l('Cancelar', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l('Eliminar', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _store.delete(t.id);
    await _reload();
  }

  Future<void> _duplicate(CustomTicketTemplate t) async {
    final copy = await _store.duplicate(t);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          L.of(context)(
              'Copia creada: ${copy.name}', 'Copy created: ${copy.name}'),
        ),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l('Tickets propios', 'Custom tickets')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating || _loading ? null : _create,
        icon: _creating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(l('Nueva', 'New')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : BoletaPage(
              child: _items.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 48),
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 56,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l(
                            'Aún no hay tickets propios.',
                            'No custom tickets yet.',
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l(
                            'Crea una plantilla con logo, líneas, '
                                'totales, QR o código de barras, y previsualízala '
                                'antes de imprimir.',
                            'Create a template with logo, lines, '
                                'totals, QR or barcode, and preview it before '
                                'printing.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final t = _items[index];
                        final subtitle = [
                          if (t.companyName.trim().isNotEmpty)
                            t.companyName.trim(),
                          '${t.lines.length} ${l('líneas', 'lines')}',
                          if (t.showQr) 'QR',
                          if (t.showBarcode) l('Barras', 'Barcode'),
                        ].join(' · ');
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                t.showLogo && t.logoBytes != null
                                    ? Icons.image
                                    : Icons.receipt_long,
                              ),
                            ),
                            title: Text(t.name),
                            subtitle: Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _openEdit(t),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'preview':
                                    _openPreview(t);
                                  case 'edit':
                                    _openEdit(t);
                                  case 'dup':
                                    _duplicate(t);
                                  case 'delete':
                                    _confirmDelete(t);
                                }
                              },
                              itemBuilder: (ctx) {
                                final loc = L.of(ctx);
                                return [
                                  PopupMenuItem(
                                    value: 'preview',
                                    child: Text(
                                      loc('Vista previa / Imprimir',
                                          'Preview / Print'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(loc('Editar', 'Edit')),
                                  ),
                                  PopupMenuItem(
                                    value: 'dup',
                                    child: Text(loc('Duplicar', 'Duplicate')),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(loc('Eliminar', 'Delete')),
                                  ),
                                ];
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
