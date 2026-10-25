# Fuentes para ubicar los paraderos de Transcaribe

Búsqueda del 25 de octubre de 2026 (D16, D18). De los 948 paraderos del archivo oficial, Karta ubica 224 (estaciones y direcciones); los otros 724 no tienen coordenadas en ninguna fuente pública con licencia abierta.

## Lo que se usa

| Fuente | Qué trae | Licencia | Uso en Karta |
|---|---|---|---|
| «Paradero_Transcaribe 2025», Portal de Datos Abiertos de Cartagena | 948 paraderos en orden por ruta y sentido, con el módulo en las estaciones. Sin coordenadas | CC BY (en datos.gov.co, la misma tabla figura como CC BY-SA 4.0; se cita la del portal distrital) | Nombre, orden, sentido y módulo de cada paradero |
| OpenStreetMap | Recorridos de 24 rutas, estaciones, cruces de calles. Solo unas 26 paradas distintas en las rutas, casi todas estaciones | ODbL | Recorridos, estaciones y cruces para ubicar las direcciones |
| GTFS comunitario ColombiaGTFS (2019) | Paradas de 2019 con coordenadas | CC BY-SA | Solo para medir el error; sus coordenadas no se copian |

## Lo que existe pero no se puede usar todavía

- **Capa «Rutas STM» de la Alcaldía** (ArcGIS Online, cuenta `sig_cartagena`, editada el 4 de junio de 2025): 26 trazados que, según su campo `FolderPath`, salen del archivo de Transcaribe «Trazados de rutas con paradas SITM-TRANSCARIBE 28-10-24.kmz». Se publicaron las líneas, no las paradas, y sin licencia. **Es la fuente más prometedora:** se pide en el [derecho de petición](legal/derecho-de-peticion-transcaribe.md).
- **Capa `shp_transcaribe_paraderos`** (ArcGIS Online, creada el 1 de diciembre de 2022 por un usuario sin organización): 278 puntos con nombre, rutas y sentido, de 13 rutas (dos ya no existen). Coincide por nombre con 234 de las 948 filas. Sin licencia ni autor identificable: no se importa sin permiso.
- **«Rutas y recorridos» de Transcaribe** (PDF de julio de 2024): mapas vectoriales con los puntos de parada. Con derechos reservados: requiere permiso.
- **Mapillary:** fotos de calle con licencia CC BY-SA. Sirven para mapear en OpenStreetMap, y de ahí a Karta, pero no para copiarlas directamente.

## Lo que se probó y no sirvió

- **Nombres de lugar en OSM y repartir entre vecinos** (antes de esta búsqueda): el lugar solía ser el barrio entero o uno equivocado; mediana de 230 m y uno de cada cinco a más de 1,4 km.
- **Nombres geográficos del IGAC** (cartografía 1:2000, 4.985 puntos): emparejando el nombre del paradero con el del lugar, exigiendo que quede a menos de 150 m del recorrido y entre sus vecinos ya ubicados, se ubicaban 67. Pero los emparejamientos eran casi siempre otro lugar con el mismo nombre de barrio: «Iglesia Ternera» con el Centro de Salud de Ternera, «Las Palmeras» con un parqueadero, «Centro Comercial Santa Lucía» a 1,4 km de la parada real. Exigiendo también la clase de lugar («iglesia», «colegio») quedaban 49, y la mitad de los validados seguía a más de 300 m. No se usa.

## No existe

- **GTFS oficial de Transcaribe:** no está en Mobility Database ni en Transitland, ni en los portales de datos abiertos.
- **Coordenadas en los manuales de Transcaribe** (usuario 2015 y 2019, operaciones 2016, señalética 2017): solo planos genéricos.

## Módulos de las estaciones

- **Lo que se sabe:**
  - En el archivo de 2025, el sufijo 1 es siempre la ida (desde el Portal, hacia el Centro) y el 2 la vuelta: 77 de 77 casos cada uno.
  - El Manual de Operaciones (2016) dice que las estaciones dobles tienen un módulo para servicios corrientes y otro para expresos.
  - El Manual de señalética (2017) remite el mapa de cada estación a sus «archivos de producción», que no son públicos.
  - En el Patio Portal: A1–A4 troncales, B1–B6 pretroncales, C1–C3 llegada de alimentadoras y D1–D5 salida.
- **Lo que no se sabe:** en qué extremo de cada estación (hacia el Centro o hacia el Portal) está el módulo A y en cuál el B. No lo dice ningún documento público. Además, una noticia de Transcaribe de octubre de 2024 pone la T101 en el módulo B de Villa Olímpica, que en el archivo de 2025 no existe.
- **Cómo averiguarlo:**
  - la respuesta al derecho de petición;
  - una foto de los letreros «Módulo A/B» en cada estación doble: Bazurto, Centro, Cuatro Vientos, Delicias, La Bodeguita, La Castellana y Madre Bernarda;
  - los Guardianes de estación (D18).

## Próximos pasos

1. Radicar el derecho de petición a Transcaribe y la versión corta a la Alcaldía (ver las [notas](legal/derecho-de-peticion-transcaribe-notas.md)).
2. Si responden con el KMZ o la capa de paraderos con licencia CC BY 4.0, importarlos con un grupo nuevo en `scripts/importar_paraderos.py` y validarlos igual que las direcciones.
3. Mientras tanto, los ubica la comunidad con «Marca este paradero».
