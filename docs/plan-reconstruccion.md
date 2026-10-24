# Plan de reconstrucción de Karta (v2)

**Estado:** propuesta, 24 de octubre de 2026 · **Entrega final:** finales de noviembre de 2026 (se asume el viernes 27; por confirmar).
**Diseño de referencia:** mockups de la ronda 3, dirección «Bahía» (canvas de mockups, páginas Ronda 2 y Ronda 3).

## 1. Qué es Karta v2

Karta deja de ser un mapa de incidentes con un planificador básico y pasa a ser **el tiempo real de Transcaribe hecho por sus pasajeros**:

- **Planificar:** buscar el destino, comparar las formas de llegar en el mapa (más rápida, más segura, sin transbordo) e iniciar el viaje.
- **Viajar acompañado:** modo de viaje paso a paso («Sube al T103», «Bájate en 3 paradas»), aviso antes de bajarse y alertas de lo que viene en la ruta.
- **Reportar y confirmar:** reportes por categorías concretas con ilustraciones propias. Otros viajeros los confirman o los desmienten, y la reputación premia a quien reporta bien.
- **Tiempo real comunitario:** «el T103 pasó hace 4 min, lo vieron 3 viajeros», qué tan lleno va y la posición anónima del bus mientras alguien viaja en él.

Sin anuncios, sin transporte privado y con el mismo backend hexagonal (FastAPI + MongoDB), que se extiende en vez de reescribirse.

## 2. Por qué

1. **Prueba en un teléfono real** (POCO X7 Pro, 23 de octubre). La versión «Cal y azulejo» no convenció en uso: botones poco claros, sin animaciones, sin forma de iniciar la ruta elegida y una escala de intensidad de 1 a 5 ambigua.
2. **Comparativa con Waze, Moovit y MiBus en el mismo teléfono:**
   - MiBus anuncia tiempo real, pero en sus paraderos dice que no lo tiene, y su búsqueda de rutas no funciona.
   - Moovit conoce las rutas, pero llena el flujo de anuncios, pone Uber de primero y cobra por funciones.
   - Waze resuelve muy bien reportar y navegar, pero solo para carro.
   - **El hueco que nadie llena es el tiempo real del pasajero.**
3. **La primera entrega prometió casos de uso que aún no existen** (sección 3).

## 3. Trazabilidad con la primera entrega

| Caso de uso (primera entrega) | Hoy | Qué lo completa en v2 | Fase |
|---|---|---|---|
| #1 Registrarse, #2 Iniciar sesión | Hecho (JWT) | Alias público para la comunidad | 1 |
| #3 Consultar ruta intermodal | Parcial: una ruta, sin transbordos | Transbordo, criterios de ruta, puntos de subida nombrados por cruce, horarios oficiales | 2 |
| #4 Notificar cambio de modalidad | No | Aviso al llegar a la parada, antes de bajarse y en el transbordo | 3 |
| #5 Reportar incidente vial | Hecho con escala 1–5 | Categorías y detalles concretos, con ilustraciones | 1 |
| #6 Visualizar mapa de eficiencia | Parcial | Mapa propio con la troncal, reportes y buses vistos por la comunidad | 1 y 3 |
| #7 Alertar cambio de modalidad | No | Alerta de incidente adelante en la ruta, con alternativas | 3 |
| #8 Monitorear ubicación | No | Viaje activo por GPS y posición anónima del bus | 3 |
| #9 Validar incidente / reporte | No | «¿Sigue ahí?», votos y reputación de quien reporta y de quien valida | 1 |
| #10 Re-enrutar | No | Nueva sugerencia cuando la ruta actual queda bloqueada | 3 |

## 4. Decisiones técnicas

**D1 · Mapa vectorial con estilo propio** (decidido en la fase 0; ver [decisiones-fase0.md](decisiones-fase0.md), F0-1).
- **Propuesta:** `flutter_map` 8 con `flutter_map_vector_tiles` y teselas de OpenFreeMap (gratis, sin clave, datos de OpenStreetMap), más un estilo «Bahía» propio en claro y oscuro: agua profunda, solo vías principales, la troncal resaltada y pocas etiquetas.
- **Por qué esta opción:** conserva lo que ya funciona (marcadores como widgets de Flutter y animaciones de líneas).
- **Alternativa:** `maplibre_gl` (nativo, más rápido, pero los marcadores y las animaciones son más rígidos).
- **Cómo se decide:** una prueba en la fase 0, en el POCO, con cuatro criterios: fluidez al mover el mapa, carga con datos móviles, marcadores ilustrados y peso del APK.

**D2 · Incidentes v2.**
- La categoría + intensidad se reemplaza por **grupo → tipo → detalles**. Ejemplo: servicio → «el bus no pasa» → {ruta: T103, espera: 20 min}.
- El servidor publica el catálogo de tipos (una sola fuente de verdad). Cada tipo define su peso en el riesgo y su vigencia base.
- **Votos** «sigue / ya no»: un voto por viajero y reporte.
  - Cada «sigue» extiende la vigencia.
  - Dos «ya no» sin «sigue» posteriores lo retiran.
- **Reputación:** suma cuando un reporte tuyo es confirmado y resta cuando lo desmienten.

**D3 · Tiempo real comunitario**, en tres fuentes, de la más simple a la más ambiciosa:
1. **Avistamientos:** «vi pasar el T103» desde un paradero, con ocupación opcional.
2. **Ocupación** reportada desde dentro del bus: con puestos, de pie, muy lleno.
3. **Posición compartida:** durante un viaje activo y solo con permiso explícito, la app envía la posición cada ~30 s asociada a un viaje anónimo, no al usuario.

Con eso el servidor estima «sale en ~6 min, según 3 viajeros». Todo vence solo con índices TTL de 5 a 30 minutos y nunca se guarda un historial de ubicaciones (Ley 1581).

**D4 · Viaje activo.**
- **Máquina de estados en la app:** caminando a la parada → esperando → a bordo → caminando al destino → llegaste.
- **Avance por GPS:** se pasa de un estado a otro por cercanía a la parada y a la ruta.
- **Servicio en primer plano** con notificación permanente: `geolocator` en Android 14+.
- **Notificaciones locales** para «bájate en la próxima».
- **Xiaomi y MIUI/HyperOS** cierran servicios en segundo plano, así que la app guía al usuario a configurar el autoinicio y la batería.

**D5 · Planificador v2.**
- Agrega un **transbordo** entre dos rutas.
- **Tres criterios:** más rápida (tiempo), más segura (riesgo con más peso) y sin transbordo.
- **Horarios de servicio** del Portal de Datos Abiertos de Cartagena («Rutas_Transcaribe 2025.xlsx», licencia CC-BY): evitan sugerir rutas que no operan a esa hora.
- **Paraderos:** el archivo oficial de paraderos no trae coordenadas (ver [decisiones-fase0.md](decisiones-fase0.md), F0-2). Fuera de la troncal, el punto de subida se nombra por el cruce de calles más cercano («Paradero Pedro de Heredia con Cra. 28»). Los paraderos reales los marcará la comunidad después de la entrega final.

**D6 · Sistema de diseño «Bahía».**
- **Tokens** de color en claro y oscuro.
- **Tipografía:** Manrope empaquetada en la app.
- **Componentes:** hoja inferior, botones, chips, burbujas y barra de viaje.
- **Ilustraciones:** las nueve de reporte, en SVG con `flutter_svg`.
- **Animaciones:** el recorrido que se dibuja, los reportes que caen y las hojas que suben, respetando la opción de reducir movimiento del sistema.
- **Documentación:** reemplaza a «Cal y azulejo»; DESIGN.md se reescribe al final de la fase 1.

**D7 · Despliegue.**
- **Datos:** MongoDB Atlas M0, gratis.
- **API:** el contenedor de la API en un servicio gratuito con HTTPS. Render es la primera opción; en la fase 0 se verifican sus condiciones actuales.
- **Distribución:** APK de *release* firmado para el piloto.
- **Desarrollo:** se mantiene Docker Compose y la prueba en el teléfono por cable (`adb reverse`).

**D8 · Calidad.**
- **Integración continua** (GitHub Actions): pytest con MongoDB, `flutter analyze` y `flutter test` en cada PR.
- **Pruebas** de cada regla nueva: votos, vigencias, transbordos, estimación de llegada.
- **Prueba en el POCO** por adb antes de fusionar cada fase.
- **Seguridad:** límite de frecuencia de peticiones (pendiente de la segunda entrega).
- **Accesibilidad:** etiquetas para TalkBack, contraste ≥ 4,5:1 y texto al 130 %.

## 5. Modelo de datos v2 (MongoDB)

| Colección | Cambio |
|---|---|
| `incidents` | Sale `categoria` e `intensidad`; entran `grupo`, `tipo` y `detalles`, contadores `votos_si` y `votos_no`, y `expira_en` dinámica (TTL). |
| `incident_votes` (nueva) | `{incidente, usuario, sigue, en}`; índice único (incidente, usuario); vence con el incidente. |
| `sightings` (nueva) | `{ruta, paradero, ubicacion, ocupacion?, en}`; TTL de 30 min; sin datos del usuario más allá de un hash para evitar duplicados. |
| `live_trips` (nueva) | `{viaje (aleatorio), ruta, ubicacion, en}`; TTL de 5 min; un documento por viaje, que se sobrescribe. |
| `intersections` (nueva, referencia) | Cruces de calles con nombre (de OSM), con `2dsphere`, para nombrar los puntos de subida. |
| `route_schedules` (nueva, referencia) | Primer y último servicio de cada ruta por tipo de día. |
| `users` | Entran `alias`, `reputacion` (ya existía, ahora cambia con los votos), `nivel` y contadores; se mantienen los lugares guardados embebidos. |

## 6. API v2 (cambios)

| Método y ruta | Qué hace |
|---|---|
| `GET /incidents/types` | Catálogo de grupos, tipos, detalles y vigencias. |
| `POST /incidents` | Reportar con `tipo` y `detalles` (reemplaza el esquema anterior). |
| `GET /incidents?bbox=` | Incidentes vigentes del área visible del mapa. |
| `POST /incidents/{id}/votes` | «Sigue ahí» / «ya no está». |
| `POST /sightings` | «Vi pasar el T103» y ocupación. |
| `GET /stops/{id}/live` | Buses vistos por la comunidad y estimación de paso. |
| `POST /trips` · `POST /trips/{id}/positions` · `DELETE /trips/{id}` | Viaje activo y posición compartida anónima. |
| `GET /routes/{codigo}` | Página de la ruta: paraderos y horario. |
| `POST /routes/suggest` | Agrega `criterio` (rápida, segura, sin transbordo) y transbordos. |
| `GET /users/me/stats` | Reputación, nivel y reportes confirmados. |

## 7. Arquitectura de la app v2

Se mantiene el patrón BLoC por funcionalidad y se reorganiza así:

- `core/design`: tokens, tipografía, componentes e ilustraciones.
- `core/map`: estilo vectorial, capas, burbujas y animaciones.
- `core/location` y `core/notifications`.
- `features/`:
  - `inicio` (mapa)
  - `buscar`
  - `planificar`
  - `viaje` (máquina de estados)
  - `reportes` (crear y confirmar)
  - `comunidad` (avistamientos y ocupación)
  - `perfil`
  - `auth`

Los incidentes y los paraderos se guardan en caché para que la app abra útil con mala señal.

## 8. Fases y calendario

Cada fase termina con una demostración en el teléfono y un PR fusionado.

| Fase | Fechas | Objetivo | Hecho cuando |
|---|---|---|---|
| 0 · Cimientos | sáb 24 – mar 27 oct | Prueba del mapa vectorial (D1), sistema de diseño base, ilustraciones en SVG, integración continua, revisión de los datos abiertos y del despliegue | Decidido el mapa con evidencia del POCO; CI en verde; tokens y fuentes en la app |
| 1 · Mapa y reportes | mié 28 oct – mar 3 nov | Inicio con mapa propio; reportes v2 (catálogo, dos pasos, detalles); «¿Sigue ahí?», votos y reputación; límite de peticiones | En el teléfono se reporta «el bus no pasa», otro usuario lo confirma y la reputación cambia |
| 2 · Planificar | mié 4 – mar 10 nov | Búsqueda; puntos de subida nombrados por cruce; opciones comparadas en el mapa; criterios; transbordo; horarios de servicio | De Bazurto a Bocagrande salen opciones con y sin transbordo, ordenadas por criterio |
| 3 · Viaje activo y tiempo real | mié 11 – mar 17 nov | Máquina de estados; avisos de subir, bajar y transbordar; alertas y re-enrutar; avistamientos, ocupación y posición compartida; estimación «según N viajeros» | Un viaje real en el T103 avanza solo y avisa antes de bajarse |
| 4 · Despliegue y piloto | mié 18 – lun 23 nov | API en la nube con HTTPS; APK firmado; piloto con compañeros durante 4–5 días; corrección de errores, rendimiento y accesibilidad | Hay datos reales del piloto y no queda ningún error crítico abierto |
| 5 · Cierre | mar 24 – vie 27 nov | Documentación final (diagramas, modelo de datos, API, DESIGN.md), resultados del piloto, presentación y video demo | Entrega lista con un día de margen |

## 9. Cómo trabajamos

- **Una rama y un PR por fase**, con integración continua en verde y prueba en el POCO antes de fusionar. Commits convencionales.
- **Camilo prueba en su teléfono** cada avance y decide sobre el diseño.
- **Propuesta para José (por acordar):**
  - mantener los diagramas y documentos de la entrega al día;
  - reclutar y coordinar el piloto con compañeros;
  - revisar los datos abiertos de paraderos.
- **Los mockups** del canvas siguen siendo la referencia visual. Las pantallas que falten (perfil, página de ruta, llegaste) se diseñan dentro de la fase correspondiente.

## 10. Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| El mapa vectorial va lento o falla en Android | La prueba de la fase 0 decide. El plan B es un mapa raster con el estilo más cercano posible. |
| Xiaomi cierra el viaje activo en segundo plano | Servicio en primer plano, guía de permisos en la app y prueba en el POCO desde la fase 3. |
| Al principio no hay datos de la comunidad | Piloto con compañeros en la fase 4. Para la presentación, un modo demo **claramente etiquetado** como tal; nunca se mezcla con datos reales. |
| Reportes falsos o abuso | Votos, reputación, vigencias cortas, límite de peticiones y un voto por usuario. |
| Privacidad de la ubicación (Ley 1581) | Consentimiento explícito y revocable, viajes anónimos, TTL corto y sin historial. |
| Datos abiertos incompletos o desactualizados | Contrastar con OpenStreetMap y mostrar la fuente y la fecha. |
| Falta de tiempo | Recortes en este orden: (1) posición compartida en vivo, (2) transbordos, (3) niveles de reputación. El resto es el núcleo. |

## 11. Fuera de alcance (después de la entrega final)

- Busetas y rutas tradicionales: datos abiertos del distrito o mapeo comunitario.
- iOS y web.
- Saldo de la tarjeta: depende de los sistemas de Transcaribe.
- Monetización (diferida).
- Transporte privado: excluido.

## 12. Preguntas abiertas

1. Fecha exacta de la entrega final y qué pide su plantilla.
2. Rol de José en el plan.
3. ¿Se hace el piloto con compañeros? Requiere la API desplegada y su consentimiento.
