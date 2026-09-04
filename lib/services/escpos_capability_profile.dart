import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

/// El perfil ESC/POS es inmutable; cargarlo una vez evita releer assets por job.
class EscPosCapabilityProfile {
  EscPosCapabilityProfile._();

  static final Future<CapabilityProfile> _cached = CapabilityProfile.load();

  static Future<CapabilityProfile> get load => _cached;
}
