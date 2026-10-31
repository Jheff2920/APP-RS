# Impresoras lógicas independientes (Android)

Rama: `feature/impresoras-logicas-independientes`. Validación física pendiente
con el usuario: la compilación y las pruebas automáticas no certifican el
protocolo ni el sensor de una HQ300 concreta.

## Configuración y prueba

1. Instalar el APK de prueba y abrir RedPOS Service una vez para migrar y
   sincronizar las impresoras. La configuración anterior queda como respaldo.
2. Editar la HQ300 existente: nombre `HQ300-Recibos`, uso **Recibos**. Conservar
   sus ajustes. Las seis medidas históricas, incluidas Max y Google, siguen
   disponibles; se pueden deshabilitar medidas individualmente.
3. Pulsar **Vincular otra impresora**. En **Usar un equipo registrado**, elegir
   la HQ300; escribir `HQ300-Etiquetas` y seleccionar **Etiquetas**.
4. Elegir el ancho del rollo/cabezal y DPI adecuados. Conservar ESC/POS si se
   prueba como impresora de recibos; seleccionar TSPL únicamente si el hardware
   lo admite. Guardar. Las capacidades del hardware se consideran desconocidas
   hasta verificarlas; no se deducen del nombre comercial.
5. Desde un lector PDF o sistema externo compatible, abrir **Imprimir** y
   **Todas las impresoras**. Deben aparecer ambos nombres. Recibos solo debe
   mostrar recibos; Etiquetas solo 50 × 25 y 30 × 20 mm inicialmente.
6. En Etiquetas, editar o agregar tamaños con ancho, alto, márgenes, GAP,
   desplazamientos y escala. Elegir su tamaño predeterminado y guardar. Abrir
   nuevamente el selector y comprobar la actualización. La sesión activa
   también recibe actualizaciones; la interfaz del selector y su refresco
   dependen de la versión de Android y de la aplicación que imprime.
7. Imprimir los PDF de muestra, probar ambas orientaciones, varias páginas y
   copias. El borde debe quedar a 2 mm del borde del papel y la raya mide 10 mm
   con ajustes sin márgenes ni calibración adicional.

Generar muestras: `python tool/create_label_test_pdfs.py`. Se guardan en
`inst-apk/impresoras-logicas/`. Cada PDF tiene tres páginas del tamaño indicado.
El PDF de etiquetas debe tener el tamaño de página correcto: este camino
conserva el espacio blanco y ajusta la página completa, sin el recorte de recibos.

**ESC/POS:** avanza una distancia fija; GAP añade avance. No configura ni activa
un sensor. **TSPL:** envía SIZE/GAP y el mapa de bits para cada etiqueta. Cambiar
el lenguaje en la app no cambia por sí solo el modo de firmware del equipo.
En etiquetas no se añaden publicidad en papel, corte de recibos ni gaveta.

## Matriz manual de aceptación

- [ ] Ambos nombres aparecen por separado, también tras reiniciar Android.
- [ ] Cada destino anuncia exclusivamente sus medidas habilitadas.
- [ ] Renombrar Etiquetas o agregar 40 × 30 no cambia Recibos.
- [ ] Ambas imprimen por la misma conexión física, con papel adecuado instalado.
- [ ] Recibos conserva dimensiones, recorte, nitidez, publicidad/pase, corte y gaveta.
- [ ] Tres etiquetas consecutivas respetan medidas y separación; no hay deriva.
- [ ] Orientación, márgenes, desplazamientos, escala y copias son correctos.
- [ ] Envíos desde la app y desde el sistema no intercalan bytes ni conexiones.
- [ ] Sin permiso de superposición, la notificación conserva destino y medida.
- [ ] Borrar una lógica no elimina la otra ni olvida su Bluetooth compartido.
- [ ] Apagado, reconexión, cancelación y reimpresión muestran un resultado coherente.

Registrar modelo/firmware, transporte, DPI real, lenguaje aceptado, sensor y
resultado de las muestras antes de dar el hardware por compatible.

## Persistencia y compatibilidad

`printer_catalog_v2` contiene una colección física y otra lógica. Cada lógica
conserva su UUID; los perfiles tienen identidad y propietario. `SavedPrinter`
es una vista compatible para los renderizadores de recibos y los transportes.
El respaldo original `saved_printers_v1` se conserva durante la migración;
el borrado de datos elimina ambos. No se usa el respaldo como catálogo activo
cuando ya existe v2, para evitar resucitar impresoras eliminadas.

La copia nativa `boleta_print/saved_printers_v2` publica una entrada por lógica.
Android recibe `generatePrinterId(logicalId)`, capacidades independientes y
medidas personalizadas. Los IDs históricos de recibos y su ancho especial para
Chrome permanecen iguales. La configuración del trabajo se copia para evitar
que un cambio posterior mezcle sus ajustes. Un ID explícito inexistente falla;
no se sustituye por el destino predeterminado.

La reserva de conexión cubre el trabajo completo en Dart y en el servicio
Android. Como los transportes existentes mantienen manejadores globales,
actualmente se serializan todos los trabajos de la instalación. Esto incluye
equipos distintos y evita introducir conexiones simultáneas sobre esos
manejadores. No coordina otras aplicaciones, teléfonos ni tablets.
