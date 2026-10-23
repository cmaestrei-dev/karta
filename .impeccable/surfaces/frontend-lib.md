---
version: 1
slug: "frontend-lib"
primary_target: "frontend/lib"
related_targets: []
---

## Scope and mode

App Android completa de Karta (inicio con mapa, buscador y elegir en el mapa, planificar ruta con opciones, detalle de ruta, reportar incidente, lugares guardados, login y registro). Modo: **Operate**.

## Audience, task and constraints

- Viajero diario de Cartagena (trabajador o estudiante); turista como secundario.
- Tarea principal: decidir en segundos cómo llegar (a pie o en Transcaribe) y qué tan complicado está el recorrido. Tarea secundaria: reportar un incidente en tres toques.
- Uso a pleno sol, con una mano, de pie en el bus, con conexión limitada.
- Datos honestos: tiempos estimados rotulados como estimados, fuente OSM visible, sin llegadas en tiempo real ni tarifas.

## Direction contract

THESIS: Karta lee Cartagena como sus propios muros: cada lugar, estación y ruta lleva su placa de azulejo sobre cal blanca, legible al sol. Rechaza el default de la categoría: mapa oscuro invertido con tarjetas flotantes y acento neón.

OWN-WORLD: Fondo de cal (#FBFAF6) y tinta azul de azulejo (#1D3A8A). Placa = superficie blanca con doble filete azul (exterior 2 dp, interior 1 dp, separados 2 dp), etiqueta en mayúsculas espaciadas. Los colores de fachada son código, nunca adorno: tipo de ruta (troncal ocre #E3A72F, pretroncal azul cobalto, alimentadora verde balcón #2E7D4F, complementaria buganvilla #C2185B) y riesgo (BAJO verde, MEDIO ocre, ALTO ladrillo #B23A26, CRÍTICO ladrillo profundo), siempre con ícono y texto. Mapa OSM claro y algo desaturado, sin inversión. Componentes Material 3 tematizados por roles de color; retícula de 8 dp; cifras tabulares.

STORY: El viajero ve de un vistazo dónde hay problemas, escribe o elige su destino, compara de dos a tres placas de opción (minutos, caminata, riesgo) y sale. Reportar queda a un toque del pulgar.

FIRST VIEWPORT: Inicio. Mapa claro a sangre; arriba, la placa «¿A dónde vas?» con una fila de mini-placas de lugares guardados (Casa, Trabajo, +). Los incidentes son marcas de azulejo con el glifo de la categoría y el color del riesgo. Abajo, una hoja de cal asomada con «Estaciones cerca» (placas con cápsulas de rutas). El botón ocre extendido «Reportar» va abajo a la derecha, sobre la hoja.

FORM: Dirección propia «Cal y azulejo», posición 6 de mi lista ordenada; seed key cc7f88ed. Aportes recibidos: mobiliario fijo por elemento (catálogo de personajes), palabras guía en la cabecera del viaje (léxico), módulo estricto de 8 dp (Crouwel) y cifras tabulares alineadas (Ikeda).

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Signature interaction

Al tocar una opción de ruta, el mapa pinta cada tramo con su código (caminata punteada en tinta, bus en el color de su tipo de ruta) y la hoja muestra los tramos como una secuencia de placas, con palabras guía «Origen → Destino» en la cabecera.

## Unresolved

- No hay una fuente propia: se usa Roboto (la del sistema) para no descargar fuentes con datos limitados.
- El modo oscuro del sistema se respeta como esquema secundario; el claro es el principal por la luz solar.
