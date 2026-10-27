# Plan: otros transportes públicos de Cartagena

**Estado:** investigación y plan del 26 de octubre de 2026. Es **solo un plan**: nada de lo que propone está hecho.

**Por qué ahora:** Camilo quiere sumar los otros transportes públicos antes del [plan para turistas](pendientes.md#4-planes-que-vienen-después). Hoy Karta cubre solo Transcaribe y la caminata. En la [primera comparación](comparacion-apps.md), Moovit le ganó a Karta tres trayectos usando busetas tradicionales.

**Reglas que no cambian:**
- **Sin transporte privado:** nada de Uber, DiDi, InDriver ni similares.
- **Sin anuncios ni comisiones:** no se venden pasajes ni hay enlaces de afiliados.
- **Nunca se copian datos de Google Maps, Moovit ni Waze.** Los datos salen de fuentes oficiales, de datos abiertos, del mapeo de la comunidad o de convenios.

## Resumen

| Prioridad | Modo | Por qué | De dónde salen los datos | Esfuerzo |
|---|---|---|---|---|
| **0** | **Transcaribe al día** | A Karta le falta la A118 (opera desde el 27 de octubre de 2025) y la extensión de la X106 hasta Turbaco en hora pico; hay busetones nuevos en la C001 y la C018 | La respuesta de Transcaribe a la petición | Días |
| **P1** | **Buses, busetas y microbuses (TPC)** | Conservan hasta el 30 % de la ciudad, sin plan de reemplazo; son la razón por la que Moovit gana viajes | Petición al DATT y a las empresas, mapeo comunitario, aporte a OpenStreetMap | 6–10 semanas |
| **P2** | **Corredores Turbaco y Arjona** | Mucho volumen: 79.251 despachos a Arjona y 37.102 a Turbaco entre enero de 2025 y abril de 2026 | Ministerio de Transporte, Terminal de Transportes, datos de Supertransporte, mapeo | 2–4 semanas |
| **P3** | **Lanchas de residentes** | La única opción para Tierrabomba, Bocachica y Caño del Oro | Petición a DIMAR y a Corpoturismo, mapeo comunitario | 2–3 semanas |
| Seguimiento | **Transcaribe Acuático** | Piloto anunciado para noviembre o diciembre de 2026; las fechas se han corrido tres veces | Pedirle a Transcaribe su GTFS apenas exista | Bajo |
| **P4** (opcional) | **Tarifas oficiales de taxi** | Información útil contra cobros de más | El decreto de tarifas | 1–2 semanas |
| **P5** | **Ciclorrutas** | Hay poca infraestructura todavía | OpenStreetMap | Bajo |

**Fuera de alcance:** el transporte privado; el mototaxismo, los colectivos informales y los bicitaxis como modos que se recomiendan; vender pasajes o hacer reservas; y las lanchas turísticas y los tours, que van al plan para turistas.

## 0. Transcaribe al día

Antes de sumar otros modos hay que tener completo el que ya está:
- **A118:** opera desde el 27 de octubre de 2025 ([El Universal](https://www.eluniversal.com.co/cartagena/2025/10/25/nueva-ruta-de-transcaribe-asi-sera-su-recorrido-y-horario/)). No está en `transcaribe.json` ni en el archivo de paraderos.
- **X106:** en hora pico se extiende hasta la Gobernación, en Turbaco. Karta la tiene solo hasta el Centro.
- **Flota:** desde el 28 de agosto de 2026 circulan 17 busetones en alimentadoras, la C001 y la C018. Hay buses eléctricos en camino ([El Universal](https://www.eluniversal.com.co/cartagena/2026/08/28/los-nuevos-buses-de-transcaribe-ya-ruedan-por-cartagena-estas-son-sus-rutas/)).
- **No habrá Fase 3** del sistema ([Informe de Calidad de Vida 2025, Cartagena Cómo Vamos](https://cartagenacomovamos.org/wp-content/uploads/2026/07/ICV_Informe-Calidad-de-Vida_Cartagena_2025_CCV.pdf)).

**Qué hacer:** cruzar la respuesta de Transcaribe con las 24 rutas de Karta. Mientras llega, mapear la A118 con «Mapear desde el bus».

## 1. Buses, busetas y microbuses (TPC)

### Qué hay

- **No se van a acabar.** Los acuerdos de 2023 dejaron a Transcaribe con hasta el 70 % del distrito y al transporte colectivo tradicional (TPC) con hasta el 30 %, «sin cronograma de reemplazo» (Informe de Calidad de Vida 2025).
- **Su flota se reduce sin reponerse.** Los decretos de 2011 congelaron la flota. El 23 de octubre de 2026 el Tribunal Administrativo de Bolívar negó reponer unos 56 vehículos ([El Universal](https://www.eluniversal.com.co/cartagena/2026/10/23/volveran-los-buses-y-busetas-a-circular-por-cartagena-juez-tomo-decision/)).
- **Sus rutas siguen cambiando por decreto:**
  - Decreto 2121 de 2025: Nuevo Bosque–Calamares ([Alcaldía](https://www.cartagena.gov.co/noticias/datt-reestructura-ruta-nuevo-bosque-calamares-para-mejorar-cobertura-beneficiar-mas-usuarios));
  - decretos 2124 y 2127 de 2025: una ruta nueva y una ampliación de Coointracar ([El Universal](https://www.eluniversal.com.co/cartagena/2025/10/14/coointracar-lanza-nueva-ruta-de-buses-en-cartagena-asi-quedaran-los-recorridos/));
  - ruta 37B en trámite.
- **El DATT anunció en 2025 una reestructuración** para «definir claramente el recorrido y los paraderos» ([El Universal](https://www.eluniversal.com.co/cartagena/2025/01/20/habra-cambios-en-las-rutas-de-busetas-esto-es-lo-que-se-sabe/)).
- **Tamaño:** no hay una cifra oficial reciente. El Mapatón de 2019 encontró 28 rutas de buses convencionales ([Cartagena Cómo Vamos](https://cartagenacomovamos.org/mapaton-cartagena-2019/)). Las empresas conocidas son siete: Coointracar, Cootransurb, Metrocar, Pemape, Transportes Rodríguez Torices, Renaciente y Vehitrans.
- **Tarifas 2026:** bus y buseta $4.000, microbús $3.900 y Transcaribe $3.900 ([El Universal](https://www.eluniversal.com.co/cartagena/2026/01/22/suben-pasajes-de-transcaribe-y-busetas-asi-reaccionan-los-cartageneros/); Decreto 16 de 2026).
- **Paran donde se les pide:** «¡Parada!». No hay horarios, solo frecuencias.

### Qué datos existen

| Fuente | Qué trae | Problema |
|---|---|---|
| Decretos del DATT | El recorrido de cada ruta, en texto | Sin geometría; cambian varias veces al año |
| datos.gov.co | Nada del TPC. Solo «Paraderos Transcaribe» (CC BY-SA 4.0, diciembre de 2025) | — |
| GTFS del [Mapatón 2019](https://datahub.uniandes.edu.co/dataset.xhtml?persistentId=doi:10.57924/TOHB9A) (Uniandes) y [ColombiaGTFS](https://github.com/ColombiaInfo/ColombiaGTFS) | 28 rutas convencionales, 30 de colectivos y 7 de lanchas | De 2019; licencia y procedencia sin verificar. **Sirven solo para planear el mapeo, no para importarlos** |
| OpenStreetMap (consulta propia a Overpass) | 26 rutas de bus en Cartagena, 24 de Transcaribe | Del TPC solo hay 2 rutas |
| Mobility Database, Transitland | Ningún GTFS de Cartagena | — |

### Cómo conseguirlos

1. **Petición al DATT.** Pide:
   - el acto vigente de cada ruta (recorrido, frecuencia, horario y empresa);
   - las empresas habilitadas;
   - los paraderos de la reestructuración;
   - cualquier archivo KMZ, SHP o GeoJSON;
   - las condiciones para reutilizar los datos, idealmente con una licencia abierta.

   Puede que la de la Alcaldía termine remitida allí.
2. **Peticiones a las empresas.** Como prestan un servicio público, la Ley 1712 también las obliga (art. 5 c).
3. **Mapeo comunitario** con «Mapear desde el bus», que ya existe para Transcaribe:
   - se graba la ida y la vuelta de cada ruta;
   - los puntos donde más se sube la gente quedan como **«parada habitual (comunidad)»**, separados de los paraderos oficiales.
4. **Aporte a OpenStreetMap** de las rutas mapeadas, cuidando la licencia (sección 6).

**Esfuerzo:**
- La petición toma 1 día de redacción y de 10 a 30 días de espera.
- El mapeo de unas 25 a 30 rutas, con 2 o 3 viajes por ruta, son 60 a 90 viajes. Con 5 voluntarios, de 3 a 5 semanas.
- Validar contra los decretos, 1 a 2 semanas.

### Qué cambia en Karta

- **Las rutas tienen modo y operador:** Transcaribe, buseta o lancha, y la empresa.
- **Paradas flexibles:** el bus recoge en cualquier punto del recorrido. En GTFS es `continuous_pickup` ([referencia](https://gtfs.org/documentation/schedule/reference/)).
- **Frecuencias en vez de horarios.**
- **Tarifa por modo,** para mostrar el costo total del viaje.
- **Cada recorrido dice de dónde salió y qué tan confiable es:** decreto, comunidad o OpenStreetMap, y la fecha.
- **El planificador:** transbordos entre buseta y Transcaribe, que no están integrados y se pagan dos veces.
- **«¡Grita parada!» (D11)** ya existe para los paraderos de Transcaribe y se extiende a las busetas.
- **Tiempo real:** los viajes compartidos y los avistamientos funcionan igual. Con más modos, más gente aporta.
- **«Ruta desactualizada»** (D21) se vuelve más importante, porque los decretos cambian las rutas.

## 2. Corredores Turbaco y Arjona

- **No es transporte urbano.** No existe un área metropolitana legal ([El Universal](https://blogs.eluniversal.com.co/vida-diaria/y-el-area-metropolitana-de-cartagena-existe-o-no-existe)), así que Cartagena–Turbaco y Cartagena–Arjona son rutas intermunicipales, a cargo del Ministerio de Transporte ([Ley 336, art. 58](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=346)).
- **Volumen** ([Supertransporte en datos.gov.co](https://www.datos.gov.co/d/eh75-8ah6), CC BY-SA 4.0), entre el 1 de enero de 2025 y el 6 de abril de 2026:

  | Destino | Despachos | Pasajeros |
  |---|---|---|
  | Arjona | 79.251 | 634.863 |
  | Barranquilla | 47.033 | 520.264 |
  | Turbaco | 37.102 | 109.677 |

- **Tarifas propuestas para 2026:** Turbaco $4.000 y Arjona $5.500 ([Cartagena al Día](https://cartagenaaldia.com/index.php/2026/01/17/contundente-ajuste-tarifario-del-transporte-intermunicipal-en-bolivar-2026/)). Estaban pendientes del aval del Ministerio.
- **Cómo:**
  - peticiones al Ministerio de Transporte y a la Terminal de Transportes;
  - frecuencia por hora estimada con los datos de Supertransporte;
  - mapeo del tramo urbano de cada corredor.
- **La larga distancia** (Barranquilla, Bogotá) se muestra solo como «sale de la Terminal», sin vender pasajes. Encaja mejor en el plan para turistas.

## 3. Lanchas de residentes

- **Están reguladas:** el servicio público marítimo de pasajeros se habilita ante DIMAR ([Decreto 804 de 2001](https://www.dimar.mil.co/sites/default/files/normatividad/dec804.pdf)). La Bodeguita es el muelle autorizado hacia las islas ([DIMAR](https://www.dimar.mil.co/muelle-la-bodeguita-lugar-autorizado-para-el-transporte-publico-de-pasajeros-hacia-las-islas-del)).
- **Las de residentes son mayormente informales:** salen cuando se llenan, desde muelles precarios y sin integración ([Revista Metro, febrero de 2026](https://revistametro.co/2026/02/el-transporte-acuatico-de-pasajeros-en-cartagena/)). En 2019 había 7 rutas, con tarifas de $5.000 a Tierrabomba hasta $40.000 a Barú.
- **Transcaribe Acuático:** lanchas eléctricas de unas 50 plazas, con estaciones en Bocagrande, La Bodeguita, Bazurto y Pasacaballos. El piloto se anunció para diciembre de 2025, luego para noviembre de 2026 y luego para diciembre de 2026. Siguen pendientes los permisos, la licencia ambiental y el modelo financiero ([Infobae, septiembre de 2026](https://www.infobae.com/colombia/2026/09/10/cartagena-tendra-sistema-de-transporte-publico-por-el-mar-asi-seran-las-rutas-y-caracteristicas-de-los-acuabuses/)).
- **Cómo:**
  - peticiones a la Capitanía de Puerto (DIMAR) y a Corpoturismo;
  - mapeo comunitario de los muelles de Bocachica, Caño del Oro y Tierrabomba;
  - en la app, «sale cuando se llena», con una tarifa de referencia reportada por la comunidad y su fecha.

## 4. Tarifas oficiales de taxi (opcional)

- **Son servicio público individual, legal.** Cartagena no usa taxímetro: cobra por zonas. La carrera mínima de 2026 es $12.250, con recargo nocturno de $1.100 ([Decreto 0051 de 2026](https://www.eluniversal.com.co/cartagena/2026/02/27/suben-las-tarifas-de-taxis-en-cartagena-asi-quedo-la-carrera-minima-para-2026/)).
- **A favor:** mostrar la tarifa oficial protege contra los cobros de más y sirve cuando Transcaribe ya cerró.
- **En contra:** abre la puerta a pedir reservas o comisiones, que Karta excluye. Además, las zonas vienen como listas de barrios.
- **Si se hace, solo informativo:** la tarifa oficial por zona y los recargos, citando el decreto. Sin reservas, sin teléfonos de empresas y sin enlaces. **Lo decide Camilo.**

## 5. Lo que no se recomienda

- **Mototaxis.** El Ministerio de Transporte conceptuó en 2024 que no son un servicio público regulado ([concepto](https://mintransporte.gov.co/info/mintransporte/media/anexos/Wf70kD3p.pdf)). En Cartagena las motos concentran el 81 % de las muertes viales.
- **Colectivos en carro particular, jeep o taxi.** Son ilegales; el Mapatón de 2019 contó 30 rutas.
- **Lo que sí se puede:** recoger reportes anónimos y agregados de «aquí no hay transporte formal», como evidencia de los vacíos de la ciudad. Es un dato valioso para el [plan de datos](plan-datos-y-monetizacion.md).

## 6. Licencias de los datos

- **OpenStreetMap (ODbL)** pide atribución. Si Karta mezcla datos de OSM con datos propios del mismo tipo, la base resultante también queda bajo ODbL. Mantener capas separadas por tipo evita que eso alcance a los datos propios ([guía de la OSMF](https://osmfoundation.org/wiki/Licence/Community_Guidelines/Collective_Database_Guideline_Guideline)).
- **datos.gov.co** suele usar CC BY-SA 4.0, que también obliga a compartir igual.
- **Cada registro guarda su procedencia y su licencia.**
- **Karta necesita publicar una licencia para sus propios datos**, aparte de la del código (AGPL y Apache).

## 7. Peticiones que harían falta

Todas se apoyan en tres normas:
- la Ley 105 de 1993, art. 3.1 b: los usuarios tienen derecho a estar informados sobre los modos de transporte ([Ley 105](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=296));
- la Ley 1712 de 2014: la información de quienes prestan servicios públicos se presume pública ([Ley 1712](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=56882));
- la Ley 1755 de 2015: 10 días para documentos y 15 para peticiones generales ([Ley 1755](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=65334)).

| A quién | Qué |
|---|---|
| DATT | Rutas del TPC, empresas, paraderos, archivos geográficos, condiciones de uso |
| Empresas de TPC | Recorridos, frecuencias y horarios de sus rutas |
| Ministerio de Transporte y Terminal de Transportes | Rutas intermunicipales, empresas, frecuencias y puntos de salida |
| Capitanía de Puerto (DIMAR) y Corpoturismo | Empresas habilitadas, rutas y muelles autorizados, zarpes y tasas |

Se redactan con el mismo cuidado que la [petición a Transcaribe](legal/derecho-de-peticion-transcaribe.md), cuando Camilo lo decida. Antes de contar con el silencio positivo, hay que confirmar si los plazos son días hábiles.

## 8. Orden

1. **Transcaribe al día:** espera la respuesta de Transcaribe.
2. **Diseño del modelo de datos multimodal:** modo, operador, paradas flexibles, frecuencias, tarifa y procedencia. No depende de nadie y se puede planear con detalle.
3. **Petición al DATT y mapeo de las busetas**, que necesita voluntarios y por eso empieza cuando Karta esté publicada.
4. **Turbaco y Arjona.**
5. **Lanchas de residentes**, y Transcaribe Acuático cuando haya piloto.
6. **Taxis y ciclorrutas**, si Camilo decide hacerlos.
7. **El plan para turistas**, después.

## Lo que no se pudo verificar

- El número actual de rutas, vehículos y empresas del TPC.
- La licencia del GTFS del Mapatón y el contenido del archivo de ColombiaGTFS.
- Si Transcaribe tiene un GTFS interno.
- Si el DATT tiene archivos geográficos de rutas.
- Las tarifas y horarios oficiales de las lanchas.
- Si la Ciénaga de la Virgen y los caños son de DIMAR o del Ministerio de Transporte.
- Si Google Maps muestra busetas o lanchas en Cartagena.

Las fuentes se consultaron el 26 de octubre de 2026. La consulta a Overpass se hizo ese mismo día.
