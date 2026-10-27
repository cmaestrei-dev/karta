# Plan: qué datos guardar, qué vender y cómo

**Estado:** investigación y plan del 26 de octubre de 2026. Es **solo un plan**: nada de lo que propone está hecho.

**Relación con otros documentos:**
- Profundiza el [plan de sostenibilidad](plan-sostenibilidad.md), §3.1, que pone la analítica agregada como la fuente principal de ingresos.
- Las reglas de hoy están en la [política 1.1](../backend/data/legal/politica-de-tratamiento.md) y en el [manual de datos](legal/manual-de-datos-personales.md).

**Qué preguntó Camilo:**
1. Cuánta información útil, valiosa y vendible se puede guardar.
2. Si conviene guardar más.
3. Si es mejor vender analítica o datos en crudo.
4. Qué se gana y qué se pierde guardando más.

## Respuestas cortas

1. **Qué se vende.** Las entidades de transporte pagan sobre todo por cinco cosas:
   - confiabilidad (espera y tiempo de recorrido reales);
   - ocupación por franja;
   - velocidad por tramo;
   - matrices origen-destino (OD);
   - puntos críticos de incidentes.

   Karta ya mide casi todo eso o puede medirlo **sin guardar recorridos**: basta con agregar cada dato apenas llega.
2. **Sí, guardar más, pero agregado, no en crudo.** Valen la pena:
   - la velocidad por tramo;
   - la OD por paradero;
   - la demanda de búsquedas por zona;
   - más ocupación y puntos críticos.

   Todo se agrega al recibirlo. Guardar trazas completas cuesta poco dinero, pero mucho en riesgo legal y en confianza.
3. **Analítica.** Un dato seudonimizado, con una fila por viaje, **sigue siendo un dato personal**. Venderlo es una transferencia: exige una autorización nueva de cada viajero, contradice la política 1.1 y el comprador público no puede guardar exclusividad. Además, el mercado no paga esas filas: paga el servicio.
4. **Ganancias y pérdidas:** están en la sección 5. En corto: más datos crudos dan mejores modelos, pero multiplican el daño de una filtración y las obligaciones legales, y gastan la confianza que hace funcionar el tiempo real comunitario.

**Hay que corregir algo antes de entregar la primera tabla** (sección 6): el mínimo de 10 por cifra cuenta viajes, no personas.

## 1. Qué vale y para quién

### Lo que muestra el mercado

| Actor | Qué ofrece | Cómo cobra |
|---|---|---|
| [Waze for Cities](https://web-assets.waze.com/partners/ccp/Waze-for-Cities-v01.pdf), [Google EIE](https://sustainability.google/stories/environmental-insights-explorer/), [Strava Metro](https://www.endurancesportswire.com/strava-metro-now-free-for-urban-planners-and-advocates/) | Agregados de tráfico, emisiones, bicicletas y peatones | **Gratis** para gobiernos (Strava, desde 2020). Ganan con su negocio principal y con legitimidad |
| Transit (app) | Ocupación reportada por viajeros, tablero de demanda | La agencia paga la suscripción de sus viajeros: unos CAD 75.000 al año en Edmonton ([CBC, 2023](https://www.cbc.ca/news/canada/edmonton/third-party-transit-planning-app-no-longer-free-for-edmonton-riders-1.6792206)) |
| Moovit | App de marca blanca; [analítica de movilidad](https://moovit.com/maas-solutions/urban-mobility-analytics/) (OD, subidas y bajadas, ocupación) con datos agregados | Contratos. LA Metro: USD 4,35 millones por 4 años por la app ([acta, 2026](https://datamade-metro-pdf-merger.s3.amazonaws.com/2025-1033.pdf)). La analítica no tiene precio público |
| StreetLight | OD y actividad por zona | Suscripción: [USD 42.888 al año](https://tetoncountywy.gov/DocumentCenter/View/25060/03213-Streetlight-data-for-Location-Based-Services-Data-Subscription) en un condado pequeño, [USD 275.000–363.000](https://ccag.ca.gov/wp-content/uploads/2024/02/6-A1-3rd-Amended-and-Restated-Streetlight-MOU_2023-8-18-executed.pdf) en uno grande |
| Swiftly | Puntualidad y predicciones con el GPS de la flota | Software por módulo: [hasta USD 246.563 al año](https://countyconnection.com/wp-content/uploads/2025/07/8.c.1.-Swiftly-Modules.pdf) |
| Teralytics | OD con datos de telefonía | Licencias; [en quiebra desde enero de 2026](https://www.moneyhouse.ch/en/company/teralytics-ag-3393361721) |

**Lecciones:**
1. **Los agregados genéricos tienden a valer cero:** los gigantes los regalan.
2. **Se paga por servicio y software recurrente**, o por cubrir una región entera. A quien vende solo datos le va mal: Teralytics quebró y [Citymapper se vendió en 2023](https://www.uktech.news/mobility/via-citymapper-20230317).
3. **Lo que más se compra:** OD y actividad por zona, subidas y bajadas con ocupación, puntualidad y tiempos de recorrido.

### Cartagena

- **Transcaribe no tiene plata, pero sí el problema que Karta mide.**
  - Tiene un hueco proyectado de unos $63.000 millones ([El Tiempo, noviembre de 2025](https://www.eltiempo.com/amp/colombia/otras-ciudades/el-sistema-de-transporte-integrado-de-cartagena-transcaribe-podria-colapsar-en-2026-por-un-hueco-fiscal-de-63-000-millones-3512058)).
  - Las quejas principales de los usuarios son los retrasos (51 %) y el sobrecupo (45 %) ([Cartagena Cómo Vamos, vía El Universal, mayo de 2026](https://www.eluniversal.com.co/cartagena/2026/05/04/aumentar-la-demanda-uno-de-los-grandes-retos-de-transcaribe-en-cartagena/)).
- **Lo que solo Karta tiene** es la experiencia del viajero: la espera real en el paradero, la ocupación percibida, los incidentes y, si se decide, la OD. Los buses nuevos traen GPS, así que la posición del bus le valdrá menos a Transcaribe.
- **Su matriz OD de hoy** sale de consultorías con encuestas cada varios años ([TC-CPN-001-19](https://www.transcaribe.gov.co/documentos/Licitaciones%202019/TC-CPN-001-19/ANEXO%20No.%201.%20ANEXO%20TECNICO.pdf)). Una OD continua y barata es justo lo que Karta podría ofrecer.
- **Otros compradores posibles:**
  - DATT y Alcaldía: tiempos de recorrido y trancones;
  - Cartagena Cómo Vamos: satisfacción y confiabilidad;
  - universidades: investigación;
  - más adelante, comercio y turismo, siempre agregado.
- **Ingresos esperables (estimación sin verificar):**
  - el primer año, $0 en dinero: un piloto gratis a cambio de las coordenadas oficiales de los paraderos;
  - si funciona, un convenio del orden de decenas de millones de pesos al año.

  Se puede contrastar con el Plan Anual de Adquisiciones de Transcaribe en SECOP II.

## 2. Lo que dice la ley

- **Qué es un dato personal.** Cualquier información asociada o que pueda asociarse a una persona ([Ley 1581, art. 3 c](http://www.secretariasenado.gov.co/senado/basedoc/ley_1581_2012.html)). La SIC trata la ubicación como dato personal: en 2022 [investigó a Avianca](https://sedeelectronica.sic.gov.co/noticias/superindustria-abre-investigacion-avianca-por-presunta-violacion-al-regimen-de-datos-personales) por perfilar con la ubicación sin autorización.
- **La ubicación puede ser sensible.** La lista del art. 5 es abierta. Un historial que revele visitas a un hospital, una iglesia o una sede sindical debe tratarse como dato sensible: autorización explícita y opcional, sin condicionar el servicio (art. 6).
- **Anonimizado no es dato personal, si es irreversible.** Según la doctrina de la SIC reseñada por [Ámbito Jurídico](https://www.ambitojuridico.com/noticias/mercantil/informacion-anonimizada-que-permita-su-vinculacion-o-asociacion-una-persona), lo seudonimizado sigue siendo personal. El PLE 282 de 2026 propone escribirlo en la ley.
- **Transferencia y transmisión** ([Decreto 1074, art. 2.2.2.25.1.3](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=76608)):
  - **Transferencia:** vender datos personales a quien los usará para sus fines. El comprador pasa a ser responsable, y la circulación debe estar autorizada (art. 4 f).
  - **Transmisión:** encargar a alguien que trate los datos por cuenta de Karta. Necesita un contrato (art. 2.2.2.25.5.2).
- **Finalidad, necesidad y tiempo.** Cada dato necesita una finalidad informada antes de recogerlo (art. 2.2.2.25.2.2). Solo se guarda lo necesario y por el tiempo necesario (arts. 2.2.2.25.2.1 y 2.2.2.25.2.8). **«Guardarlo por si sirve después» no es una finalidad válida.**
- **Sanciones.** Hasta 2.000 salarios mínimos (unos $3.500 millones en 2026), suspensión y, con datos sensibles, cierre (art. 23). Casos recientes:
  - [Risks International, 2025](https://sedeelectronica.sic.gov.co/comunicado/la-superintendencia-de-industria-y-comercio-confirmo-sancion-risks-international-sas-por-infraccion-al-regimen-de-proteccion-de-datos): $190 millones y suspensión por dar a sus clientes acceso a una base con datos sensibles;
  - [Movistar, 2025](https://www.portafolio.co/negocios/empresas/sic-sanciona-a-movistar-con-670-millones-por-uso-indebido-de-datos-personales-643230): $670 millones por usar datos para una finalidad no autorizada;
  - [World y Tools for Humanity, 2025](https://sedeelectronica.sic.gov.co/comunicado/la-sic-sanciona-las-sociedades-world-foundation-y-tools-humanity-corporation-con-el-cierre-inmediato-y-definitivo-de-su-operacion-de): cierre definitivo por datos biométricos.
- **Lo que viene.** El [PLE 282 de 2026 Cámara](https://congresovisible.uniandes.edu.co/proyectos-de-ley/ppor-la-cual-se-modifica-parcialmente-la-ley-1581-de-2012-y-se-dictan-otras-disposiciones-relativas-al-derecho-fundamental-a-la-proteccion-de-datos-personales-fortalecimiento-de-la-proteccion-de-datos-personales/15863/) se radicó el 26 de agosto de 2026 y no tiene ponencia. Propone:
  - delegado de protección de datos;
  - evaluaciones de impacto;
  - privacidad desde el diseño;
  - reporte de incidentes en **72 horas**.

  No regiría antes de 2027, pero conviene diseñar pensando en él.
- **Venderle a una entidad pública:**
  - **Cómo se contrata.** Se puede por contratación directa de ciencia y tecnología ([Ley 1150, art. 2.4 e](http://www.secretariasenado.gov.co/senado/basedoc/ley_1150_2007.html), que incluye estudios y estadísticas), por un contrato interadministrativo con la Universidad de Cartagena o por mínima cuantía.
  - **Ojo:** lo que la entidad adquiere es información pública ([Ley 1712, art. 6 b](http://www.secretariasenado.gov.co/senado/basedoc/ley_1712_2014.html)) y puede terminar publicado. Por eso **se cobra por el servicio continuo, no por el archivo.**
- **Persona natural o S.A.S.** Una persona natural puede contratar con el Estado. Una S.A.S. de un solo accionista limita la responsabilidad al aporte ([Ley 1258](http://www.secretariasenado.gov.co/senado/basedoc/ley_1258_2008.html)) y facilita los convenios. Una S.A.S. pequeña no tendría que inscribirse en el RNBD: solo deben hacerlo las sociedades con activos de más de 100.000 UVT, unos $5.237 millones en 2026.

## 3. ¿Crudos o agregados?

**Por qué los crudos son peligrosos aunque no lleven nombre:**
- Cuatro puntos de lugar y hora identifican al 95 % de las personas ([de Montjoye et al., 2013](https://www.nature.com/articles/srep01376)), y el tamaño de la base no protege ([Farzanehfar et al., 2021](https://www.cell.com/patterns/fulltext/S2666-3899(21)00014-3)).
- El paradero donde alguien sube cada mañana delata su casa.
- **Los agregados también filtran si los grupos son pequeños:**
  - se reconstruyeron trayectorias a partir de agregados con 73–91 % de acierto ([Xu et al., 2017](https://arxiv.org/abs/1702.06270));
  - el mapa de calor de Strava reveló bases militares en zonas con pocos usuarios ([2018](https://techcrunch.com/2018/01/28/strava-exposes-military-bases/)).

**Qué hace seguro un agregado:**
- un **mínimo de personas distintas** por celda, suprimiendo las que no lo alcanzan;
- franjas de 15 minutos o más, y tramos, estaciones o zonas en vez de puntos;
- una **cuadrícula fija**, sin consultas a la medida, para que nadie reste dos tablas que difieren en una persona;
- **ruido de privacidad diferencial** en lo que se publica: Google lo usó en sus informes de movilidad, con un mínimo de 100 usuarios ([Aktay et al., 2020](https://arxiv.org/abs/2004.04145));
- un contrato que prohíba reidentificar a alguien.

**Comparación de los tres modelos:**

| | A. Analítica agregada | B. Vender datos crudos o seudonimizados | C. Panel voluntario de investigación |
|---|---|---|---|
| Qué se entrega | No es dato personal, si el mínimo cuenta personas | Datos personales: una transferencia | Datos personales, con autorización específica |
| Autorización | Ya cubierta por la política 1.1 | Una nueva y expresa de cada viajero, que nombre a los compradores. La política 1.1 lo prohíbe | Separada, revocable y temporal |
| Riesgo legal | Bajo | Alto | Medio y controlado |
| Ingresos | Bajos a medios, recurrentes, ligados al servicio | Bajos en la práctica: mercado local pequeño y sin exclusividad | Bajos; se financia con convocatorias |
| Costo | Bajo: tablas pequeñas | Alto: almacenamiento, seguridad, contratos, atención a titulares | Medio: protocolo y comité de ética |
| Confianza | Refuerza lo que diferencia a Karta de Moovit | La destruye: [Muslim Pro](https://www.aljazeera.com/news/2020/11/18/muslim-pro-app-denies-selling-user-data-to-us-military), [Avast/Jumpshot](https://www.ftc.gov/news-events/news/press-releases/2024/02/ftc-order-will-ban-avast-selling-browsing-data-advertising-purposes-require-it-pay-165-million-over) | Neutra o positiva, si es voluntario y transparente |

**Algunos compradores sí piden crudos.** Por ejemplo, Portland le pidió a Replica sus datos desagregados; Replica se negó y el proyecto se cayó ([GovTech, 2021](https://www.govtech.com/fs/Portland-Replica-Part-Ways-Over-Data-Privacy-Concerns.html)). A esos compradores Karta les ofrece transparencia en vez de filas:
- el código abierto;
- métricas de validación;
- auditorías dentro del entorno de Karta, con acuerdo de confidencialidad y sin que los datos salgan.

## 4. Qué datos añadir y en qué forma

| Dato | A quién le sirve | Riesgo | Requisito | Forma recomendada |
|---|---|---|---|---|
| Velocidad por tramo ([plan de tráfico](plan-datos-de-trafico.md), fase A) | DATT, Transcaribe | Muy bajo | Cubierto por la política 1.1 | **Agregar al recibir**; las posiciones siguen venciendo a los 5 min |
| Espera real y ocupación | Transcaribe, Cómo Vamos: son las dos quejas principales | Bajo | Cubierto (`trip_results`, avistamientos) | Agregar por ruta, tramo y 15 min antes de que venzan |
| Puntos críticos de incidentes (robo, acoso, inundación) | DATT, Policía, Alcaldía | Bajo si se agrega | Cubierto | Conteos por zona, tipo y franja, por cuentas distintas, antes de que venzan |
| Aglomeración en estaciones (reporte nuevo) | Operación, eventos | Bajo | Declararla en la política | Agregar al recibir |
| **OD por paradero** (dónde sube y dónde baja) | Transcaribe: rediseño de rutas. Es el producto más vendido | Medio: pares raros a horas raras | **Política 1.2 y autorización nueva**: hoy la política dice «sin paraderos» | Agregar al recibir: pares × franja × tipo de día, con mínimo de personas |
| **Demanda de búsquedas por zona** (de dónde a dónde se busca) | Demanda no atendida, turismo | Alto con puntos, medio por zona | **Política 1.2**: hoy dice que no se guardan | Agregar al recibir por barrio o celda grande × hora; nunca una fila por búsqueda |
| Telemetría de la app (fallas, tiempos) | Solo interna | Bajo a medio | Declararla en la política | Contadores agregados, sin SDK de terceros, de 7 a 30 días |
| Encuestas cortas en la app | Cómo Vamos, Transcaribe | Alto si se cruzan con los viajes | Autorización separada | Sin vínculo con la cuenta ni con los viajes; categorías gruesas |
| Trazas completas de los tramos en bus | Modelos de llegada, buses en racimo | **Alto**: el punto de subida es casi la casa | Política nueva y autorización nueva | **No.** Como mucho, 7 días sin el primer ni el último paradero, solo para recalcular |
| Historial de viajes del usuario (Karta Plus) | El propio usuario; no se vende | Alto en el servidor | Contradice «no guardamos historial» | **Solo en el teléfono**, o cifrado de extremo a extremo |
| Panel voluntario de investigación | Academia, modelos de demanda | Alto | Autorización separada que nombre a la universidad; comité de ética; mayores de 18 | Después del piloto, con la universidad, por 4 a 8 semanas, en una base aparte; solo salen agregados |

Un panel pagado choca con la regla de premios solo visuales. Es una decisión de Camilo; una salida es que la compensación la pague una convocatoria y la entregue la universidad.

## 5. Guardar más: lo que se gana y lo que se pierde

**Lo que se gana:**
- llegadas estimadas con referencias por tramo, hora y temporada (turística y de lluvias);
- modelos de predicción;
- productos más ricos;
- evidencia para las peticiones y los convenios.

Casi todo eso se logra con agregados, que crecen con el catálogo (rutas × tramos × franjas) y no con el número de viajes.

**Lo que se pierde o se arriesga:**
- **Dinero, poco.** Trazas completas de 2.000 personas que comparten serían unos 15 GB al año (estimación): obligarían a un Atlas M10 (unos USD 57 al mes) o a mover lo viejo a S3. Los agregados se quedan en decenas de MB.
- **Riesgo de filtración, mucho.** Gravy Analytics filtró datos de ubicación en 2025 a partir de [una llave de AWS robada](https://therecord.media/location-data-broker-gravy-breach), que es el primer escenario del manual de Karta. Cuanto más se guarda, peor el incidente: reporte a la SIC en 15 días hábiles hoy, y en 72 horas si se aprueba el PLE 282.
- **Obligaciones.** Cada dato nuevo necesita finalidad, plazo y justificación. Con el PLE 282 también necesitaría una evaluación de impacto.
- **Confianza.** Hay órdenes de la FTC contra quienes vendían ubicaciones:
  - [InMarket](https://www.ftc.gov/news-events/news/press-releases/2024/01/ftc-order-will-ban-inmarket-selling-precise-consumer-location-data) y [X-Mode](https://www.ftc.gov/news-events/news/press-releases/2024/01/ftc-order-prohibits-data-broker-x-mode-social-outlogic-selling-sensitive-location-data) (2024);
  - [Mobilewalla y Gravy](https://www.ftc.gov/news-events/news/press-releases/2024/12/ftc-takes-action-against-mobilewalla-collecting-selling-sensitive-location-data) (2024);
  - [Kochava](https://www.gtlaw-dataprivacydish.com/2026/05/ftc-bars-kochava-from-selling-sensitive-location-data/) (2026).

  «Sin anuncios y sin historial» solo distingue a Karta de Moovit si de verdad no se guarda el historial.

## 6. Correcciones antes de entregar cualquier tabla

1. **El mínimo de 10 cuenta viajes, no personas.** Afecta a `precision.py`, a `indicadores.py` y al manual.
   - **Ejemplo:** alguien que toma el T103 a la misma hora cada día hábil llena en dos semanas una celda «T103, 6:30–6:45, día hábil» con 10 viajes suyos. Con una OD por paradero, esa celda revelaría su casa y su trabajo.
   - **Cómo arreglarlo sin guardar identificadores:** contar personas distintas por celda con un resumen de cardinalidad (HyperLogLog) sobre una huella con clave que se descarta al cerrar la ventana. Otra opción es exigir a la vez 10 viajes, en al menos 5 días distintos y de al menos 3 personas.
2. **`boardings` guarda la hora exacta junto al punto durante 180 días.** Redondearla al cuarto de hora al recibirla le quita poder de enlace sin perder el paradero.
3. **Celdas fijas y publicadas,** sin consultas a la medida.

## 7. Recomendación

1. **Nunca vender datos crudos ni seudonimizados.** En Colombia siguen siendo datos personales. Venderlos exigiría que todos volvieran a autorizar, el comprador público no guarda exclusividad, y el mercado premia el servicio, no las filas.
2. **Hacer las correcciones de la sección 6** antes de la primera tabla.
3. **Guardar más, pero agregado al recibir:** velocidad por tramo, ocupación, espera real y puntos críticos ya caben en la política 1.1.
   - **La OD por paradero y la demanda por zona** son las de más valor, pero exigen una **política 1.2** con autorización nueva **antes** de recogerlas.
   - **Los datos crudos nuevos** se guardan como máximo 7 días y solo para control de calidad.
4. **Vender servicio, no archivos:**
   1. **Primero,** un piloto gratis con Transcaribe a cambio de las coordenadas oficiales de los paraderos. Encaja con la [petición](legal/derecho-de-peticion-transcaribe.md).
   2. **Después,** un boletín mensual de confiabilidad y ocupación, más un tablero, por un convenio con la Universidad de Cartagena o por contratación directa de ciencia y tecnología.
   3. **Siempre,** una versión gratis con ruido para la ciudadanía y para Cómo Vamos.
5. **Antes de facturar:**
   - crear una S.A.S.;
   - firmar con cada receptor la prohibición de reidentificar;
   - antes de cada producto, hacer la prueba de riesgo de la [Guía de Anonimización del AGN](https://www.archivogeneral.gov.co/sites/default/files/Estructura_Web/5_Consulte/Recursos/Publicacionees/Guia_de_Anonimizacion-min.pdf);
   - diseñar desde ya para el PLE 282.
6. **El panel de investigación, después del piloto,** con la universidad y su comité de ética.

**Por qué:** lo que diferencia a Karta es la experiencia del viajero (espera, ocupación, incidentes), y eso se vende bien agregado. Guardar más cuesta sobre todo riesgo y confianza, y la confianza es lo que hace funcionar el tiempo real comunitario.

## 8. Lo que no se pudo verificar

- El texto completo del PLE 282 (solo sus definiciones y reseñas).
- El número y la fecha del concepto de la SIC sobre anonimización (la reseña es de pago).
- La versión final de la reforma del Título V de la SIC de mayo de 2026.
- Los precios de Replica y de la analítica de Moovit, y el valor de la consultoría OD de Transcaribe de 2019.
- El resultado de la investigación de la SIC contra Avianca.
- Las cifras de almacenamiento y de ingresos, que son estimaciones.

Las fuentes legales y de mercado se consultaron el 26 de octubre de 2026.
