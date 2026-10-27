# Plan de calidad: escalabilidad, disponibilidad, latencia, seguridad y consistencia

**Estado:** auditoría y plan del 26 de octubre de 2026. El P0 se hizo el mismo día (sección 8); lo demás sigue siendo plan.

**Alcance:** la versión de la rama `claude/fase-4`, desplegada en AWS Lambda con MongoDB Atlas M0 ([despliegue](despliegue-aws.md)).

**Cómo se auditó:**
- **El código:** lectura con referencias a archivos.
- **Producción:** 10 peticiones GET, sin carga.
- **AWS:** solo consultas permitidas: cuotas, concurrencia y métricas de CloudWatch de los últimos 7 días.
- **Local:** medición pasando por el manejador de Lambda contra MongoDB en Docker, contando los comandos a la base, y `explain()` de las consultas clave.
- **Dependencias:** la base pública OSV de vulnerabilidades.
- **Lo que no se pudo verificar:** la configuración de Atlas (copias y rol del usuario), si existen alarmas o presupuestos en AWS, y el arranque en frío real en los registros.

## Resumen

**Para el piloto de 15 personas el sistema sobra.** Los límites aparecen así:

| Viajeros a la vez | Peticiones/s | Operaciones/s en la base | Qué se rompe primero |
|---|---|---|---|
| 15 | 0,6 | 2,5 | Nada |
| 1.000 | ~42 | ~170 | **Atlas M0:** admite 100 operaciones/s y 10 GB de salida por semana; con la lista de reportes completa, esos 10 GB se acaban en unas 4 horas pico |
| 10.000 | ~420 | ~1.700 | **Lambda:** esta cuenta permite 10 ejecuciones simultáneas, unas 100 peticiones/s |

Estimación con estos supuestos:
- la mitad espera el bus y consulta 1,5 rutas cada 30 s;
- la otra mitad va a bordo, y de ella la mitad comparte la posición;
- todos refrescan los reportes cada 2 minutos.

**Lo más urgente no es el tamaño, sino cuatro riesgos:**
1. **Denegación de servicio barata.** Planificar, buscar, la llegada y la lista de reportes no tienen límite de peticiones. Unas 100 peticiones por segundo desde un solo equipo copan las 10 ejecuciones de la cuenta, y todos los usuarios empiezan a recibir rechazos.
2. **Cuentas falsas.** Se pueden crear 60 cuentas invisibles por hora por IP. Con ellas se infla la reputación, se publican avistamientos falsos y se ubican paraderos falsos que quedan para siempre.
3. **Votos sin transacción.** Un voto son varias escrituras. Si falla a la mitad, queda guardado sin aplicarse y no se puede repetir.
4. **Sin alarmas ni marcha atrás.** No hay alarmas ni registros propios, y cada despliegue reemplaza la función sin versión a la cual volver.

## 1. Escalabilidad

**Estado:**
- **Lambda:** la cuenta permite 10 ejecuciones simultáneas (lo verificó `get-account-settings`). En 7 días hubo 335 invocaciones, un máximo de 4 a la vez y ningún rechazo.
- **Atlas M0:** tiene un límite de 0,5 GB, 500 conexiones, 100 operaciones por segundo (al pasarse, frena con esperas de 1 s) y 10 GB de entrada y 10 de salida cada 7 días ([límites de Atlas Free](https://www.mongodb.com/docs/atlas/reference/free-shared-limitations/)).
- **Datos de referencia leídos en cada petición:** las rutas, las estaciones y los horarios casi no cambian, pero se vuelven a leer de Atlas en cada consulta.
  - Planificar lee todos los horarios, las estaciones y las troncales con su trazado, y recalcula una huella de los datos (`trip_service.py`).
  - Cada consulta de llegada lee la ruta entera (`realtime_service.py`).
- **Comandos a la base por petición** (medidos):

  | Endpoint | Comandos |
  |---|---|
  | Planificar | 10 a 20 |
  | Votar | 10 |
  | Reportar | 7 |
  | Llegada | 5, uno de ellos el contador diario agregado el 26 de octubre, que es una escritura |

- **Consultas costosas** (`explain()`):
  - Buscar los buses varados de una ruta recorre todos los reportes vigentes.
  - La lista de reportes se ordena en memoria.
  - Las subidas en estaciones traen hasta 20.000 documentos en cada plan que pasa por una estación doble.
- **CPU de la llegada:** crece en línea recta con las observaciones de la ruta: 10 ms sin ninguna, 158 ms con 300 y 538 ms con 1.000 (`tiempo_real.py`).
- **Crecimiento:** hoy el piloto ocupa unos 2 MB. Las subidas, los resultados de viaje y las respuestas de parada vencen tarde (180 a 365 días). Con 10.000 usuarios diarios llenarían los 512 MB en pocos meses; con 1.000, ocuparían unos 150 MB al año.

**Qué hacer:**

| # | Mejora | Costo | Esfuerzo |
|---|---|---|---|
| E1 | Caché en memoria de los datos de referencia, con unos 60 s de vigencia: rutas, estaciones, horarios y muestreos ya calculados. Ahorra del 50 al 80 % de los comandos y de la salida de Atlas | USD 0 | 1–2 días |
| E2 | El contador de llegadas se suma en memoria y se guarda cada pocos minutos, en vez de una escritura por consulta | USD 0 | Medio día |
| E3 | Llegada vectorizada (numpy y pyproj sobre arreglos, muestreo en caché, máximo unas 100 observaciones por ruta) | USD 0 | 1–2 días |
| E4 | Índices para los varados y la lista de reportes; la app pide solo el área visible | USD 0 | 1 día |
| E5 | Retención resumida: las subidas, los resultados y las respuestas pasan a agregados diarios y los datos crudos se guardan 30 días. Encaja con el [plan de datos](plan-datos-y-monetizacion.md) | USD 0 | 2–3 días |
| E6 | Al crecer: pedir más concurrencia a AWS (gratis) y reservar un tope que proteja a Atlas; Atlas Flex antes de 300 viajeros simultáneos; M10 para más de 500 operaciones/s o para tener SLA | Flex USD 8–30 al mes ([costos](https://www.mongodb.com/docs/atlas/billing/atlas-flex-costs/)); M10 ~USD 57 al mes ([precios](https://www.mongodb.com/pricing)) | Horas |

## 2. Disponibilidad

**Estado:**
- **Una región, una función y una base sin SLA.** El SLA de Atlas empieza en M10 ([notas de producción](https://www.mongodb.com/docs/atlas/production-notes/)).
- **Copias:** M0 permite una instantánea diaria; no se pudo verificar si está activa.
- **Arranque en frío:** al cargar, la función crea índices y revisa los datos de referencia (`lambda_handler.py`). Lambda da 10 s para esa fase. La primera carga duró 18,4 s, así que se pasó; los 5 errores del primer despliegue probablemente vienen de ahí.
- **El calentador mantiene vivo un solo entorno.** En una ráfaga, los demás arrancan en frío.
- **La app sin API:**
  - espera 15 s, no reintenta y no guarda rutas ni estaciones, así que sin servidor no se puede planificar;
  - el viaje activo sí sigue con el GPS;
  - el resultado del viaje se envía una sola vez y se pierde si falla.
- **Monitoreo:** no hay registros propios de la aplicación ni alarmas. La política de despliegue ni siquiera permite crearlas.
- **Despliegue:** se reemplaza la función en el acto, sin versiones, alias ni ambiente de prueba. La prueba de salud corre después de publicar.
- **El mapa base depende de OpenFreeMap**, que no tiene SLA y vive de donaciones.

**Qué hacer:**

| # | Mejora | Costo | Esfuerzo |
|---|---|---|---|
| D1 | Alarmas de errores, rechazos, p95 y concurrencia, con aviso por correo; presupuesto de AWS; sonda externa gratuita a `/health` cada 5 minutos | USD 0 (verificar el costo de las alarmas) | Medio día |
| D2 | Copias diarias. Las del plan gratuito de Atlas cuestan USD 0,10 al día y piden tarjeta, así que se hace una propia en S3 | Centavos al mes | Medio día |
| D3 | Cargar los datos de referencia al desplegar, no al arrancar, y dejar el arranque solo de lectura | USD 0 | Medio a 1 día |
| D4 | Despliegue reversible: publicar versiones, usar un alias «live» y probar antes de moverlo. Antes conviene poner un dominio o CloudFront delante, porque la dirección está compilada en el APK | USD 0 | 1 día |
| D5 | App resistente: guardar en el teléfono rutas, estaciones y política; reintentar los GET con espera creciente; cola de envíos con clave de idempotencia | USD 0 | 2–3 días |
| D6 | Subir el límite de 60 cuentas invisibles por hora por IP para las IP compartidas (operadores móviles, universidad), compensándolo con la defensa S2 | USD 0 | Horas |

## 3. Latencia

**Medido:**
- **Desde el portátil a producción:**
  - `/health` tarda 0,39 a 0,83 s con conexión nueva (mediana 0,49 s), y la conexión TCP y el TLS se llevan unos 0,3 s;
  - con la conexión reutilizada, 0,20 s;
  - `/routes/` pesa 74 KB y tarda 0,82 s.
- **En el servidor:** p95 de 145 ms; las peticiones normales no pasan de unos 200 ms.
- **Local:** búsqueda 12 ms, cercanas 42 ms, planificar 63 a 234 ms y llegada con 30 avistamientos 84 ms. Mangum no añade casi nada.
- **Ninguna respuesta va comprimida** y no hay `Cache-Control` ni `ETag`.
- **La causa principal está en la app:** el cliente HTTP de Dart cierra las conexiones inactivas a los 15 s ([`idleTimeout`](https://api.dart.dev/stable/dart-io/HttpClient/idleTimeout.html)). Como la app consulta cada 30 s, **cada consulta paga otra vez la conexión TCP y el TLS**, unos 0,3 a 0,45 s. Además, la sesión usa llamadas sueltas, cada una con conexión nueva.

**Qué hacer:**

| # | Mejora | Costo | Esfuerzo |
|---|---|---|---|
| L1 | Un solo cliente HTTP en la app, con conexiones abiertas unos 75 s | USD 0 | Medio día |
| L2 | gzip y `ETag` en rutas, tipos de reporte y política: `/routes/` pasaría de 74 a ~15 KB | USD 0 | Medio día |
| L3 | CloudFront con su [plan gratuito](https://aws.amazon.com/cloudfront/pricing/): TLS más cerca, caché de los datos que casi no cambian y límites en el borde con WAF. Con control de acceso al origen hay que mover el JWT a otra cabecera; lo más simple es una cabecera secreta que la API comprueba | USD 0 | 1–2 días |
| L4 | La llegada vectorizada (E3) y las cachés (E1) también bajan la latencia | — | — |

## 4. Seguridad

Revisión contra el [OWASP API Security Top 10 de 2023](https://owasp.org/API-Security/editions/2023/en/0x11-t10/):

| Riesgo de OWASP | Estado en Karta |
|---|---|
| API1, objetos de otros | **Bien.** Los lugares se filtran por dueño y no se puede votar el reporte propio. Los viajes compartidos usan un código al azar de 128 bits |
| API2, autenticación | **Medio.** El JWT dura 7 días, sin `aud`, `iss` ni forma de revocarlo; el inicio de sesión se limita por IP, no por cuenta; no se verifica el correo. Las contraseñas usan Argon2id |
| API3, propiedades expuestas | **Bien.** Respuestas con campos explícitos y documentos armados campo por campo |
| API4, consumo de recursos | **Alto.** Planificar, riesgo (hasta 5.000 puntos), llegada, búsqueda y lista de reportes no tienen límite. La IP no se puede falsificar, porque la pone AWS, pero rotar IP es fácil |
| API5, funciones de administración | **Bien.** No hay endpoints de administración |
| API6, flujos de negocio | **Alto al abrir a la ciudad.** Con cuentas invisibles se infla la reputación (+2 por confirmación; desde el nivel 3, un solo «ya no está» retira cualquier reporte), se envenena la llegada con avistamientos falsos y se ubican paraderos falsos con 3 cuentas, sin forma de disputarlos |
| API8, configuración | **Medio.** `/docs` y `openapi.json` son públicos en producción; CORS abierto; Atlas acepta cualquier IP. Los secretos están en variables de Lambda, legibles para quien tenga `lambda:Get*`, que el permiso de despliegue incluye. El APK de *release* se firma con la llave de depuración si falta la propia, sin avisar |
| API9, inventario | **Bajo.** Solo existe `$LATEST`; sigue el campo transitorio `responsable`; no se puede exigir una versión mínima de la app |
| API7 y API10, terceros | **Bajo.** El servidor no llama a terceros; las teselas las pide la app |

Lo demás:
- **Registros:** no hay ninguno de la aplicación, así que un abuso no deja rastro.
- **Dependencias:** OSV no reporta vulnerabilidades en los 44 paquetes del servidor.
- **La app:** el token va en el almacenamiento seguro, la copia de seguridad está desactivada y el tráfico sin cifrar solo se permite en depuración.

**Qué hacer:**

| # | Mejora | Esfuerzo |
|---|---|---|
| S1 | **Límites para los endpoints anónimos:** por IP y global, con un balde de fichas en memoria, sin escribir en la base. Bajar `/routes/risk` a unos 1.000 puntos. Reservar concurrencia | 1 día |
| S2 | **Defensa contra cuentas falsas:** la reputación solo cuenta con cuentas de cierta antigüedad o nivel; tope de avistamientos por ruta y cuenta; más confirmaciones (o de nivel alto) para ubicar un paradero, y poder disputarlo; coordenadas plausibles (velocidad, cercanía a la ruta); evaluar Play Integrity | 3–5 días |
| S3 | **Endurecer la configuración:** ocultar `/docs`; JWT con `aud` e `iss` y vigencia más corta; quitar `lambda:Get*` del usuario de todos los días; que el *build* falle sin la llave de firma; rotar los secretos cada 90 días | 1 día |
| S4 | **Registros estructurados sin datos personales:** códigos 4xx, 429 y 5xx por ruta, para ver abusos | Medio día |
| S5 | **El servidor exige la autorización de la política** antes de aceptar datos, o la registra al crear la cuenta invisible. Hoy, si falla el envío de la prueba por falta de señal, igual se reciben datos (Ley 1581, art. 9) | Medio día |

## 5. Consistencia

**Estado:**
- **MongoDB con los valores de fábrica:** escritura confirmada por mayoría, lectura del primario y reintento automático de escrituras. Dentro de una petición siempre se lee lo propio.
- **Escrituras de varios documentos sin transacción:**
  - **Votar:** si falla entre guardar el voto y aplicarlo, el voto queda guardado sin efecto y repetirlo da 409. Además, premiar a los votantes primero busca y luego actualiza, así que dos confirmaciones simultáneas pueden premiar dos veces.
  - **«Gracias»:** guarda el agradecimiento y suma al contador en dos pasos.
  - **Paraderos:** el voto que alcanza el umbral y la ubicación del paradero son escrituras separadas.
- **Borrado:** el borrado a los 180 días (TTL) de las cuentas invisibles no desliga sus marcas de paraderos, como sí lo hace «Borrar mi cuenta».
- **Duplicados:** ningún POST tiene clave de idempotencia. Un avistamiento repetido cuenta como otra fuente en la llegada.
- **Vencimientos:** los viajes compartidos se filtran por `expira_en > ahora − 30 min` en vez de `> ahora` (`repositories.py`, `observations`). Un viaje vencido sigue contando hasta que MongoDB lo barre, unos 60 s después.
- **Votos repetidos:** vencen a los 2 días, pero un reporte se puede renovar sin fin, así que la misma cuenta puede votar otra vez el mismo reporte.
- **`visto_en`** solo se actualiza al renovar la sesión invisible. Atrasa hasta 7 días la métrica de «vuelven» y el borrado a los 180 días.
- **Cachés por instancia:** las del planificador se validan con la huella de los datos y no quedan viejas. La de la política se renueva cuando cambia la configuración.

**Qué hacer:**

| # | Mejora | Esfuerzo |
|---|---|---|
| C1 | Votos y paraderos en transacciones (verificar que M0 las permita), o idempotentes: marcar «aplicado» en el voto y conciliar a diario | 1–2 días |
| C2 | Premios atómicos con una sola operación que busca y marca | Medio día |
| C3 | Cabecera `Idempotency-Key` en los POST, guardada 24 h | 1 día |
| C4 | Filtrar los viajes compartidos con `expira_en > ahora` | 1 hora |
| C5 | Que el voto venza con el reporte | Medio día |
| C6 | Desligar las marcas de las cuentas invisibles vencidas (tarea diaria) y actualizar `visto_en` al menos una vez al día con la actividad | Medio día |

## 6. Metas medibles

| Meta | Piloto | Ciudad |
|---|---|---|
| Disponibilidad mensual (sonda a `/health` cada 5 min) | 99,0 % | 99,5 % |
| p95 en el servidor, lecturas simples | 300 ms | 300 ms |
| p95 en el servidor, planificar | 800 ms | 800 ms |
| p95 de punta a punta desde Cartagena, lecturas | 1,0 s | 0,8 s |
| p95 de punta a punta, planificar | 2,0 s | 1,5 s |
| p99 del arranque en frío | 5 s | 5 s |
| Errores 5xx | < 0,5 % diario | < 0,5 % diario |
| Rechazos 429 a usuarios legítimos | < 1 % | < 1 % |
| Rechazos de Lambda por límite | 0 | 0 |
| Datos que se pueden perder (RPO) | 24 h | 1 h |
| Tiempo para recuperarse (RTO) | 4 h | 1 h |
| Votos sin aplicar (conciliación diaria) | 0 | 0 |
| Vulnerabilidades altas en dependencias | Ninguna por más de 7 días | Ninguna por más de 7 días |

## 7. Orden

- **P0, antes de publicar (3 a 4 días, USD 0).** Encaja con la espera por Transcaribe:
  - D1 alarmas, presupuesto y sonda;
  - D2 copias;
  - S1 límites a lo anónimo;
  - S3 configuración;
  - S5 autorización exigida por el servidor;
  - D3 carga de datos al desplegar;
  - E2 contador en memoria;
  - E1 caché de referencia;
  - C4 filtro de viajes;
  - D4 versiones y alias.
- **P1, antes de abrir a la ciudad (2 a 3 semanas, de USD 0 a unos 60 al mes):**
  - L3 CloudFront con WAF y L2 gzip;
  - L1 conexiones abiertas;
  - E3 llegada vectorizada y E4 índices;
  - S2 defensa contra cuentas falsas;
  - C1 a C3 transacciones e idempotencia;
  - S4 registros;
  - E5 retención resumida;
  - D5 app resistente;
  - D6 límite de cuentas para IP compartidas;
  - E6 más concurrencia y Atlas Flex o M10.
- **P2, con miles de viajeros a la vez:** clúster dedicado con SLA y copia continua. Varias regiones no se justifican todavía.

## 8. El P0, hecho el 26 de octubre

| # | Qué quedó | Falta |
|---|---|---|
| D1 | `deploy/aws/alarmas.sh`: 5 alarmas (5xx, fallas, rechazos, p95 sobre 3 s, concurrencia de 8 o más) y el presupuesto `karta-mensual` de USD 5, con aviso por correo. La sonda `.github/workflows/sonda.yml` pide `/health` cada 10 min desde GitHub | Camilo corre `ajustar-permisos.sh` (una vez, con la cuenta principal) y confirma el correo de la suscripción. La sonda corre cuando se fusione a `main` |
| D2 | Copia propia diaria (`respaldo.py`), a las 3 a. m. de Colombia, en un bucket privado y cifrado que borra cada copia a los 7 días. Sin los datos de referencia, que están en el repositorio. `deploy/aws/respaldos.sh` lista, copia ya y restaura. Las copias de Atlas no se usaron: cuestan USD 0,10 al día (hasta 3 al mes), piden tarjeta y están en vista previa ([Atlas](https://www.mongodb.com/docs/atlas/backup/cloud-backup/free-cluster-backup/)). Declarada en la política y el manual | Camilo vuelve a correr `ajustar-permisos.sh`, que crea el bucket, y se despliega |
| D3 | Los índices y los datos de referencia se preparan al desplegar (evento `preparar`), no en cada arranque en frío | — |
| D4 | Cada despliegue publica una versión, la prepara y la prueba antes de mover el alias «live»; `--volver N` y `--versiones` | La dirección de la API cambia a la de «live»: hace falta un APK nuevo. La dirección vieja se borra cuando nadie use el APK anterior |
| S1 | Límite por IP en memoria para todas las rutas: 240 por minuto; planificar, 30; buscar, 120. Las IPv6 cuentan por su red /64. Middleware ASGI puro, sin costo medible. `/routes/risk` admite hasta 1.000 puntos | — |
| S3 | El APK de release falla sin la llave propia; `--rotar-secreto` y rotación cada 90 días en el manual | Ver abajo lo que no se hizo |
| S5 | El servidor no recibe datos de una cuenta sin la versión vigente de la política (403). La app manda la versión aceptada al crear o renovar la sesión, y el registro la guarda | — |
| E1 | Caché de 60 s por instancia para rutas, estaciones, horarios y sentidos; se vacía al recargar los datos. Los paraderos no pasan por ella porque llevan lo de la comunidad | — |
| E2 | Los conteos del piloto se juntan en memoria y se guardan cada 60 s o con el calentador | Se pueden perder hasta 60 s de conteos si Lambda recicla la instancia |
| C4 | Un viaje compartido vencido deja de contar en el acto | — |

**Lo que no se hizo de S3, y por qué:**
- **`/docs` sigue público.** El código es abierto (AGPL), así que esconder la documentación no protege nada, y la entrega del curso pide el enlace de la API.
- **El JWT sigue durando 7 días.** Las cuentas con correo no tienen renovación automática: acortarlo las obligaría a iniciar sesión más seguido. Queda para cuando haya tokens de renovación (P1).
- **`lambda:Get*` sigue en el usuario de despliegue.** Ese usuario puede subir código, y el código lee los secretos; quitarle la lectura no los protege. La mejora real es mover los secretos a Parameter Store (P1).
- **No se reservó concurrencia.** Con el tope de 10 de esta cuenta, AWS no lo permite. Primero hay que pedir que lo suban, gratis, en *Service Quotas* (P1).

## Fuentes

Consultadas el 26 de octubre de 2026:
- [Límites de Atlas Free](https://www.mongodb.com/docs/atlas/reference/free-shared-limitations/) · [límites de Flex](https://www.mongodb.com/docs/atlas/reference/flex-limitations/) · [costos de Flex](https://www.mongodb.com/docs/atlas/billing/atlas-flex-costs/) · [notas de producción (SLA)](https://www.mongodb.com/docs/atlas/production-notes/) · [precios de MongoDB](https://www.mongodb.com/pricing)
- [Cuotas de Lambda](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html) · [ciclo de vida de Lambda](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtime-environment.html) · [precios de Lambda](https://aws.amazon.com/lambda/pricing/)
- [Precios de CloudFront](https://aws.amazon.com/cloudfront/pricing/) · [control de acceso al origen para Lambda](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-lambda.html)
- [OpenFreeMap](https://openfreemap.org/) · [`HttpClient.idleTimeout` de Dart](https://api.dart.dev/stable/dart-io/HttpClient/idleTimeout.html)
- [OWASP API Security Top 10 2023](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)
