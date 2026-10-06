# Política de privacidad — RedPOS Service

**Última actualización:** 28 de septiembre de 2026  
**Package ID:** `com.redpos.service`  
**URL Play Console (HTTPS):** https://redpos-codigos-prueba.vercel.app/privacidad.html  
**Eliminar cuenta:** https://redpos-codigos-prueba.vercel.app/eliminar-cuenta.html  

Copia en markdown de la política alojada. La app también muestra el texto en  
**Ayuda → Datos y privacidad** y **Política de privacidad (completa)**.

## 1. Responsable

RedPOS (marca de Red Soluciones / [redsoluciones.com.pe](https://www.redsoluciones.com.pe)).  
Contacto: jcefe.2920@gmail.com

## 2. Qué se recoge y qué no

**Local (SharedPreferences / aparato):**

- Impresoras vinculadas (nombre, tipo, Bluetooth/MAC, IP, USB)
- Márgenes, corte, historial de trabajos
- Plantillas de tickets propios (incl. logos)
- Ajustes y logo del ticket SUNAT
- Pase de licencia/código, entitlement Play, correo Google si te suscribes

**Hacia RedPOS:** solo canje de código de activación cuando la API está configurada  
(código + identificador opcional de impresora). **No** se sube PDF/imagen/XML de la boleta.

**No incluimos** SDK de Firebase, Crashlytics, Google Analytics ni AdMob, ni tracking publicitario.  
Los servicios de Google que sí usa la app (Google Play Billing y Google Sign-In) pueden enviar a Google
telemetría técnica propia de esos servicios (p. ej. diagnóstico de la librería de facturación), regida por
la política de privacidad de Google.  
La publicidad en pantalla y pie de papel es de primera parte (RedPOS).

## 3. Inteligencia artificial

**Esta app no utiliza inteligencia artificial generativa** ni modelos de ML sobre el  
contenido del usuario. Raster ESC/POS, recorte de vouchers y parseo XML SUNAT son  
algoritmos tradicionales.

## 4. Terceros y APIs

| Servicio | Uso |
|----------|-----|
| Google Play Billing (`in_app_purchase`) | Suscripción `redpos_ads_free_monthly` |
| Google Sign-In | Solo al suscribirse |
| API códigos RedPOS (HTTPS / Vercel) | Canje de código |
| url_launcher | Correo / web / WhatsApp |
| Plugins impresión (BT/USB/TCP, pdfx, image, esc_pos_*) | Impresión local |
| SharedPreferences | Persistencia local |

## 5. Eliminación

1. **App:** Ayuda → Datos y privacidad → Borrar datos locales  
2. **Play:** Pagos y suscripciones → cancelar  
3. **Servidor:** [eliminar-cuenta.html](https://redpos-codigos-prueba.vercel.app/eliminar-cuenta.html) o correo (≈ 30 días)

## Relacionado

- HTML desplegado: `admin-web/public/privacidad.html`
- Texto in-app: `lib/legal/legal_copy.dart`
- Pantalla: `lib/screens/privacy_data_screen.dart`
- Distribución Play: [DISTRIBUCION.md](DISTRIBUCION.md)
