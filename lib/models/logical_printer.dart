enum PrinterKind { receipt, label }

enum PrinterProtocol { escpos, tspl }

/// Identity and independent configuration of a destination in Android.
class LogicalPrinter {
  const LogicalPrinter({
    required this.logicalPrinterId,
    required this.physicalPrinterId,
    required this.name,
    required this.kind,
    required this.protocol,
    required this.paperProfiles,
    required this.defaultPaperProfileId,
  });

  final String logicalPrinterId;
  final String physicalPrinterId;
  final String name;
  final PrinterKind kind;
  final PrinterProtocol protocol;
  final List<PaperProfile> paperProfiles;
  final String defaultPaperProfileId;
}

class PaperProfile {
  const PaperProfile({
    required this.paperProfileId,
    required this.logicalPrinterId,
    required this.name,
    required this.widthMm,
    required this.heightMm,
    this.leftMm = 0,
    this.rightMm = 0,
    this.topMm = 0,
    this.bottomMm = 0,
    this.gapMm = 2,
    this.offsetXmm = 0,
    this.offsetYmm = 0,
    this.scalePercent = 100,
    this.rotation = 0,
    this.darkness = 0,
    this.thicken = false,
    this.enabled = true,
    this.receiptMediaId,
  });

  final String paperProfileId;
  final String logicalPrinterId;
  final String name;
  final double widthMm;
  final double heightMm;
  final double leftMm, rightMm, topMm, bottomMm, gapMm;
  final double offsetXmm, offsetYmm, scalePercent;

  /// Giro horario del contenido: 0, 90, 180 o 270.
  final int rotation;

  /// Oscuridad 1–15 (DENSITY en TSPL). 0 = la que tenga la impresora.
  final int darkness;

  /// Engrosa trazos 1 punto: oscurece aunque la impresora ignore DENSITY.
  final bool thicken;
  final bool enabled;
  final String? receiptMediaId;

  String get mediaId => receiptMediaId ?? 'REDPOS_LABEL_$paperProfileId';
  bool get isLabel => receiptMediaId == null;

  String? get validationError {
    final values = [
      widthMm,
      heightMm,
      leftMm,
      rightMm,
      topMm,
      bottomMm,
      gapMm,
      offsetXmm,
      offsetYmm,
      scalePercent
    ];
    if (values.any((v) => !v.isFinite)) return 'Escribe medidas válidas.';
    if (name.trim().isEmpty) return 'Escribe un nombre para el tamaño.';
    if (widthMm < 10 || widthMm > 210 || heightMm < 5 || heightMm > 500) {
      return 'El ancho debe estar entre 10 y 210 mm y el alto entre 5 y 500 mm.';
    }
    if ([leftMm, rightMm, topMm, bottomMm, gapMm].any((v) => v < 0) ||
        gapMm > 50 ||
        leftMm + rightMm >= widthMm ||
        topMm + bottomMm >= heightMm) {
      return 'Los márgenes deben dejar espacio para imprimir. GAP máximo: 50 mm.';
    }
    if (offsetXmm.abs() > widthMm ||
        offsetYmm.abs() > heightMm ||
        scalePercent < 25 ||
        scalePercent > 200) {
      return 'Revisa los desplazamientos y la escala (25 a 200 %).';
    }
    if (!const [0, 90, 180, 270].contains(rotation)) {
      return 'Elige una orientación válida.';
    }
    if (darkness < 0 || darkness > 15) {
      return 'La oscuridad debe estar entre 0 y 15.';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'paperProfileId': paperProfileId,
        'logicalPrinterId': logicalPrinterId,
        'name': name,
        'widthMm': widthMm,
        'heightMm': heightMm,
        'leftMm': leftMm,
        'rightMm': rightMm,
        'topMm': topMm,
        'bottomMm': bottomMm,
        'gapMm': gapMm,
        'offsetXmm': offsetXmm,
        'offsetYmm': offsetYmm,
        'scalePercent': scalePercent,
        'rotation': rotation,
        'darkness': darkness,
        'thicken': thicken,
        'enabled': enabled,
        if (receiptMediaId != null) 'receiptMediaId': receiptMediaId,
      };

  factory PaperProfile.fromJson(Map<String, dynamic> j) => PaperProfile(
        paperProfileId: j['paperProfileId'] as String,
        logicalPrinterId: j['logicalPrinterId'] as String,
        name: j['name'] as String,
        widthMm: (j['widthMm'] as num).toDouble(),
        heightMm: (j['heightMm'] as num).toDouble(),
        leftMm: (j['leftMm'] as num?)?.toDouble() ?? 0,
        rightMm: (j['rightMm'] as num?)?.toDouble() ?? 0,
        topMm: (j['topMm'] as num?)?.toDouble() ?? 0,
        bottomMm: (j['bottomMm'] as num?)?.toDouble() ?? 0,
        gapMm: (j['gapMm'] as num?)?.toDouble() ?? 2,
        offsetXmm: (j['offsetXmm'] as num?)?.toDouble() ?? 0,
        offsetYmm: (j['offsetYmm'] as num?)?.toDouble() ?? 0,
        scalePercent: (j['scalePercent'] as num?)?.toDouble() ?? 100,
        rotation: (j['rotation'] as num?)?.toInt() ?? 0,
        darkness: (j['darkness'] as num?)?.toInt() ?? 0,
        thicken: j['thicken'] as bool? ?? false,
        enabled: j['enabled'] as bool? ?? true,
        receiptMediaId: j['receiptMediaId'] as String?,
      );

  static List<PaperProfile> receipts(String logicalId) => [
        for (final width in [58, 80])
          for (final suffix in ['', '_MAX', '_GOOGLE'])
            PaperProfile(
              paperProfileId: '$logicalId-receipt-$width$suffix',
              logicalPrinterId: logicalId,
              name:
                  'Rollo $width mm${suffix == '_MAX' ? ' Max' : suffix == '_GOOGLE' ? ' Google' : ''}',
              widthMm: width.toDouble(),
              heightMm: 812.8,
              receiptMediaId: 'BOLETA_ROLL_$width$suffix',
              gapMm: 0,
            ),
      ];

  static List<PaperProfile> labels(String logicalId) => [
        for (final size in [(50, 25), (30, 20)])
          PaperProfile(
              paperProfileId: '$logicalId-${size.$1}x${size.$2}',
              logicalPrinterId: logicalId,
              name: '${size.$1} × ${size.$2} mm',
              widthMm: size.$1.toDouble(),
              heightMm: size.$2.toDouble()),
      ];
}
