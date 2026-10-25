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
3. **Posición compartida:** a bordo, durante un viaje activo, la app envía la posición del bus cada ~30 s asociada a un viaje anónimo, no al usuario.
   - **Activada por defecto** (decisión del 24 de octubre, como hace Waze): el tiempo real depende de cuántos la comparten.
   - **Aviso una sola vez**, al empezar el primer viaje en bus, con un único botón «Entendido, empezar viaje». Ese toque es la autorización expresa (Ley 1581 y Decreto 1377, art. 7: conducta inequívoca; el silencio nunca cuenta). Sin haber visto el aviso no se envía nada.
   - **Se apaga en Perfil › Privacidad**, con confirmación, y no desde la pantalla del viaje. Durante el viaje solo se ve un indicador: «Compartiendo dónde va el T103, sin tu nombre».
   - **No se condiciona nada a compartir:** ver las llegadas es igual para todos.

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

**D9 · Cuenta invisible** (decidido el 24 de octubre).
- **Sin pantalla de inicio de sesión:** al abrir Karta por primera vez, el teléfono recibe una cuenta anónima, sin nombre ni correo. Todo funciona sin registrarse, también compartir el bus.
- **Registrarse** es ponerle correo a esa misma cuenta: conserva la reputación y los lugares, y los lleva a otros teléfonos.
- **Abuso:** las cuentas nuevas empiezan con poca confianza y crear cuentas tiene un límite por IP.

| | Sin registrarse | Registrado | Reputación alta (nivel 3+) |
|---|---|---|---|
| Mapa, planificar, viaje, avisos, llegadas | ✓ | ✓ | ✓ |
| Compartir el bus, ocupación, «Pasó lleno» | ✓ | ✓ | ✓ |
| Reportar | ✓, «por confirmar» hasta que otro lo confirme (no pesa en el riesgo) | ✓, al instante | ✓ y pesa más en el riesgo |
| «¿Sigue ahí?» | ✓ | ✓ | su «ya no está» lo retira solo |
| Lugares y reputación | solo en ese teléfono | en la cuenta | — |

**D10 · Comunidad y premios visuales** (sin beneficios económicos por ahora).
- **Marcos del avatar por nivel**, con nombres de Cartagena: 2 «Muralla», 3 «Bahía», 4 «Castillo», 5 «La Popa».
- **Insignias por logros:** «Primer aviso», «Ojo de halcón» (10 reportes confirmados), «Madrugador», «Guardián del T103» (el que más reportes confirmados tiene en la ruta en el mes).
- **Se ven junto al alias en los reportes:** además de premio, le dicen a los demás qué tan confiable es quien reporta.
- **«Tu impacto»** en el perfil: cuántos viajeros vieron tus reportes.
- **Ajuste a la reputación:** el punto por votar se da solo si el voto coincide con lo que concluye la comunidad (hoy se gana por votar en todo).
- **Compartir el bus no da reputación** (los viajes son anónimos a propósito): queda como un contador que solo guarda el teléfono.

**D11 · Cómo pedir la parada: estación o paradero.** Según el [Manual de Operaciones de Transcaribe](https://transcaribe.gov.co/Centro%20de%20Documentacion/MANUAL%20DE%20OPERACIONES%20FINAL.pdf) (Resolución 030 de 2016):
- Hay **dos tipos de punto de parada**:
  - **Estaciones:** las 18 del corredor, con plataforma y puertas automáticas; se baja por la izquierda. Los expresos solo paran en las estaciones dobles.
  - **Paraderos:** a nivel de andén en las vías mixtas, cada ~250 m; se baja por la derecha.
- **Las troncales y pretroncales usan los dos:** el T103, por ejemplo, para en estaciones sobre la Pedro de Heredia y en paraderos en Bocagrande.
- **Cómo avisa Karta:**
  - si la bajada es una estación, el bus para solo: se queda «Bájate en la próxima»;
  - si es un paradero, «¡Toca el timbre!»;
  - «¡Grita parada!» queda listo para cuando haya busetas en los datos.
- **El manual no menciona el timbre. Lo confirmó Camilo como usuario** (25 de octubre):
  - en las estaciones de su ruta el bus para siempre, sin timbre;
  - en los paraderos se toca el timbre en el tramo entre la última parada y la tuya.

  El aviso a 200 m del paradero cae dentro de esa ventana. Para las demás rutas y las busetas, la comunidad lo confirma (D12).

**D12 · Lo que la comunidad sabe de las rutas.** Preguntar cuando algo se sale de lo normal, para armar una base de conocimiento:
- **Desvíos:**
  - si el viajero va a bordo y el bus se sale del recorrido a velocidad de bus, Karta pregunta «¿El T103 se desvió?» en vez de proponer otra ruta;
  - con un sí, sigue acompañando el viaje y los demás ven «El T103 va desviado cerca de X, según 2 viajeros» (vence en horas).
- **Cómo se pidió la parada:** al bajarse en un paradero, Karta pregunta «¿Cómo pediste la parada?» (toqué el timbre, paró solo, le avisé al conductor). Con suficientes respuestas, el aviso dice lo que de verdad funciona allí, con «según N viajeros».
- **Paradas que no se hicieron:** si el GPS muestra que el bus pasó sin detenerse por una estación de su servicio, Karta pregunta después si estaba cerrada.
- **Paraderos sin coordenadas:** donde el bus se detiene a menudo es un paradero candidato. Se detecta en el teléfono y solo se envía el punto, sin el recorrido.
- **Reglas para preguntar:**
  - como máximo una pregunta por viaje;
  - en un momento seguro (después de bajarse), salvo el desvío, que importa en el momento;
  - con respuestas de un toque y siempre se puede saltar.

**D13 · Teléfonos de gama baja.**
- **Primero medir:** compilación de perfilado en el POCO, en cuatro escenas (inicio, mover el mapa, planificar y viaje activo), con y sin animaciones.
- **El sospechoso principal es el mapa vectorial**, más que las animaciones cortas. El POCO es de gama alta: si ya usa más de la mitad de cada fotograma, un teléfono barato se trabará. En el piloto se prueba con uno o dos teléfonos económicos.
- **«Modo ligero»** en Perfil › Apariencia: sin animaciones decorativas ni latidos, mapa con menos detalle y, si la medición lo justifica, teselas raster.
- **Sugerencia automática:** se ofrece una vez si la app detecta muchos fotogramas lentos.

**D14 · Buses varados** (propuesto el 25 de octubre). Que un Transcaribe se vare es frecuente, y quien lo espera no tiene cómo saberlo.
- **Nuevo tipo de reporte, «Bus varado»** (grupo servicio): con la ruta y el sentido, y vigencia de 1 hora.
- **Detección en el viaje:** a bordo, si el bus lleva más de 4 minutos sin moverse lejos de una estación o un paradero, Karta pregunta «¿El T103 se varó?». Las respuestas posibles: «Sí, se varó», «No, es un trancón» o «Ya me bajé».
  - Con un sí, el reporte se crea con ese toque y Karta propone qué hacer: «Toma el siguiente T103, llega en unos 9 min según 2 viajeros», o recalcular desde ahí.
  - Con «trancón», se ofrece reportarlo.
- **Las llegadas lo tienen en cuenta:** un bus reportado como varado deja de contar como «el próximo que llega». Quien espera más adelante ve «Un T103 se varó en Bazurto, según 2 viajeros: espera el siguiente».

**D15 · Buscar direcciones con la nomenclatura colombiana.** Hoy el buscador solo conoce los 453 lugares con nombre. OpenStreetMap tiene apenas 505 direcciones con número en toda Cartagena, casi todas en el Centro, así que ningún geocodificador gratuito basado en él resuelve «Calle 9 # 3-50».
- **Lo propio, gratis y sin límites:** entender la dirección y ubicarla en los cruces que ya tenemos (1.678 con vías numeradas).
  - Formatos: «Calle 9 # 3-50», «Cl 9 3 50», «Cra. 3 #8-129», «Tv 54 # 21-30», «Diagonal…», «Avenida…».
  - Cálculo: «Calle 9 # 3-50» es la Calle 9 en su cruce con la vía número 3, y 50 m más allá, hacia la 4.
  - Precisión esperada: 20 a 60 m, suficiente para planificar.
- **Calles completas:** escribir «Calle 30» muestra la vía en el mapa.
- **Respaldo externo**, solo si el piloto muestra huecos: evaluar un servicio con plan gratuito que tenga mejores direcciones colombianas, revisando antes sus términos de uso. Nominatim no sirve para autocompletar porque su política de uso lo prohíbe.

**D16 · Lo que está cerca: estaciones, rutas y paraderos.** El inicio solo muestra estaciones. Los paraderos no tienen coordenadas oficiales, y OpenStreetMap tiene apenas 103 en Cartagena (38 con nombre).
- **«Rutas que pasan cerca»:** para cada ruta a menos de ~150 m, por dónde pasa y a qué distancia. Por ejemplo: «A107 pasa por la Av. Kennedy con Calle 18 · 120 m». Es honesto, porque no inventa un paradero exacto.
- **Paraderos reales cuando haya datos:**
  - los de OpenStreetMap etiquetados como Transcaribe;
  - los que la comunidad confirme (D12: donde el bus se detiene a menudo).

  Se muestran con «según N viajeros» hasta estar confirmados.

**D17 · Aprender de los demás y medirnos.** Google Maps es un competidor directo: muy completo, pero con quejas por su navegación y por las rutas y los tiempos de transporte.
- **Estudio de las reseñas** de las tiendas (Google Play y App Store) de Google Maps, Moovit, Waze, MiBus y las apps de Transcaribe y TransMilenio: los dolores más frecuentes, lo que se valora y qué adoptar y evitar (en curso).
- **Pruebas comparativas en el piloto** (fase 4):
  - **Recorridos:** 10 trayectos típicos, planificados en Karta, Google Maps y Moovit.
  - **Qué se mide:**
    - el error de la hora de llegada estimada frente a la real;
    - la distancia a la que suena cada aviso de bajarse;
    - cuántos toques hacen falta para empezar un viaje;
    - batería y datos móviles por hora de viaje.
- **Trazas para pruebas:** con permiso expreso de quienes hagan el piloto, se graban los recorridos GPS reales. Se usan para reproducir viajes en las pruebas automáticas y para afinar el seguidor. Nunca salen del equipo de desarrollo y se borran al terminar.

**D18 · Estaciones por dentro: plataformas, sentido y estaciones confusas** (propuesto el 25 de octubre).
- **El problema real:**
  - en Patio Portal hay varias plataformas;
  - Santa Lucía (alimentadores) y Madre Bernarda (troncales y pretroncales, incluido el T100E) quedan una frente a la otra, a unos 65 m.

  Hoy Karta solo conoce las 17 estaciones del corredor: **Patio Portal y Santa Lucía no existen como estaciones**.
- **Lo que ya hay en OpenStreetMap:** áreas de parada de Santa Lucía y Patio Portal, y plataformas por ruta. Por ejemplo:
  - una con A103, A104, A105, A107, A108 y A111;
  - otra con T100E, T101, T102, T103, X102 y X103;
  - otra con A101, A102, A114, A117 y C016.
- **Modelo:** cada estación tiene plataformas, y cada plataforma lleva:
  - nombre y coordenadas;
  - las rutas y el sentido de cada una;
  - una descripción («lado del Éxito»);
  - la fuente (OSM, oficial o comunidad) y la confianza («según N viajeros»).
- **Lo que ve el viajero al subir:**
  - «Sube al T103 en **Madre Bernarda**, plataforma hacia el Centro», con un plano pequeño de la estación que muestra dónde está él y a dónde caminar;
  - en las estaciones confusas, una advertencia: «Ojo: Santa Lucía, la de enfrente, es solo de alimentadores».
  - Cada tramo en bus dice su sentido: «hacia La Bodeguita» o «hacia Portal».
- **Cómo aprende de la comunidad:**
  - **Sin preguntar:** con el viaje compartido activo, el punto donde la gente sube a cada ruta. Agrupados, esos puntos revelan la plataforma de cada ruta y sentido. Solo se usa el punto de subida, sin el recorrido.
  - **Preguntando una vez:** tras subir en una estación con varias plataformas, «¿Desde dónde tomaste el T103?».
  - **Guardianes de estación** (niveles 4 y 5): corrigen el plano.
  - **Fuente oficial:** pedirle a Transcaribe los planos de módulos de sus estaciones.
- **Primer paso, sin depender de la comunidad:** importar Patio Portal, Santa Lucía y las plataformas por ruta desde OpenStreetMap.
- **Lo que se sabe por experiencia** (Camilo, 25 de octubre):
  - **Patio Portal:** dos plataformas unidas por un puente. Cada una tiene dos mitades donde paran rutas distintas, y en cada mitad se hace la fila. Los letreros dicen el código de cada ruta (X103, T101, T100E).
  - **De Santa Lucía a Madre Bernarda** hay que salir de la estación y cruzar por la cebra. El aviso lo dice así: «Sal de Santa Lucía y cruza por la cebra hasta Madre Bernarda».
- **Cultura ciudadana:** en las plataformas, un mensaje breve y amable en el momento justo: «Haz la fila del T103: se sube en orden». Ver [plan-comunidad.md](plan-comunidad.md).

**D19 · «El que pase primero».** Varias rutas sirven el mismo trayecto (en la troncal, el T101, el T102 y el T103 comparten estaciones).
- **Opciones agrupadas:** «Toma el T101 o el T103, el que pase primero», con la llegada de cada uno.
- **Cálculo:**
  - para cada ruta se usa la llegada según los viajeros;
  - si no hay datos, la espera esperada es la mitad de la frecuencia habitual. La frecuencia se aprende de los avistamientos por franja horaria; al principio se usan valores por tipo de ruta.
  - Se suma el tiempo a bordo, porque un expreso como el T100E puede pasar después y llegar antes.
  - Karta distingue «Pasa primero» de «Llegas primero».
- **En el viaje:** Karta detecta en cuál se subió cuando las rutas se separan. Solo pregunta si cambia algo.
- **Honestidad:** «Calculado con 3 viajeros en la última media hora», o «Sin datos: estimado con la frecuencia habitual».

**D20 · Identidad y comunidad.**
- **Tono:** cercano, con identidad propia y diciendo siempre para qué sirve cada aporte («Esta llegada es precisa gracias a 3 viajeros»).
- **Reconocimiento sin dinero:** «Gracias», «Tu impacto», marcos e insignias, confianza por nivel, Guardianes de ruta o de estación, acceso anticipado y eventos de mapeo.
- **Límites:** sin trampas de diseño y con puntos solo por aportes validados.
- **Detalle:** [plan-comunidad.md](plan-comunidad.md).

**D21 · Brechas del estudio de reseñas** ([estudio-resenas.md](estudio-resenas.md)):
- mostrar **hace cuánto** se actualizó cada llegada;
- reportar «no paró en el paradero»;
- el sentido en cada bus (D18);
- un límite de caminata elegible;
- una consulta de un vistazo (notificación con el próximo bus);
- planificar sin conexión;
- reportar «ruta o paradero desactualizado».
- **Dos reglas de proceso:** nunca quitar una función sin avisar, y publicar las reglas de moderación.

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
| 3 · Viaje activo y tiempo real | mié 11 – mar 17 nov | Máquina de estados; avisos de subir, bajar y transbordar; alertas y re-enrutar; avistamientos, ocupación y posición compartida; estimación «según N viajeros»; cuenta invisible (D9); «¡Toca el timbre!» en paraderos (D11); «¿El bus se desvió?» (D12) | Un viaje real en el T103 avanza solo y avisa antes de bajarse |
| 3b · Comunidad y datos | — | Buscar direcciones (D15); buses varados (D14); pesos por reputación (D9); premios visuales, «Gracias» y «Tu impacto» (D10, D20); base de conocimiento (D12); antigüedad del dato y «no paró» (D21) | Escribir «Calle 9 # 3-50» encuentra la dirección; un bus varado se pregunta, se reporta y deja de contar en las llegadas; al bajarse en un paradero, Karta pregunta cómo se pidió la parada |
| 3c · Encontrar y abordar | — | Patio Portal, Santa Lucía y plataformas por ruta (D18); sentido en cada bus; rutas y paraderos cerca (D16); «el que pase primero» (D19); límite de caminata (D21) | En Madre Bernarda, Karta dice la plataforma y el sentido del T103 y advierte que Santa Lucía es de alimentadores |
| 4 · Despliegue y piloto | mié 18 – lun 23 nov | API en la nube con HTTPS; APK firmado; piloto con compañeros durante 4–5 días; corrección de errores, rendimiento y accesibilidad; modo ligero y prueba en teléfonos económicos (D13); pruebas comparativas con Google Maps y Moovit (D17); política de tratamiento de datos escrita (Ley 1581) | Hay datos reales del piloto y no queda ningún error crítico abierto |
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
| Privacidad de la ubicación (Ley 1581) | Compartir por defecto con aviso claro una vez y revocable en Privacidad; solo el tramo en bus; viajes anónimos, TTL corto y sin historial. Falta la política de tratamiento de datos escrita (fase 4). |
| Datos abiertos incompletos o desactualizados | Contrastar con OpenStreetMap y mostrar la fuente y la fecha. |
| Falta de tiempo | Recortes en este orden: (1) posición compartida en vivo, (2) transbordos, (3) niveles de reputación. El resto es el núcleo. |

## 11. Fuera de alcance (después de la entrega final)

- Busetas y rutas tradicionales: datos abiertos del distrito o mapeo comunitario. Con ellas llega «¡Grita parada!» (D11).
- Marcar los paraderos reales: los niveles 4 y 5 los proponen sobre el mapa (D10, D12).
- iOS y web.
- Saldo de la tarjeta: depende de los sistemas de Transcaribe.
- Monetización: [plan de sostenibilidad sin anuncios](plan-sostenibilidad.md).
- Datos de tráfico externos: [plan de datos de tráfico](plan-datos-de-trafico.md).
- Licencias y publicación: [plan de código abierto](plan-codigo-abierto.md) (AGPL en el servidor, Apache en la app).
- Transporte privado: excluido.

## 12. Preguntas abiertas

1. Fecha exacta de la entrega final y qué pide su plantilla.
2. Rol de José en el plan.
3. ¿Se hace el piloto con compañeros? Requiere la API desplegada y su consentimiento.
