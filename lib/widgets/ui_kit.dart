import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../models/saved_printer.dart';
import '../theme.dart';

/// Icono sobre fondo tintado del mismo color.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.color,
    this.size = 44,
  });

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, color: c, size: size * 0.52),
    );
  }
}

/// Título de un bloque de contenido, con acción opcional a la derecha.
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(4, 20, 4, 8),
  });

  final String text;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: tt.titleSmall?.copyWith(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Contenedor blanco que agrupa filas con separadores internos.
class SectionGroup extends StatelessWidget {
  const SectionGroup({
    super.key,
    required this.children,
    this.dividerIndent = 16,
  });

  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(Divider(height: 1, indent: dividerIndent));
      }
      items.add(children[i]);
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      ),
    );
  }
}

/// Bloque con padding interno para formularios dentro de un [SectionGroup].
class SectionBody extends StatelessWidget {
  const SectionBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Fila navegable: icono, título, subtítulo y chevron.
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.color,
    this.trailing,
    this.destructive = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Widget? trailing;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final tint = destructive ? cs.error : (color ?? cs.primary);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            IconTile(icon: icon, color: tint, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: destructive ? cs.error : cs.onSurface,
                      height: 1.25,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (showChevron && onTap != null)
              Icon(Icons.chevron_right_rounded, color: cs.outline),
          ],
        ),
      ),
    );
  }
}

/// Fila con interruptor dentro de un [SectionGroup].
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.fromLTRB(icon == null ? 16 : 14, 4, 12, 4),
      secondary: icon == null ? null : IconTile(icon: icon!, size: 40),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Estado vacío o bloqueado: icono grande, título, texto y acciones.
class EmptyMessage extends StatelessWidget {
  const EmptyMessage({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actions = const [],
    this.color,
  });

  final IconData icon;
  final String title;
  final String? body;
  final List<Widget> actions;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTile(icon: icon, color: color, size: 76),
          const SizedBox(height: 20),
          Text(
            title,
            style: tt.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (body != null) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                body!,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    actions[i],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Aviso en línea (informativo, éxito o advertencia).
class InfoNote extends StatelessWidget {
  const InfoNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.tone = InfoTone.neutral,
  });

  final String text;
  final IconData icon;
  final InfoTone tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      InfoTone.neutral => (cs.primaryContainer, cs.onPrimaryContainer),
      InfoTone.ok => (AppColors.okSoft, AppColors.ok),
      InfoTone.warn => (AppColors.warnSoft, AppColors.warn),
      InfoTone.error => (cs.errorContainer, cs.error),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tone == InfoTone.neutral ? cs.onSurface : fg,
                    fontSize: 13,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

enum InfoTone { neutral, ok, warn, error }

/// Spinner pequeño para botones.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}

/// ListView centrado con ancho máximo legible en tablet.
class PageList extends StatelessWidget {
  const PageList({
    super.key,
    required this.children,
    this.maxWidth = 640,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 32),
    this.controller,
  });

  final List<Widget> children;
  final double maxWidth;
  final EdgeInsets padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Mismos bordes que BottomActions: ancho máximo menos el margen lateral.
        final extra = constraints.maxWidth > maxWidth
            ? (constraints.maxWidth - maxWidth) / 2 + padding.left
            : padding.left;
        return ListView(
          controller: controller,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            extra,
            padding.top,
            extra,
            padding.bottom + MediaQuery.paddingOf(context).bottom,
          ),
          children: children,
        );
      },
    );
  }
}

/// Barra inferior fija con las acciones principales de la pantalla.
class BottomActions extends StatelessWidget {
  const BottomActions({super.key, required this.children, this.maxWidth = 640});

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: children[i]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData printerTypeIcon(PrinterLinkType t) => switch (t) {
      PrinterLinkType.bluetooth => Icons.bluetooth_rounded,
      PrinterLinkType.usb => Icons.usb_rounded,
      PrinterLinkType.network => Icons.wifi_rounded,
    };

Color printerTypeColor(PrinterLinkType t) => switch (t) {
      PrinterLinkType.bluetooth => AppColors.bluetooth,
      PrinterLinkType.usb => AppColors.usb,
      PrinterLinkType.network => AppColors.brand,
    };

/// Lista de impresoras para elegir una (reemplaza el desplegable).
class PrinterPicker extends StatelessWidget {
  const PrinterPicker({
    super.key,
    required this.printers,
    required this.selectedId,
    required this.onSelected,
    this.enabled = true,
  });

  final List<SavedPrinter> printers;
  final String? selectedId;
  final ValueChanged<SavedPrinter> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SectionGroup(
      dividerIndent: 70,
      children: [
        for (final p in printers)
          InkWell(
            onTap: enabled ? () => onSelected(p) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  IconTile(
                    icon: printerTypeIcon(p.type),
                    color: printerTypeColor(p.type),
                    size: 40,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${p.type.label}, ${p.paper.label}',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _RadioDot(selected: p.id == selectedId),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Opción elegible con título, explicación y marca de selección.
class OptionRow extends StatelessWidget {
  const OptionRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: tt.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _RadioDot(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? cs.primary : Colors.transparent,
        border: Border.all(
          color: selected ? cs.primary : cs.outline,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}

/// Recorte con borde inferior dentado, como papel térmico cortado.
class TornPaperClipper extends CustomClipper<Path> {
  const TornPaperClipper({this.tooth = 10, this.depth = 7, this.topRadius = 0});

  final double tooth;
  final double depth;
  final double topRadius;

  @override
  Path getClip(Size size) {
    final r = topRadius;
    final path = Path()..moveTo(0, r);
    if (r > 0) {
      path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
    }
    path.lineTo(size.width - r, 0);
    if (r > 0) {
      path.arcToPoint(Offset(size.width, r), radius: Radius.circular(r));
    }
    path.lineTo(size.width, size.height - depth);
    final count = (size.width / tooth).ceil();
    final step = size.width / count;
    for (var i = count; i > 0; i--) {
      final x = i * step;
      path
        ..lineTo(x - step / 2, size.height)
        ..lineTo(x - step, size.height - depth);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(TornPaperClipper oldClipper) =>
      oldClipper.tooth != tooth ||
      oldClipper.depth != depth ||
      oldClipper.topRadius != topRadius;
}

/// Hora corta (13:05) para filas de listas.
String shortTime(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(date.toLocal()),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// Encabezado de día para listas agrupadas: Hoy, Ayer o la fecha.
String dayHeading(BuildContext context, DateTime date) {
  final l = L.of(context);
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return l('Hoy', 'Today');
  if (diff == 1) return l('Ayer', 'Yesterday');
  final loc = MaterialLocalizations.of(context);
  if (local.year == now.year) return loc.formatMediumDate(local);
  return loc.formatFullDate(local);
}
