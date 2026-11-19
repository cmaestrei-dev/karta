# Fuentes para ubicar los paraderos de Transcaribe

Búsqueda del 25 de octubre de 2026 (D16, D18). De los 948 paraderos del archivo oficial, Karta ubica 224 (estaciones y direcciones); los otros 724 no tienen coordenadas en ninguna fuente pública con licencia abierta.

**Actualización del 18 de noviembre de 2026:** Transcaribe respondió el derecho de petición con su GTFS, que trae todos los paraderos con coordenadas. Karta ya sabe importarlo, pero no lo usa todavía: falta que Transcaribe diga bajo qué licencia (ver [El GTFS de Transcaribe](#el-gtfs-de-transcaribe-recibido-sin-activar)).

## Lo que se usa

| Fuente | Qué trae | Licencia | Uso en Karta |
|---|---|---|---|
| «Paradero_Transcaribe 2025», Portal de Datos Abiertos de Cartagena | 948 paraderos en orden por ruta y sentido, con el módulo en las estaciones. Sin coordenadas | CC BY (en datos.gov.co, la misma tabla figura como CC BY-SA 4.0; se cita la del portal distrital) | Nombre, orden, sentido y módulo de cada paradero |
| OpenStreetMap | Recorridos de 24 rutas, estaciones, cruces de calles. Solo unas 26 paradas distintas en las rutas, casi todas estaciones | ODbL | Recorridos, estaciones y cruces para ubicar las direcciones |
| GTFS comunitario ColombiaGTFS (2019) | Paradas de 2019 con coordenadas | CC BY-SA | Solo para medir el error; sus coordenadas no se copian |

## El GTFS de Transcaribe: recibido, sin activar

**Qué es:** «GTFS SITM.zip», entregado con el Oficio TC-DO-07.01-01821-26 del 18 de noviembre de 2026, en respuesta a los radicados 3565 y 3777. Va del 1 de enero al 31 de diciembre de 2026.
- **Lo que trae:**
  - las 24 rutas, en 45 recorridos;
  - 602 paradas con coordenadas, incluido cada módulo de las estaciones;
  - los viajes del día, con la hora de cada parada.
- **Lo que no trae:** `agency.txt` ni `calendar_dates.txt`, es decir, sin festivos. El horario es el mismo todos los días en que opera cada ruta. Tampoco trae la A118.
- **La licencia:** no la dieron; solo dijeron que la «tendrán en cuenta». El 18 de noviembre se les pidió por escrito, junto con la A118, la frecuencia de actualización y cómo aplican los horarios en festivos. Mientras no respondan, el archivo y lo que sale de él quedan fuera del repositorio.

**Cómo se importa:** `python -m scripts.importar_gtfs RUTA_AL_ZIP --informe informe.md`, desde `backend/`. Escribe `paraderos.json`, `horarios.json` y las rutas de cada estación en `transcaribe.json`; con `--salida` se escribe en otra carpeta. El script explica qué toma y qué no.

**Lo que dice la primera importación** (el informe completo se queda con el archivo, fuera del repositorio):
- **Paraderos:** 1.012, todos ubicados (191 en estaciones). Hoy Karta tiene 224 ubicados de 948.
- **Precisión de lo que Karta ya ubicaba:**
  - por dirección, mediana de 33 m;
  - estimados, 53 m;
  - en estaciones, 27 m, porque hoy se usa el centro de la estación y no el del módulo;
  - dos paraderos quedaban a más de 300 m.
- **Trazados:** coinciden con los de OpenStreetMap a 2 m en promedio. Por eso no se importan: Karta sigue con los de OSM. Solo la ida de la T102 se aparta (24 m en promedio).
- **Rutas que paran en estaciones donde Karta no las tenía:**
  - X101, X104, X105 y X106 en La Bodeguita;
  - T101 en Villa Olímpica;
  - T103 en Los Ángeles;
  - C017 en Centro;
  - C018 en Chambacú.
- **Horarios:** entre semana, el último despacho sale entre 20 y 60 minutos más tarde que en el archivo de 2025. La A111, la C016 y la C017 ya no operan solo en la mañana: tienen pocos viajes hasta las 7:00–7:30 p. m. Como el GTFS no distingue el fin de semana:
  - entre semana se toma el GTFS;
  - el sábado y el domingo, el GTFS dice si la ruta opera y el archivo de 2025 a qué horas.
- **Variante fuera:** la extensión del X106 (57 viajes entre semana, hasta Sena Ternera).

**Para activarlo, cuando haya licencia:**
1. Correr el importador sobre `backend/data` y revisar el informe.
2. Ajustar las pruebas que suponen los datos de 2025. Con el GTFS fallan 6 de 218:
   - el número de paraderos de una ruta;
   - el horario de la T103;
   - que la C018 no tenga horario;
   - las de «Marca este paradero», que buscan uno sin ubicar.
3. Cambiar los créditos de los datos:
   - `FUENTE_RUTAS` en `route_router.py`;
   - la página de la ruta y el perfil en la app;
   - README y LICENSE.md.
4. Publicar un APK nuevo: los anteriores muestran los paraderos `oficial` como «sin ubicar».
5. Desplegar.

**Después:**
- Usar los lados oficiales de los vagones en lugar de aprenderlos de las subidas (ver [Módulos](#módulos-de-las-estaciones)).
- Que el planificador suba y baje en paraderos reales.
- Estimar la espera con las salidas por hora, que ya se importan.
- Decidir qué hacen los Kartógrafos cuando ya no queden paraderos por ubicar.

## Lo que existe pero no se puede usar todavía

- **Capa «Rutas STM» de la Alcaldía** (ArcGIS Online, cuenta `sig_cartagena`, editada el 4 de junio de 2025): 26 trazados que, según su campo `FolderPath`, salen del archivo de Transcaribe «Trazados de rutas con paradas SITM-TRANSCARIBE 28-10-24.kmz». Se publicaron las líneas, no las paradas, y sin licencia. **Es la fuente más prometedora:** se pide en el [derecho de petición](legal/derecho-de-peticion-transcaribe.md).
- **Capa `shp_transcaribe_paraderos`** (ArcGIS Online, creada el 1 de diciembre de 2022 por un usuario sin organización): 278 puntos con nombre, rutas y sentido, de 13 rutas (dos ya no existen). Coincide por nombre con 234 de las 948 filas. Sin licencia ni autor identificable: no se importa sin permiso.
- **«Rutas y recorridos» de Transcaribe** (PDF de julio de 2024): mapas vectoriales con los puntos de parada. Con derechos reservados: requiere permiso.
- **Mapillary:** fotos de calle con licencia CC BY-SA. Sirven para mapear en OpenStreetMap, y de ahí a Karta, pero no para copiarlas directamente.

## Lo que se probó y no sirvió

- **Nombres de lugar en OSM y repartir entre vecinos** (antes de esta búsqueda): el lugar solía ser el barrio entero o uno equivocado; mediana de 230 m y uno de cada cinco a más de 1,4 km.
- **Nombres geográficos del IGAC** (cartografía 1:2000, 4.985 puntos): emparejando el nombre del paradero con el del lugar, exigiendo que quede a menos de 150 m del recorrido y entre sus vecinos ya ubicados, se ubicaban 67. Pero los emparejamientos eran casi siempre otro lugar con el mismo nombre de barrio: «Iglesia Ternera» con el Centro de Salud de Ternera, «Las Palmeras» con un parqueadero, «Centro Comercial Santa Lucía» a 1,4 km de la parada real. Exigiendo también la clase de lugar («iglesia», «colegio») quedaban 49, y la mitad de los validados seguía a más de 300 m. No se usa.

## No existe

- **GTFS oficial de Transcaribe, publicado:** no está en Mobility Database ni en Transitland, ni en los portales de datos abiertos. Existe, y Transcaribe lo entregó por el derecho de petición (ver arriba).
- **Coordenadas en los manuales de Transcaribe** (usuario 2015 y 2019, operaciones 2016, señalética 2017): solo planos genéricos.

## Módulos de las estaciones

- **Lo que se sabe:**
  - En el archivo de 2025, el sufijo 1 es siempre la ida (desde el Portal, hacia el Centro) y el 2 la vuelta: 77 de 77 casos cada uno.
  - El Manual de Operaciones (2016) dice que las estaciones dobles tienen un módulo para servicios corrientes y otro para expresos.
  - El Manual de señalética (2017) remite el mapa de cada estación a sus «archivos de producción», que no son públicos.
  - En el Patio Portal: A1–A4 troncales, B1–B6 pretroncales, C1–C3 llegada de alimentadoras y D1–D5 salida.
- **Lo que no se sabía:** en qué extremo de cada estación (hacia el Centro o hacia el Portal) está el módulo A y en cuál el B. No lo dice ningún documento público. Además, una noticia de Transcaribe de octubre de 2024 pone la T101 en el módulo B de Villa Olímpica, que en el archivo de 2025 no existe.
- **Lo que dicen el oficio y el GTFS (18 de noviembre de 2026):**
  - En las estaciones, la letra es el vagón y el número el sentido. En el Portal, A y B son andenes de troncales y pretroncales, y C y D de alimentadoras.
  - Según las coordenadas de los módulos en el GTFS, en las siete estaciones dobles el vagón B queda hacia el Centro, en todos los recorridos de ida. Los dos vagones quedan a entre 53 y 99 m.
  - El GTFS pone la T101 en Villa Olímpica.
  - Conviene confirmarlo con una foto de los letreros antes de mostrarlo como seguro.
- **Cómo averiguarlo:**
  - la respuesta al derecho de petición;
  - una foto de los letreros «Módulo A/B» en cada estación doble: Bazurto, Centro, Cuatro Vientos, Delicias, La Bodeguita, La Castellana y Madre Bernarda;
  - los Guardianes de estación (D18).

## Próximos pasos

1. Esperar la licencia del GTFS (pedida el 18 de noviembre de 2026) y activarlo como dice [arriba](#el-gtfs-de-transcaribe-recibido-sin-activar).
2. Mientras tanto, los ubica la comunidad con «Marca este paradero».
