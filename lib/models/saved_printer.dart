import 'paper_width.dart';
import 'print_margins.dart';
import 'cut_mode.dart';

enum PrinterLinkType {
  bluetooth,
  network;

  String get label => this == PrinterLinkType.bluetooth ? 'Bluetooth' : 'WiFi / Red';

  static PrinterLinkType fromName(String name) {
    return PrinterLinkType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => PrinterLinkType.network,
    );
  }
}

class SavedPrinter {
  SavedPrinter({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    this.port = 9100,
    this.paper = PaperWidth.mm58,
    this.margins = const PrintMargins(),
    this.cut = CutMode.fullGsV0,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final PrinterLinkType type;
  final String address;
  final int port;
  final PaperWidth paper;
  final PrintMargins margins;
  /// Corte automatico (RawBT cutCommand). Default: corte total GS V 0.
  final CutMode cut;
  final bool isDefault;

  SavedPrinter copyWith({
    String? id,
    String? name,
    PrinterLinkType? type,
    String? address,
    int? port,
    PaperWidth? paper,
    PrintMargins? margins,
    CutMode? cut,
    bool? isDefault,
  }) {
    return SavedPrinter(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      port: port ?? this.port,
      paper: paper ?? this.paper,
      margins: margins ?? this.margins,
      cut: cut ?? this.cut,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'address': address,
        'port': port,
        'paper': paper.name,
        'margins': margins.toJson(),
        'cut': cut.name,
        'isDefault': isDefault,
      };

  factory SavedPrinter.fromJson(Map<String, dynamic> json) {
    return SavedPrinter(
      id: json['id'] as String,
      name: json['name'] as String,
      type: PrinterLinkType.fromName(json['type'] as String? ?? 'network'),
      address: json['address'] as String,
      port: (json['port'] as num?)?.toInt() ?? 9100,
      paper: PaperWidth.fromName(json['paper'] as String? ?? 'mm58'),
      margins: PrintMargins.fromJson(
        Map<String, dynamic>.from(json['margins'] as Map? ?? {}),
      ),
      cut: CutMode.fromName(json['cut'] as String? ?? 'fullGsV0'),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  String get connectionSummary {
    if (type == PrinterLinkType.bluetooth) {
      return 'BT $address';
    }
    return '$address:$port';
  }
}
