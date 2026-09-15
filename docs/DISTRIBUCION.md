# Distribución Play + código de activación RedPOS

App **pública en Play** (Android). Imprimir **nunca se bloquea**.  
Sin publicidad con **código de activación** (equipo o licencia de por vida), o **suscripción mensual** (Google Play).  
Sin código y sin pago: la app funciona igual, con anuncios en pantalla y pie en el papel.

**Identidad:** `com.redpos.service` · versión en `pubspec.yaml` (hoy `1.8.2+43`).  
**Producto Play:** `redpos_ads_free_monthly` (plan base mensual).  
**URLs legales (Play Console):**

- Privacidad: https://redpos-codigos-prueba.vercel.app/privacidad.html
- Términos: https://redpos-codigos-prueba.vercel.app/terminos.html

Los HTML ya están en GitHub (`test/redpos-vercel-codigos`). Si Vercel aún muestra 404, en el proyecto `redpos-codigos-prueba` pulsa **Redeploy** (el CLI de Vercel no tiene sesión en esta PC).

Web staff + API HTTPS: carpeta `admin-web/` (Vercel, rama `test/redpos-vercel-codigos`).  
El HMAC de prueba no es producción; en Vercel el KV marca cada código como usado.

---

## Cómo probar

1. Al **vincular** hay campo opcional de código y **Continuar con publicidad**.
2. Banner: **Tengo un código**, **Suscripción mensual**, **Licencia de por vida**.
3. Generar códigos:

- Local (PC): `dart run tool/redpos_admin.dart` → http://127.0.0.1:8787 (clave staff `R100301S`).
- Nube de prueba (HTTPS): [admin-web/README.md](../admin-web/README.md).

4. Sin pase: banner en la lista / Compartir, y pie en el papel **después** del ticket/QR y **antes** del corte (también PrintService/Chrome).
5. Un código válido o una suscripción vigente quita la publicidad en **toda la instalación**.

Compila con:

`--dart-define=REDPOS_API=https://redpos-codigos-prueba.vercel.app`

---

## La idea

```
Cliente instala desde Play
        │
        ▼
Usa la app (imprime siempre)
        │
        ├─ Tiene código (equipo o por vida) ──► sin anuncios
        ├─ Suscripción mensual (Google + Play) ──► sin anuncios
        └─ Continuar con publicidad ──► imprime + ads
```

- El código se lo dan ustedes (caja del equipo, WhatsApp, o tras un correo de licencia de por vida).
- Si no lo tiene, **acepta publicidad** y sigue.
- La suscripción **sí** va con cuenta Google, solo al pagar. El código **no** exige cuenta.

---

## Play Console (ustedes)

Sin el perfil de pagos el botón de suscripción no cobra.

1. **Perfil de pagos / merchant** en Play Console (no es lo mismo que la cuenta de desarrollador). En Perú puede tardar varios días.
2. Monetización → Productos → Suscripciones → crear **`redpos_ads_free_monthly`**.
   - Nombre visible: `RedPOS Service sin publicidad`.
   - Plan base: **mensual**, precio en PEN.
3. Testers de licencia: Configuración → Licencias → añadir las cuentas Gmail de prueba. Esas cuentas pueden comprar sin cargo real en pistas internas.
4. **Play App Signing:** al subir el primer AAB, Google genera la clave de firma de la app. El `android/upload-keystore.jks` de esta PC es solo la **clave de subida**. Cópialo junto con `android/key.properties` a un USB / gestor de contraseñas. **No va a git.** Si se pierde, no se pueden subir más actualizaciones.
5. Ficha: nombre **RedPOS Service**, capturas, icono, gráfico, categoría, clasificación de contenido.
6. **Seguridad de datos:** Bluetooth/USB/archivos en el aparato; cuenta Google y pago solo si se suscribe. Política: la URL de privacidad de arriba.
7. Cuentas nuevas suelen exigir **prueba cerrada** (testers que acepten el enlace, a menudo 14 días) **antes** de producción. Orden: prueba interna → cerrada → producción.

### Google Sign-In

Clientes OAuth Android (paquete `com.redpos.service`):

- SHA-1 de **firma Play:** `5A:00:43:D3:11:B5:55:DF:CE:68:6A:BE:66:9E:37:93:6D:D3:39:FD`
- SHA-1 de **upload:** `55:DA:51:A8:72:63:E2:6E:8C:11:CE:CB:1D:EF:A8:55:AE:5D:F4:5A`
- SHA-256 upload: `60:B1:58:F4:81:54:66:32:92:CF:05:FD:BF:B1:5E:BA:AF:B7:90:AA:47:D4:02:68:45:3D:61:F3:47:AC:C3:5C`

Cliente OAuth **web** (va en la app como `serverClientId`; el secreto GOCSPX no se usa en el teléfono).

---

## Firma y AAB

- Keystore local: `android/upload-keystore.jks` + `android/key.properties` (gitignored). Plantilla: `android/key.properties.example`.
- AAB: `flutter build appbundle --release --dart-define=REDPOS_API=https://redpos-codigos-prueba.vercel.app`
- APK sideload (IMIN): misma firma de upload, carpeta `inst-apk/`.

Las tablets que ya tienen el APK **debug-firmado** no se actualizan con el AAB de Play: hay que desinstalar e instalar de nuevo.

Sube `versionCode` en cada release (`pubspec.yaml`, el número después de `+`).

---

## Checklist

### 0. App lista para Play

- [x] `applicationId` / bundle: `com.redpos.service`
- [x] Keystore **release** + `key.properties` (no subir a git)
- [x] Política de privacidad y términos en HTTPS
- [ ] Ficha Play, capturas, AAB subido
- [x] APK firmado de respaldo (IMIN sin Play), mismo ID
- [x] Subir `versionCode` en cada release (proceso: `pubspec.yaml`)

### 1. Web interna de códigos (staff)

- [x] Generar código (`tool/redpos_admin.dart` y `admin-web/`)
- [ ] Login de **empleados** RedPOS (ahora una clave local)
- [ ] Atar a MAC / modelo al vender
- [x] Rama de prueba Vercel: `test/redpos-vercel-codigos` (`admin-web/`)
- [ ] Servidor de producción + HMAC distinto
- [x] `noindex` en la página staff; términos/privacidad públicos

### 2. App al agregar impresora

- [x] Campo “Código de activación (opcional)”
- [x] Botón “Continuar con publicidad”
- [x] Código válido → pase local → sin ads
- [x] Si falla red al validar (con `REDPOS_API`): guardar igual, modo ads
- [x] Texto de aviso + contacto

### 3. Suscripción y licencia

- [x] Google Sign-In **solo al pagar** el mensual
- [x] Play Billing `redpos_ads_free_monthly` → mismo efecto que el código
- [x] Licencia de por vida por correo → mismo código HMAC
- [x] Imprimir **sin** estar logueado
- [ ] Crear el producto y el perfil de pagos en Play Console

### 4. Anuncios

- [x] Banner en lista / compartir si no hay pase
- [x] Pie ESC/POS al final de cada job (app y PrintService), antes del corte
- [x] Separado del PDF; no tapa QR SUNAT
- [x] Texto y URL configurables (`REDPOS_SITE` / `lib/services/redpos/redpos_config.dart`)

### 5. Operación

- [ ] Al vender RedPOS: sticker o mensaje con el código + anotar MAC
- [x] IMIN: aviso USB tras apagar (ya en `main`)
- [ ] QR en la caja al listing de Play

---

## Relacionado

- App en general: [README.md](../README.md)
- USB al encender / IMIN: sección USB del README
- Rendimiento: [PRINT_PERFORMANCE.md](PRINT_PERFORMANCE.md)
- Códigos Vercel: [admin-web/README.md](../admin-web/README.md)
