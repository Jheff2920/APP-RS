import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../services/custom_ticket/custom_ticket.dart';
import '../services/custom_ticket/custom_ticket_store.dart';
import '../services/print_service.dart';
import '../services/redpos/redpos_license.dart';
import '../services/printer_store.dart';
import '../theme.dart';
import '../widgets/redpos_paid_gate.dart';
import '../widgets/ui_kit.dart';
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
  var _unlocked = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final all = await _store.loadAll();
    final unlocked =
        await RedPosLicenseStore.instance.isAdsFree(reloadDisk: false);
    if (!mounted) return;
    setState(() {
      _items = all;
      _unlocked = unlocked;
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
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
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
    final title = l('Tickets propios', 'Custom tickets');

    if (!_loading && !_unlocked) {
      return RedPosPaidGatePage(
        title: title,
        store: widget.printerStore,
        onUnlocked: () => _reload(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating || _loading ? null : _create,
        icon: _creating
            ? const ButtonSpinner(color: Colors.white)
            : const Icon(Icons.add_rounded),
        label: Text(l('Nuevo ticket', 'New ticket')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: EmptyMessage(
                      icon: Icons.edit_note_rounded,
                      title: l('Aún no hay tickets propios.', 'No custom tickets yet.'),
                      body: l(
                        'Arma tu propio ticket con logo, productos, totales, '
                            'QR o código de barras. Lo ves antes de imprimir.',
                        'Build your own ticket with logo, products, totals, '
                            'QR or barcode. Preview it before printing.',
                      ),
                    ),
                  ),
                )
              : PageList(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    for (final t in _items) ...[
                      _TemplateCard(
                        template: t,
                        onOpen: () => _openEdit(t),
                        onPrint: () => _openPreview(t),
                        onMenu: (value) {
                          switch (value) {
                            case 'edit':
                              _openEdit(t);
                            case 'dup':
                              _duplicate(t);
                            case 'delete':
                              _confirmDelete(t);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onOpen,
    required this.onPrint,
    required this.onMenu,
  });

  final CustomTicketTemplate template;
  final VoidCallback onOpen;
  final VoidCallback onPrint;
  final ValueChanged<String> onMenu;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tt = Theme.of(context).textTheme;
    final t = template;
    final items = t.lines.length;
    final details = [
      items == 1 ? l('1 línea', '1 line') : l('$items líneas', '$items lines'),
      if (t.showQr) 'QR',
      if (t.showBarcode) l('código de barras', 'barcode'),
    ].join(', ');
    final hasLogo = t.showLogo && t.logoBytes != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasLogo
                    ? Container(
                        width: 48,
                        height: 48,
                        color: AppColors.background,
                        padding: const EdgeInsets.all(6),
                        child: Image.memory(t.logoBytes!, fit: BoxFit.contain),
                      )
                    : const IconTile(icon: Icons.receipt_outlined, size: 48),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if (t.companyName.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        t.companyName.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(color: AppColors.ink),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: l('Vista previa e imprimir', 'Preview and print'),
                onPressed: onPrint,
                icon: const Icon(Icons.print_outlined),
              ),
              PopupMenuButton<String>(
                tooltip: l('Opciones', 'Options'),
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: onMenu,
                itemBuilder: (ctx) {
                  final loc = L.of(ctx);
                  return [
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
                      child: Text(
                        loc('Eliminar', 'Delete'),
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
