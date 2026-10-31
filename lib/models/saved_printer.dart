import 'cash_drawer.dart';
import 'cut_mode.dart';
import 'paper_width.dart';
import 'print_margins.dart';
import 'printer_dpi.dart';
import 'raster_scale.dart';
import '../l10n/app_lang.dart';
import 'logical_printer.dart';
export 'logical_printer.dart';

enum PrinterLinkType {
  bluetooth,
  network,
  usb;

  String get label {
    switch (this) {
      case PrinterLinkType.bluetooth:
        return 'Bluetooth';
      case PrinterLinkType.network:
        return tr('WiFi / Red', 'WiFi / Network');
      case PrinterLinkType.usb:
        return 'USB';
    }
  }

  static PrinterLinkType fromName(String name) {
    return PrinterLinkType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => PrinterLinkType.network,
    );
  }
}

/// Compatibility view consumed by existing receipt renderers and transports.
/// PrinterStore persists connection data once, in the physical catalog, and
/// independent settings in the logical catalog. This object is a job snapshot.
class SavedPrinter {
  SavedPrinter({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    this.port = 9100,
    this.paper = PaperWidth.mm58,
    this.dpi = PrinterDpi.dpi203,
    this.margins = const PrintMargins(),
    this.cut = CutMode.fullGsV0,
    this.cashDrawer = CashDrawer.none,
    this.rasterScale = RasterScale.x1,
    this.isDefault = false,
    this.adsFree = false,
    String? physicalPrinterId,
    this.kind = PrinterKind.receipt,
    this.protocol = PrinterProtocol.escpos,
    List<PaperProfile>? paperProfiles,
    String? defaultPaperProfileId,
  })  : physicalPrinterId = physicalPrinterId ?? 'physical-$id',
        paperProfiles = List.unmodifiable(paperProfiles ??
            (kind == PrinterKind.receipt
                ? PaperProfile.receipts(id)
                : PaperProfile.labels(id))),
        defaultPaperProfileId = defaultPaperProfileId ?? '';

  final String physicalPrinterId;
  final PrinterKind kind;
  final PrinterProtocol protocol;
  final List<PaperProfile> paperProfiles;
  final String defaultPaperProfileId;
  bool get isLabel => kind == PrinterKind.label;
  List<PaperProfile> get enabledProfiles => paperProfiles
      .where(
          (p) => p.enabled && p.logicalPrinterId == id && p.isLabel == isLabel)
      .toList();
  PaperProfile get defaultProfile => enabledProfiles.firstWhere(
      (p) => p.paperProfileId == defaultPaperProfileId,
      orElse: () => enabledProfiles.firstWhere(
          (p) =>
              !isLabel &&
              p.receiptMediaId ==
                  'BOLETA_ROLL_${paper == PaperWidth.mm80 ? 80 : 58}_GOOGLE',
          orElse: () => enabledProfiles.first));
  LogicalPrinter get logicalPrinter => LogicalPrinter(
      logicalPrinterId: id,
      physicalPrinterId: physicalPrinterId,
      name: name,
      kind: kind,
      protocol: protocol,
      paperProfiles: paperProfiles,
      defaultPaperProfileId: defaultPaperProfileId);

  final String id;
  final String name;
  final PrinterLinkType type;
  final String address;
  final int port;
  final PaperWidth paper;
  final PrinterDpi dpi;
  final PrintMargins margins;

  /// Corte automatico (RawBT cutCommand). Default: corte total GS V 0.
  final CutMode cut;

  /// Gaveta: none = no enviar ESC p. Default off.
  final CashDrawer cashDrawer;
  final RasterScale rasterScale;
  final bool isDefault;

  /// Copia para el PrintService nativo. En Dart se verifica el pase firmado.
  final bool adsFree;

  int get dotsWidth => dpi.dotsFor(paper);

  SavedPrinter copyWith({
    String? id,
    String? name,
    PrinterLinkType? type,
    String? address,
    int? port,
    PaperWidth? paper,
    PrinterDpi? dpi,
    PrintMargins? margins,
    CutMode? cut,
    CashDrawer? cashDrawer,
    RasterScale? rasterScale,
    bool? isDefault,
    bool? adsFree,
    String? physicalPrinterId,
    PrinterKind? kind,
    PrinterProtocol? protocol,
    List<PaperProfile>? paperProfiles,
    String? defaultPaperProfileId,
  }) {
    return SavedPrinter(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      port: port ?? this.port,
      paper: paper ?? this.paper,
      dpi: dpi ?? this.dpi,
      margins: margins ?? this.margins,
      cut: cut ?? this.cut,
      cashDrawer: cashDrawer ?? this.cashDrawer,
      rasterScale: rasterScale ?? this.rasterScale,
      isDefault: isDefault ?? this.isDefault,
      adsFree: adsFree ?? this.adsFree,
      physicalPrinterId: physicalPrinterId ?? this.physicalPrinterId,
      kind: kind ?? this.kind,
      protocol: protocol ?? this.protocol,
      paperProfiles: paperProfiles ?? this.paperProfiles,
      defaultPaperProfileId:
          defaultPaperProfileId ?? this.defaultPaperProfileId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'address': address,
        'port': port,
        'paper': paper.name,
        'dpi': dpi.name,
        'margins': margins.toJson(),
        'cut': cut.name,
        'cashDrawer': cashDrawer.name,
        'rasterScale': rasterScale.name,
        'isDefault': isDefault,
        'adsFree': adsFree,
        'physicalPrinterId': physicalPrinterId,
        'kind': kind.name,
        'protocol': protocol.name,
        'paperProfiles': paperProfiles.map((p) => p.toJson()).toList(),
        'defaultPaperProfileId': defaultPaperProfileId,
      };

  factory SavedPrinter.fromJson(Map<String, dynamic> json) {
    return SavedPrinter(
      id: json['id'] as String,
      name: json['name'] as String,
      type: PrinterLinkType.fromName(json['type'] as String? ?? 'network'),
      address: json['address'] as String,
      port: (json['port'] as num?)?.toInt() ?? 9100,
      paper: PaperWidth.fromName(json['paper'] as String? ?? 'mm58'),
      dpi: PrinterDpi.fromName(json['dpi'] as String? ?? 'dpi203'),
      margins: PrintMargins.fromJson(
        Map<String, dynamic>.from(json['margins'] as Map? ?? {}),
      ),
      cut: CutMode.fromName(json['cut'] as String? ?? 'fullGsV0'),
      cashDrawer: CashDrawer.fromName(json['cashDrawer'] as String? ?? 'none'),
      rasterScale: RasterScale.fromName(json['rasterScale'] as String? ?? 'x1'),
      isDefault: json['isDefault'] as bool? ?? false,
      adsFree: json['adsFree'] as bool? ?? false,
      physicalPrinterId: json['physicalPrinterId'] as String?,
      kind: json['kind'] == 'label' ? PrinterKind.label : PrinterKind.receipt,
      protocol: json['protocol'] == 'tspl'
          ? PrinterProtocol.tspl
          : PrinterProtocol.escpos,
      paperProfiles: (json['paperProfiles'] as List?)
          ?.map(
              (p) => PaperProfile.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      defaultPaperProfileId: json['defaultPaperProfileId'] as String?,
    );
  }

  String get connectionSummary {
    switch (type) {
      case PrinterLinkType.bluetooth:
        return 'BT $address';
      case PrinterLinkType.usb:
        return 'USB $address';
      case PrinterLinkType.network:
        return '$address:$port';
    }
  }
}
