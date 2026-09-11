import 'dart:convert';
import 'dart:io';

import 'package:hello_world_app/services/redpos/redpos_code.dart';
import 'package:hello_world_app/services/redpos/redpos_config.dart';

/// Web interna de prueba para generar códigos RedPOS.
///
///   dart run tool/redpos_admin.dart
///
/// Abre http://127.0.0.1:8787  (clave por defecto: R100301S)
void main(List<String> args) async {
  final host = Platform.environment['REDPOS_ADMIN_HOST'] ?? '127.0.0.1';
  final port = int.tryParse(Platform.environment['REDPOS_ADMIN_PORT'] ?? '') ?? 8787;
  final password =
      Platform.environment['REDPOS_STAFF_PASSWORD'] ?? 'R100301S';
  final dataFile = File(
    Platform.environment['REDPOS_ADMIN_DATA'] ?? 'tool/redpos_admin_data.json',
  );

  final server = await HttpServer.bind(host, port);
  stderr.writeln('RedPOS admin (prueba) en http://$host:$port');
  stderr.writeln('Clave staff: $password');
  stderr.writeln('Los códigos HMAC usan el secreto de la app de prueba.');
  stderr.writeln('Ctrl+C para salir.');

  await for (final req in server) {
    try {
      await _handle(req, password: password, dataFile: dataFile);
    } catch (e, st) {
      stderr.writeln('$e\n$st');
      req.response.statusCode = 500;
      req.response.write('error');
      await req.response.close();
    }
  }
}

Future<void> _handle(
  HttpRequest req, {
  required String password,
  required File dataFile,
}) async {
  final path = req.uri.path;
  if (req.method == 'GET' && (path == '/' || path == '/index.html')) {
    req.response.headers.contentType = ContentType.html;
    req.response.write(_html);
    await req.response.close();
    return;
  }

  if (req.method == 'POST' && path == '/api/generate') {
    final body = jsonDecode(await utf8.decodeStream(req)) as Map;
    if (body['password'] != password) {
      req.response.statusCode = 401;
      req.response.write(jsonEncode({'ok': false, 'error': 'clave'}));
      await req.response.close();
      return;
    }
    final code = RedPosCode.generate(secret: RedPosConfig.hmacSecret);
    await _record(dataFile, code, used: false);
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode({'ok': true, 'code': code}));
    await req.response.close();
    return;
  }

  if (req.method == 'POST' && path == '/api/activate') {
    final body = jsonDecode(await utf8.decodeStream(req)) as Map;
    final code = body['code'] as String? ?? '';
    final verified = RedPosCode.verify(code, secret: RedPosConfig.hmacSecret);
    if (!verified.ok || verified.nonce == null) {
      req.response.statusCode = 400;
      req.response.write(jsonEncode({'ok': false, 'error': 'invalid'}));
      await req.response.close();
      return;
    }
    final used = await _consume(dataFile, verified.nonce!);
    req.response.headers.contentType = ContentType.json;
    if (!used) {
      req.response.statusCode = 409;
      req.response.write(jsonEncode({'ok': false, 'error': 'used'}));
    } else {
      req.response.write(jsonEncode({'ok': true}));
    }
    await req.response.close();
    return;
  }

  req.response.statusCode = 404;
  req.response.write('not found');
  await req.response.close();
}

Future<Map<String, dynamic>> _load(File file) async {
  if (!await file.exists()) return {'codes': <dynamic>[]};
  try {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, dynamic>) return decoded;
    return {'codes': <dynamic>[]};
  } catch (_) {
    return {'codes': <dynamic>[]};
  }
}

Future<void> _record(File file, String code, {required bool used}) async {
  final data = await _load(file);
  final list = List<Map<String, dynamic>>.from(
    (data['codes'] as List? ?? []).map(
      (e) => Map<String, dynamic>.from(e as Map),
    ),
  );
  final verified = RedPosCode.verify(code);
  list.add({
    'code': code,
    'nonce': verified.nonce,
    'used': used,
    'createdAt': DateTime.now().toIso8601String(),
  });
  data['codes'] = list;
  await file.parent.create(recursive: true);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
}

/// Marca el nonce como usado. Si el código no estaba en el archivo (HMAC
/// generado en otro sitio), lo acepta la primera vez y lo registra.
Future<bool> _consume(File file, String nonce) async {
  final data = await _load(file);
  final list = List<Map<String, dynamic>>.from(
    (data['codes'] as List? ?? []).map(
      (e) => Map<String, dynamic>.from(e as Map),
    ),
  );
  final i = list.indexWhere((e) => e['nonce'] == nonce);
  if (i >= 0) {
    if (list[i]['used'] == true) return false;
    list[i]['used'] = true;
    list[i]['usedAt'] = DateTime.now().toIso8601String();
  } else {
    list.add({
      'nonce': nonce,
      'used': true,
      'usedAt': DateTime.now().toIso8601String(),
      'note': 'hmac-offline',
    });
  }
  data['codes'] = list;
  await file.parent.create(recursive: true);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  return true;
}

const _html = '''
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>RedPOS · códigos (prueba)</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 40rem; margin: 2rem auto; padding: 0 1rem;
      background: #f4f4f5; color: #111; }
    input, button { font-size: 1rem; padding: .5rem .75rem; }
    .code { font-size: 1.6rem; letter-spacing: .08em; font-family: ui-monospace, monospace; margin: 1rem 0; }
    .hint { color: #333; }
  </style>
</head>
<body>
  <h1>Códigos RedPOS (prueba)</h1>
  <p class="hint">Solo personal interno. No publiques esta página. Los códigos
  se validan en la app de la rama <code>test/redpos-activacion</code>.</p>
  <label>Clave staff<br/>
    <input id="pw" type="password" autocomplete="current-password"/>
  </label>
  <p><button id="go">Generar código</button></p>
  <p id="out" class="code"></p>
  <p class="hint">En la app: campo opcional al vincular, o el banner
  «Tengo un código». Código de demo: <code>REDPOS-PRUEBA-1</code>.</p>
  <script>
    document.getElementById('go').onclick = async () => {
      const password = document.getElementById('pw').value;
      const res = await fetch('/api/generate', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({password}),
      });
      const data = await res.json();
      document.getElementById('out').textContent = data.code || data.error || 'error';
    };
  </script>
</body>
</html>
''';
