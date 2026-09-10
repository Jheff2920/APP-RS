# Códigos RedPOS (prueba en Vercel)

Rama: `test/redpos-vercel-codigos`. **No es producción.**  
Esta página es **solo para staff**. El cliente no genera códigos aquí: los escribe en la app.

## Subir a Vercel (HTTPS)

1. En [vercel.com](https://vercel.com) → Add New → Project → el repo `APP-RS`.
2. **Root Directory:** `admin-web`
3. **Production Branch** (o Preview): `test/redpos-vercel-codigos`
4. Variables de entorno:

   | Variable | Valor de prueba |
   |----------|-----------------|
   | `REDPOS_STAFF_PASSWORD` | una clave solo de ustedes |
   | `REDPOS_HMAC` | `REDPOS-PRUEBA-NO-USAR-EN-PRODUCCION` (el mismo de la app de prueba) |

5. Storage → Create Database → **KV (Upstash)** y conéctalo al proyecto. Eso crea `KV_REST_API_URL` y `KV_REST_API_TOKEN`. Sin KV, generar códigos sí; canjear desde la app en la nube no (hace falta marcar “ya usado”).
6. Deploy. Queda `https://….vercel.app`.

## Conectar la app

Compila el release con la URL de Vercel (sin barra final):

```powershell
flutter build apk --release --target-platform android-arm64 `
  --dart-define=REDPOS_API=https://TU-PROYECTO.vercel.app
```

La app llama a `POST /api/activate` con `{ "code": "RP-…" }`.

## Local

```powershell
npx vercel dev --cwd admin-web
```

Sin Vercel CLI, la página staff no corre sola: son funciones serverless.

## Endpoints

- `GET /` — formulario staff
- `POST /api/generate` — `{ "password": "…" }` → `{ "code": "RP-…" }`
- `POST /api/activate` — `{ "code": "RP-…" }` → `{ "ok": true }` o 409 si ya se usó
