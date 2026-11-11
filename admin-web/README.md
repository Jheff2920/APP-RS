# Códigos RedPOS (Vercel)

Proyecto Vercel `redpos-codigos-prueba`. Esta página es **solo para staff**: el cliente no genera códigos aquí, los escribe en la app.

Páginas:

- `/` — **generador** de keys.
- `/control.html` — **panel de control** (para el dueño): resumen en ticket, pestañas Todas/Pendientes/Disponibles/Usadas, buscador por key o cliente, precio por defecto y por key, marcar **pendiente**, **liberar** una key usada y campo **Cliente**.

Pon una clave distinta en `REDPOS_DASHBOARD_PASSWORD` para que quien use el generador no abra el panel.

## Publicar

El push a `main` **no** publica. Desde esta carpeta:

```powershell
npx vercel login      # solo la primera vez
npx vercel --prod
```

La carpeta ya está vinculada al proyecto (`.vercel/project.json`).

Variables de entorno (Vercel → Settings → Environment Variables):

| Variable | Uso |
|----------|-----|
| `REDPOS_STAFF_PASSWORD` | clave del **generador**. **Obligatoria**: sin ella nadie entra (ya no hay clave de respaldo en el código) |
| `REDPOS_DASHBOARD_PASSWORD` | clave del **panel**; si falta, usa la del generador |
| `REDPOS_HMAC` | `REDPOS-PRUEBA-NO-USAR-EN-PRODUCCION` (el mismo de la app) |
| `KV_REST_API_URL`, `KV_REST_API_TOKEN` | base de datos KV (Upstash), conectada desde Storage |

## Cómo funciona una key

- Solo se aceptan keys creadas por el generador (`code:<nonce>` con `createdAt`); la firma HMAC sola no basta.
- Al activarla, la app Android manda un valor anónimo del teléfono (`device`, SHA-256 de `ANDROID_ID` con el código). La key queda **ligada a ese teléfono**: si reinstala la app ahí, se vuelve a activar sola.
- Otro teléfono (o un iPhone) necesita que el panel la **libere**: vale una sola vez y deja de valer el teléfono anterior.
- La primera activación (`HSETNX usedAt`) y el uso de una liberación (`HDEL rebind`) son atómicos.

## Conectar la app

`REDPOS_API` ya tiene por defecto `https://redpos-codigos-prueba.vercel.app`; se mantiene explícito al compilar:

```powershell
flutter build appbundle --release --dart-define=REDPOS_API=https://redpos-codigos-prueba.vercel.app
flutter build apk --release --target-platform android-arm64 --dart-define=REDPOS_API=https://redpos-codigos-prueba.vercel.app
```

## Pruebas

```powershell
npm test
```

`test/kv.test.js` prueba el camino KV contra un Redis en memoria, con activaciones simultáneas.

## Endpoints

- `GET /` — generador de códigos (`noindex`)
- `GET /control.html` — panel de control (`noindex`)
- `GET /terminos.html`, `/privacidad.html` (y en inglés) — URLs de Play
- `POST /api/generate` — `{ "password" }` → `{ "code": "RP-…" }`
- `POST /api/codes` — `{ "password" }` → listado y totales (clave del panel)
- `POST /api/settings` — `{ "password", "price": 19.99 }` → precio por defecto de las usadas
- `POST /api/price` — `{ "password", "nonce", "price" }` → precio propio de una key **ya usada** (vacío = vuelve al defecto)
- `POST /api/key` — `{ "password", "nonce", "pending" | "release" | "note" }` → pendiente, liberar o cliente
- `POST /api/activate` — `{ "code": "RP-…", "device": "<sha256 hex>" }` → `{ "ok": true, "again": bool }`; errores `invalid` (400), `unknown`/`used` (409)
