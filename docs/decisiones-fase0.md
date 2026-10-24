# Decisiones de la fase 0 (24–27 de octubre de 2026)

Registro de lo que se probó y decidió antes de reconstruir Karta. Cada decisión dice qué se eligió, por qué y qué se descartó, para que el resto del plan ([plan-reconstruccion.md](plan-reconstruccion.md)) se apoye en evidencia.

## F0-1 · Mapa vectorial con estilo propio

- **Estado:** **decidido** el 24 de octubre de 2026, con medición en el POCO X7 Pro (sección «Resultado»).
- **Opción probada:** `flutter_map` 8 + `flutter_map_vector_tiles` 2.10 con teselas de OpenFreeMap y el estilo «Bahía». El estilo lo genera [`frontend/tool/estilo_mapa.py`](../frontend/tool/estilo_mapa.py) en claro y oscuro: 12 a 15 capas, solo vías que orientan y pocas etiquetas.
- **Por qué primero esta:**
  - conserva los marcadores como widgets, lo que permite las ilustraciones y las animaciones de Flutter;
  - conserva las líneas animadas que ya existen;
  - no cambia la compilación de Android.
- **La alternativa, `maplibre_gl` 0.27,** exige JDK 21 (el equipo tiene JDK 17) y usa vistas nativas. Solo se evalúa si la primera falla.
- **Prueba en el teléfono:** una app aparte (`co.karta.spike_mapa`, compilación *profile*, 24,5 MB) compara vector oscuro, vector claro y el mapa raster actual sobre la T103, con cuatro reportes ilustrados. Registra cada 5 s el tiempo de cuadro (p50 y p90) y el porcentaje de cuadros de más de 16,7 ms.
- **Criterios:**
  - p90 del cuadro ≤ 16,7 ms al mover el mapa;
  - estilo cargado en < 1 s;
  - etiquetas legibles;
  - las ilustraciones nítidas.

**Resultado** (POCO X7 Pro, compilación *profile*, la misma secuencia de arrastres y dobles toques en cada modo):

| Modo | Estilo listo | Cuadro p50 en movimiento | Cuadro p90 en movimiento | Cuadros de más de 16,7 ms |
|---|---|---|---|---|
| Vector oscuro «Bahía» | 524 ms la primera vez, 133 ms con caché | 5,0–6,1 ms | 5,7–8,6 ms | 0,5–2,6 % |
| Vector claro «Bahía» | 12 ms (con caché) | 4,3–5,1 ms | 5,8–6,4 ms | 0,0–0,3 % |
| Raster OSM con filtro (el de hoy) | — | 4,6–4,9 ms | 5,6–7,2 ms | 0,0–1,7 % |

- La carga inicial de teselas es el único momento con tirones: el 11 % de los cuadros tarda más de 16,7 ms durante los primeros 5 s.
- Todo lo demás cumple el criterio con holgura y queda a la par con el mapa actual.
- Las etiquetas (barrios y vías) y las ilustraciones se ven nítidas.
- **Visualmente gana el vector con claridad:** el raster actual se ve recargado y con tono café; el estilo «Bahía» deja ver la ruta y los reportes.

**Decisión:** `flutter_map` + `flutter_map_vector_tiles` + OpenFreeMap con el estilo «Bahía». `maplibre_gl` no hace falta.

**Ajustes para la fase 1:**
- en el tema oscuro, subir el contraste entre agua y tierra (hoy se distinguen poco);
- revisar la atribución, que hoy repite el símbolo ©.

La app de prueba se desinstaló del teléfono al terminar.

## F0-2 · Datos abiertos de Transcaribe

Se revisó el [Portal de Datos Abiertos de Cartagena](https://datosabiertos.cartagena.gov.co/organization/sistema-integrado-de-transporte-masivo-transcaribe). Licencia CC-BY: hay que citar la fuente en la app.

- **Rutas («Rutas_Transcaribe 2025.xlsx», 25 rutas):**
  - trae código, nombre, tipo, longitud y el **primer y último servicio** por tipo de día (lunes a viernes, sábado, domingo y festivos);
  - **se usa en la fase 2** para no sugerir rutas fuera de horario.
- **Paraderos («Paradero_Transcaribe 2025.xlsx», 948 filas):**
  - trae código, descripción textual («Bicentenario Mz 75»), ruta, sentido y horario;
  - **no trae coordenadas**, así que no sirve para ubicar paraderos en el mapa;
  - OpenStreetMap tiene apenas 103 paraderos en Cartagena (38 con nombre).
- **Decisión:**
  - las estaciones de la troncal siguen saliendo de OSM;
  - fuera de la troncal, el punto de subida se nombra por el **cruce de calles más cercano** (calles de OSM);
  - la descripción oficial del paradero se muestra cuando se pueda emparejar por ruta y sentido;
  - **los paraderos reales los marcará la comunidad** («aquí para el X104»), después de la entrega final, junto con las busetas.

## F0-3 · Despliegue para el piloto

- **API:** el contenedor Docker actual en el plan gratuito de Render.
  - 512 MB de RAM, 0,1 vCPU y 750 h al mes.
  - Se duerme tras 15 min sin uso y tarda de 30 a 60 s en despertar.
- **Datos:** MongoDB Atlas M0, gratis y sin vencimiento.
  - 512 MB, 100 operaciones por segundo.
  - Se pausa tras 30 días sin conexiones.
  - Soporta los índices `2dsphere` y TTL que usa Karta.
- **Mitigaciones:**
  - la app muestra «despertando el servidor» en la primera petición lenta;
  - durante el piloto, un ping programado cada 10 min mantiene la API despierta;
  - la planificación de rutas es lo más pesado en 0,1 vCPU, así que se mide en la fase 4.
- **Plan B:** otro proveedor de contenedores. Para la demo siempre queda el portátil con `adb reverse`.

## F0-4 · Integración continua

- [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) corre en cada PR y en `main`:
  - pytest contra un MongoDB 8 de servicio;
  - `flutter analyze` y `flutter test`.
- Las pruebas de integración ya no se saltan en silencio si falta la base: con `KARTA_EXIGIR_MONGO=1` fallan. CI activa esa variable.

## F0-5 · Base del sistema de diseño «Bahía»

- **Tokens:** [`lib/core/design/bahia.dart`](../frontend/lib/core/design/bahia.dart) como `ThemeExtension`, con paleta oscura y clara, colores de grupo de reporte y colores de ruta.
- **Tipografía:** Manrope (OFL), empaquetada en pesos fijos 400 a 800.
- **Ilustraciones:** las nueve de reporte, en SVG, en `assets/ilustraciones/`, con el widget `Ilustracion` y claves iguales a las del futuro catálogo del backend.
- **Pruebas** ([`test/bahia_design_test.dart`](../frontend/test/bahia_design_test.dart)):
  - contraste ≥ 4,5:1 de todos los textos en ambos temas y del texto blanco sobre las cápsulas de ruta;
  - existencia de cada ilustración;
  - validez de los estilos de mapa.
- **Pendiente para la fase 1:** las pantallas siguen usando el tema anterior. La fase 1 lo reemplaza por «Bahía» y reescribe DESIGN.md.
