# Distribución Play + código de activación RedPOS

App **pública en Play** (Android). Imprimir **nunca se bloquea**.  
Sin publicidad solo con **código de activación** (equipo RedPOS) o **suscripción** (cuenta).  
Sin código y sin cuenta: la app funciona igual, con anuncios en pantalla y pie en el papel.

**Implementación de prueba:** códigos en `main` (HMAC en la app).  
Web staff + API HTTPS (Vercel): rama `test/redpos-vercel-codigos` → carpeta `admin-web/`.  
El HMAC de prueba no es producción; en Vercel el KV marca cada código como usado.

---

## Cómo probar esta rama

1. App: al **vincular** hay campo opcional de código y **Continuar con publicidad**.
2. Código de demo: `REDPOS-PRUEBA-1`
3. Generar más códigos:

- Local (PC): `dart run tool/redpos_admin.dart` → http://127.0.0.1:8787 (clave staff `R100301S`).
- Nube de prueba (HTTPS): rama `test/redpos-vercel-codigos`, ver [admin-web/README.md](../admin-web/README.md).

4. Sin código: banner en la lista / Compartir, y pie en el papel **después** del ticket/QR y **antes** del corte (también PrintService/Chrome).
5. Un código válido quita la publicidad en **toda la instalación** (no hace falta cuenta).
6. La suscripción (login + pago) aún no está; el botón abre un aviso de contacto.

Para canje de un solo uso entre varios teléfonos, corre el admin en la LAN y compila con:

`--dart-define=REDPOS_API=http://IP:8787`

---

## La idea

```
Cliente instala desde Play
        │
        ▼
Agrega impresora
        │
        ├─ Tiene código ──► valida ──► sin anuncios
        ├─ Paga suscripción (cuenta) ──► sin anuncios
        └─ “Continuar con publicidad” ──► imprime + ads
```

- El código se lo dan ustedes (caja del equipo, WhatsApp, o tras pagar).
- Si no lo tiene, **acepta publicidad** y sigue.
- La suscripción **sí** va con **cuenta**. El código de hardware **no** exige cuenta.

---

## Checklist

### 0. App lista para Play

- [x] `applicationId` / bundle: `com.redpos.service`
- [ ] Keystore **release** + `key.properties` (no subir a git)
- [ ] Política de privacidad (códigos, MAC, cuenta)
- [ ] Ficha Play, capturas, AAB
- [ ] APK firmado de respaldo (IMIN sin Play), mismo ID
- [ ] Subir `versionCode` en cada release

### 1. Web interna de códigos (staff)

- [x] Generar código (rama de prueba: `tool/redpos_admin.dart`)
- [ ] Login de **empleados** RedPOS (ahora una clave local)
- [ ] Atar a MAC / modelo al vender
- [x] Rama de prueba Vercel: `test/redpos-vercel-codigos` (`admin-web/`)
- [ ] Servidor de producción + HTTPS (no HMAC en el APK)
- [ ] No exponer esta web en Google

### 2. App al agregar impresora

- [x] Campo “Código de activación (opcional)”
- [x] Botón “Continuar con publicidad”
- [x] Código válido → pase local → sin ads (HMAC de prueba; API opcional)
- [x] Si falla red al validar (con `REDPOS_API`): guardar igual, modo ads
- [x] Texto de aviso + contacto

### 3. Suscripción (cuenta de usuario)

- [ ] Registro / inicio de sesión **opcional**
- [ ] Pago → membresía activa → mismo efecto que el código
- [x] Imprimir **sin** estar logueado
- [x] Aviso de contacto (placeholder)

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
