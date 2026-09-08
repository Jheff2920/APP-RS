import 'paper_width.dart';

/// Tamaño elegido en el diálogo Imprimir de Android (Chrome, etc.).
///
/// El ancho es 58 u 80 mm. *Max* solo alarga la página para la vista previa.
/// *Google* (y cualquier tamaño del diálogo) recorta el ticket y lo ajusta
/// al rollo: Chrome deja LIMAFAC a ~58 mm centrado.
class SystemPrintMedia {
  const SystemPrintMedia({
    required this.paper,
    this.previewMax = false,
    this.chromeFit = false,
    this.rawId = '',
  });

  final PaperWidth paper;
  final bool previewMax;
  final bool chromeFit;
  final String rawId;

  static SystemPrintMedia? fromJob({String? id, int? widthMils}) {
    final parsed = fromId(id);
    if (parsed != null) return parsed;
    if (widthMils == null || widthMils < 1000) return null;
    // 58 mm Chrome = 3000 mils; 80 mm = 3150. No usar 2700: 3000 pasaría a 80.
    final paper = widthMils >= 3100 ? PaperWidth.mm80 : PaperWidth.mm58;
    return SystemPrintMedia(
      paper: paper,
      previewMax: true,
      chromeFit: true,
      rawId: id ?? 'mils:$widthMils',
    );
  }

  static SystemPrintMedia? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    final upper = id.toUpperCase();
    PaperWidth? paper;
    if (upper.contains('80')) {
      paper = PaperWidth.mm80;
    } else if (upper.contains('58')) {
      paper = PaperWidth.mm58;
    }
    if (paper == null) return null;
    return SystemPrintMedia(
      paper: paper,
      previewMax: upper.contains('MAX') || upper.contains('GOOGLE'),
      chromeFit: true,
      rawId: id,
    );
  }
}
