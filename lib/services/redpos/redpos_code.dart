import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'redpos_config.dart';

class RedPosCodeResult {
  const RedPosCodeResult._({
    required this.ok,
    this.nonce,
    this.message,
    this.testAlias = false,
  });

  final bool ok;
  final String? nonce;
  final String? message;
  final bool testAlias;

  static const invalid = RedPosCodeResult._(
    ok: false,
    message: 'Código no válido',
  );

  static RedPosCodeResult valid(String nonce, {bool testAlias = false}) {
    return RedPosCodeResult._(ok: true, nonce: nonce, testAlias: testAlias);
  }
}

/// Códigos cortos firmados: `RP-XXXX-XXXX-XXXX` (HMAC, 12 caracteres).
class RedPosCode {
  static const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const _nonceLen = 8;
  static const _macLen = 4;

  static String generate({String? secret, Random? random}) {
    final rnd = random ?? Random.secure();
    final nonce = String.fromCharCodes(
      List.generate(
        _nonceLen,
        (_) => alphabet.codeUnitAt(rnd.nextInt(alphabet.length)),
      ),
    );
    final mac = _macChars(secret ?? RedPosConfig.hmacSecret, nonce);
    return format(nonce + mac);
  }

  static String format(String raw12) {
    final body = raw12.toUpperCase();
    if (body.length != 12) return body;
    return 'RP-${body.substring(0, 4)}-${body.substring(4, 8)}-${body.substring(8, 12)}';
  }

  static String normalize(String input) {
    return input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static bool isTestAlias(String input) {
    if (!RedPosConfig.allowTestCodes) return false;
    return normalize(input) == normalize(RedPosConfig.testCode);
  }

  static RedPosCodeResult verify(String input, {String? secret}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const RedPosCodeResult._(
        ok: false,
        message: 'Escribe un código o continúa con publicidad',
      );
    }
    if (isTestAlias(trimmed)) {
      return RedPosCodeResult.valid('TESTALIAS', testAlias: true);
    }

    var body = normalize(trimmed);
    if (body.startsWith('RP') && body.length == 14) {
      body = body.substring(2);
    }
    if (body.length != 12) return RedPosCodeResult.invalid;

    for (final ch in body.split('')) {
      if (!alphabet.contains(ch)) return RedPosCodeResult.invalid;
    }

    final nonce = body.substring(0, _nonceLen);
    final mac = body.substring(_nonceLen);
    final expected = _macChars(secret ?? RedPosConfig.hmacSecret, nonce);
    if (!_constEq(mac, expected)) return RedPosCodeResult.invalid;
    return RedPosCodeResult.valid(nonce);
  }

  static String _macChars(String secret, String nonce) {
    final digest = Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode('RP1|$nonce'))
        .bytes;
    return _charsFromHash(digest, _macLen);
  }

  static String _charsFromHash(List<int> hash, int count) {
    final out = StringBuffer();
    var acc = 0;
    var bits = 0;
    var i = 0;
    while (out.length < count && i < hash.length) {
      acc = (acc << 8) | (hash[i++] & 0xff);
      bits += 8;
      while (bits >= 5 && out.length < count) {
        bits -= 5;
        out.write(alphabet[(acc >> bits) & 31]);
      }
    }
    return out.toString();
  }

  static bool _constEq(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

/// Token local que la app vuelve a verificar (no un simple flag).
class RedPosLicenseToken {
  const RedPosLicenseToken({
    required this.nonce,
    required this.issuedAtMs,
  });

  final String nonce;
  final int issuedAtMs;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'nonce': nonce,
        'issuedAtMs': issuedAtMs,
      };

  factory RedPosLicenseToken.fromJson(Map<String, dynamic> json) {
    return RedPosLicenseToken(
      nonce: json['nonce'] as String? ?? '',
      issuedAtMs: (json['issuedAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  String encode() => base64Url.encode(utf8.encode(jsonEncode(toJson())));

  static RedPosLicenseToken? tryDecode(String raw) {
    try {
      final json = jsonDecode(utf8.decode(base64Url.decode(raw)));
      if (json is! Map) return null;
      return RedPosLicenseToken.fromJson(Map<String, dynamic>.from(json));
    } catch (_) {
      return null;
    }
  }
}
