# Karta — Sistema de enrutamiento de transporte público

Proyecto de aula de **Ingeniería de Servicios de Internet**, Universidad de Cartagena (2026-2).

Karta ayuda al viajero de Cartagena a moverse en Transcaribe con menos incertidumbre: busca su destino,
le sugiere cómo llegar (caminata + ruta + caminata) con el riesgo de cada opción y muestra en el mapa lo
que reporta la comunidad (el servicio, la vía y la seguridad), que otros viajeros confirman o desmienten. El alcance del prototipo es el área urbana de
Cartagena de Indias.

## Estado actual

| Funcionalidad | Estado |
|---|---|
| Usar Karta sin registrarse: cuenta invisible del teléfono, sin nombre ni correo | ✅ registrarse le pone correo a la misma cuenta |
| Registro e inicio de sesión (JWT, sesión guardada en almacenamiento seguro) | ✅ desde el perfil |
| Reportar en dos pasos: 10 tipos ilustrados en 3 grupos y sus detalles («el T103 no pasa · 20 min», «el X103 no paró: iba lleno») | ✅ sin cuenta salen «por confirmar» |
| Ver los reportes vigentes en el mapa | ✅ cada tipo vive de 30 min a 12 h; cada confirmación lo renueva |
| «¿Sigue ahí?»: confirmar o desmentir reportes ajenos, reputación y niveles | ✅ un voto por viajero; dos «ya no está» seguidos lo retiran, o uno desde el nivel 3 |
| Reputación justa: puntos solo por aportes que la comunidad valida; desde el nivel 3, los reportes pesan más | ✅ votar da puntos solo si la comunidad coincide |
| «Gracias» a quien reportó y «Tu impacto» (vistas, confirmaciones, gracias, buses compartidos) | ✅ |
| Marcos del avatar por nivel (Muralla, Bahía, Castillo, La Popa) e insignias; el nivel de quien reporta, junto a su alias | ✅ solo visuales: nada se compra |
| Buscar un lugar de Cartagena o elegir el punto en el mapa | ✅ 453 lugares de OpenStreetMap y nombres populares («Torre del Reloj») |
| Buscar direcciones con la nomenclatura colombiana («Calle 9 # 3-50», «Cra. 3 No. 8-129», «Tv 54 #21») | ✅ 4.671 cruces numerados de OpenStreetMap, 20 a 60 m de precisión |
| Rutas sugeridas de Transcaribe con su riesgo, comparadas en el mapa | ✅ 24 rutas y 17 estaciones de OpenStreetMap |
| Transbordo entre dos rutas y criterio: más rápida, más segura o sin transbordo | ✅ |
| Solo rutas que operan a la hora de salida (horarios oficiales, festivos incluidos) | ✅ avisa cuándo sale la primera |
| Paraderos fuera de la troncal nombrados por el cruce de calles («Av. Pedro de Heredia con Cra. 80C») | ✅ 2083 cruces de OpenStreetMap |
| Estaciones cercanas con sus rutas | ✅ |
| Lugares guardados (Casa, Trabajo…) | ✅ CRUD, máximo 10 por viajero |
| Límite de frecuencia de peticiones (registro, inicio de sesión, reportes y votos) | ✅ responde 429 con `Retry-After` |
| Viaje activo paso a paso, que avanza solo con el GPS (también con la pantalla apagada) | ✅ «Sube al T103», «Bájate en 3 paradas» |
| Avisos para bajarse: en una estación el bus para solo; en un paradero, «¡Toca el timbre!» a 200 m | ✅ notificación y pantalla completa |
| «¿El T103 se desvió?» cuando el bus sale de su recorrido | ✅ |
| Llegada estimada «según N viajeros» y qué tan lleno va el bus | ✅ avistamientos y viajes compartidos; siempre dice de cuándo es el dato, y sin conexión lo envejece y lo avisa |
| Bus varado: a bordo, 4 min quieto lejos de una estación, «¿El T103 se varó?»; quien espera lo ve y ese bus no cuenta en la llegada | ✅ |
| «¿Cómo pediste la parada?» al bajarse en un paradero; con 3 respuestas que coinciden, el aviso dice qué funciona allí | ✅ una pregunta por viaje, siempre se puede saltar |
| Cultura ciudadana: «Haz la fila del T103: se sube en orden», «Deja bajar primero» | ✅ sin regañar ni premiar |
| Compartir dónde va el bus (anónimo, solo a bordo, vence a los 5 min) | ✅ activado por defecto, se apaga en Perfil › Privacidad |

## Arquitectura

```
Flutter (BLoC) ──HTTP/JSON + Bearer JWT──▶ FastAPI ──PyMongo──▶ MongoDB
      │
      └──HTTPS──▶ teselas vectoriales de OpenFreeMap (datos de OpenStreetMap), con estilo propio «Bahía»
```

El backend sigue una arquitectura hexagonal (puertos y adaptadores):

| Carpeta | Contenido |
|---|---|
| `backend/src/domain` | Entidades, reglas de negocio (`reportes.py` con el catálogo y la validación comunitaria, `trip_planning.py`, `route_risk.py`, `geo.py`), puertos (`ports.py`) y esquemas Pydantic de la API. No depende de FastAPI ni de MongoDB |
| `backend/src/application` | Casos de uso: `AuthService`, `IncidentService`, `PlaceService` (buscador y lugares guardados) y `TripService` (rutas sugeridas, estaciones cercanas) |
| `backend/data`, `backend/scripts` | Rutas, estaciones, lugares y cruces de calles de OpenStreetMap (`importar_osm.py`, `importar_cruces.py`) y horarios oficiales de Transcaribe (`importar_horarios.py`); se cargan al arrancar la API |
| `backend/src/infrastructure` | Adaptadores: FastAPI y routers, repositorios MongoDB, Argon2 + JWT, configuración |
| `frontend/lib/core` | Configuración y servicios compartidos (URL de la API, GPS, errores de la API), sistema de diseño «Bahía» (`design/`) y capa del mapa (`map/`) |
| `frontend/lib/features/<funcionalidad>` | `data` (repositorios HTTP), `domain` (modelos), `presentation` (BLoC y pantallas) |

### Modelo de datos (MongoDB)

| Colección | Documento | Índices |
|---|---|---|
| `users` | `email`, `password_hash` (Argon2id), `nombre`, `alias` («Ana P.»), `tipo_viajero`, `reputacion`, `impacto` (`reportes`, `confirmaciones`, `gracias`, `vistas`), `terminos_aceptados_en`, `creado_en`, `lugares_guardados` (embebidos, máx. 10). La cuenta invisible: `anonimo`, `secreto` (huella SHA-256) y `visto_en` | único parcial en `email` y en `secreto`; TTL de 180 días en `visto_en` de las cuentas invisibles |
| `incidents` | `reportado_por` (ObjectId), `grupo`, `tipo`, `detalles`, `lugar`, `ubicacion` (GeoJSON Point), `votos_si`, `votos_no`, `no_seguidos`, `sin_cuenta`, `nivel_autor`, `gracias`, `creado_en`, `expira_en` | `2dsphere` en `ubicacion`; TTL en `expira_en` |
| `incident_votes` | `incidente`, `usuario`, `sigue` (sí / no), `creado_en`, `expira_en` | único en (`incidente`, `usuario`); TTL |
| `incident_thanks`, `incident_views` | `incidente`, `usuario`, `en`, `expira_en`: un «Gracias» y una vista por viajero y reporte | único en (`incidente`, `usuario`); TTL |
| `sightings` | `ruta`, `ubicacion`, `ocupacion`, `en`, `expira_en` (30 min); sin quién lo envió | (`ruta`, `en`); TTL |
| `live_trips` | `_id` aleatorio, `ruta`, `ubicacion`, `ocupacion`, `en`, `expira_en` (5 min sin posiciones); sin quién lo envió | (`ruta`, `en`); TTL |
| `stop_answers` | `ruta`, `ubicacion` del paradero, `como` (`timbre`, `paro_solo`, `conductor`), `en`, `expira_en` (1 año); sin quién respondió | `2dsphere` con `ruta`; TTL |
| `rate_limits` | `_id` = acción, clave y ventana; `conteo`, `expira_en` | TTL en `expira_en` |
| `places` | `nombre`, `tipo`, `ubicacion` (Point), `tokens` (palabras normalizadas) | `2dsphere`; `tokens` |
| `stations` | `nombre`, `ubicacion` (Point), `rutas` | `2dsphere` |
| `transit_routes` | `nombre`, `tipo`, `desde`, `hasta`, `geometria` (LineString) | `2dsphere` en `geometria` |
| `route_schedules` | `_id` = código de ruta; primer y último despacho de `lunes_a_viernes`, `sabado` y `domingo_y_festivos` | — |
| `intersections` | `nombre` («Av. Pedro de Heredia con Cra. 28»), `ubicacion` (Point) | `2dsphere` |
| `route_stops` | Paraderos oficiales ubicados (`scripts/importar_paraderos.py`): `ruta`, `sentido`, `orden`, `nombre`, `estacion`, `modulo` («A1»), `precision` (`estacion` o `direccion`), `ubicacion` | (`ruta`, `sentido`, `orden`); `2dsphere` |
| `route_directions` | `_id` = «T101-ida», `hacia` («el Centro») | — |
| `address_crossings` | `nombre`, `vias` (`calle:9`, `carrera:3`), `ubicacion`: cruces de vías numeradas para ubicar direcciones | `vias` |

El riesgo de una ruta se calcula trazando un corredor de 500 m alrededor de la polilínea
(en UTM 18N, EPSG:32618, para medir en metros) y consultándolo con `$geoWithin` sobre el índice `2dsphere`.
Las rutas sugeridas parten de las rutas que pasan a menos de 800 m del origen o del destino (`$geoIntersects`)
y operan a la hora de salida. Cada ruta se muestrea cada 25 m y, en los dos sentidos, se calcula lo antes que se
llega a cada punto desde el origen y lo que falta desde él hasta el destino. Un viaje directo une esos dos
cálculos en la misma ruta; un transbordo los une donde dos rutas pasan a menos de 300 m (`STRtree` de Shapely).
Se descartan los transbordos que no ganan a ir directo en una de sus rutas, y las opciones se ordenan por tiempo
más una penalización por riesgo, que pesa el triple con el criterio «más segura».

Los diagramas de clases, del modelo de datos y de secuencia (PlantUML y PNG) están en [`docs/diagramas`](docs/diagramas).

## Puesta en marcha

### Opción A: Docker (recomendada)

Requiere Docker Engine con Compose. Desde la raíz del repositorio:

```bash
docker compose up --build
```

- API: <http://localhost:8000> (redirige a Swagger, en `/api/v1/docs`)
- MongoDB: `localhost:27017`, solo accesible desde el mismo equipo. Credenciales en `docker-compose.yml`

Al arrancar se crean los índices y se cargan datos de demostración: un usuario demo (credenciales en
`backend/.env.example`) y algunos incidentes en Cartagena. Los cambios en `backend/src` recargan la API solos.

### Opción B: instalación local

Requiere Python 3.12 y un MongoDB 7 u 8 (local o un clúster gratuito M0 de MongoDB Atlas).
Desde la carpeta `backend/` (los imports parten de `src.`, así que los comandos deben correr ahí):

```bash
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements-dev.txt
cp .env.example .env               # Windows: copy .env.example .env — luego ajusta MONGO_URI y JWT_SECRET
python -m src.infrastructure.seed  # opcional: datos de demostración
uvicorn src.infrastructure.main:app --reload
```

### App Flutter

Desde la carpeta `frontend/`:

```bash
flutter pub get
flutter run -d chrome     # la forma más rápida de probar
flutter run -d linux      # escritorio Linux (requiere libsecret-1-dev)
```

La URL de la API se define con `--dart-define`; por defecto es `http://127.0.0.1:8000/api/v1`.

| Dónde corre la app | Cómo ejecutarla |
|---|---|
| Chrome o escritorio, en el mismo equipo que la API | `flutter run` sin parámetros extra |
| Emulador de Android | `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1` |
| Celular físico en la misma red Wi-Fi | ver la sección siguiente |

En modo debug, si el GPS no responde (común en Linux de escritorio) y no hay una ubicación conocida,
la app usa una coordenada de respaldo en Cartagena y lo avisa. En release nunca inventa la ubicación.

### Probar en un celular Android (APK de prueba)

El celular y el computador con la API deben estar en la misma red (sirve el hotspot del propio celular).

1. Levanta el backend con `docker compose up` (publica el puerto 8000 en la red local).
2. Averigua la IP del computador: `hostname -I` en Linux, `ipconfig` en Windows.
3. Compila el APK apuntando a esa IP:

   ```bash
   flutter build apk --debug --target-platform android-arm64 \
     --dart-define=API_BASE_URL=http://<IP-del-computador>:8000/api/v1
   ```

4. Instala `build/app/outputs/flutter-apk/app-debug.apk` en el celular (por cable con
   `adb install`, o copiándolo y permitiendo "instalar apps de origen desconocido").

Si la IP del computador cambia, hay que recompilar el APK. Si la app no conecta, revisa que el
firewall del computador permita conexiones entrantes al puerto 8000.

## Endpoints

| Método | Ruta | Sesión | Descripción |
|---|---|---|---|
| GET | `/api/v1/health` | — | Estado del servicio y de la base de datos |
| POST | `/api/v1/auth/anonymous` | — | Cuenta invisible del teléfono: manda su `secreto` aleatorio y recibe la sesión (siempre la misma cuenta). Máx. 60 por hora por IP |
| POST | `/api/v1/auth/register` | opcional | Registrar un viajero (exige `acepta_terminos: true`); con la sesión de la cuenta invisible, le pone correo a esa misma cuenta. Máx. 10 por hora por IP |
| POST | `/api/v1/auth/login` | — | Iniciar sesión; devuelve un token Bearer (JWT). Máx. 10 por minuto por IP |
| GET | `/api/v1/users/me` | ✅ | Perfil del viajero autenticado: alias, reputación, nivel (1 a 5), `impacto`, `marco`, `insignias` y `siguiente_insignia` con su avance |
| GET | `/api/v1/incidents/types` | — | Catálogo de reportes: grupos, tipos, preguntas y vigencia |
| POST | `/api/v1/incidents/` | ✅ | Reportar (`tipo`, `detalles`, `latitud`, `longitud`); el autor sale del token. Máx. 6 cada 10 min |
| GET | `/api/v1/incidents/` | — | Reportes vigentes, opcionalmente dentro de una caja (`lon_min`, `lat_min`, `lon_max`, `lat_max`) |
| GET | `/api/v1/incidents/{id}` | opcional | Detalle con el alias, el nivel y el marco del autor; con sesión dice si es tuyo, cómo votaste y si ya diste las gracias |
| POST | `/api/v1/incidents/{id}/thanks` | ✅ | «Gracias» a quien reportó (suma a su «Tu impacto», no a su reputación). 403 si es tuyo, 409 si ya agradeciste |
| POST | `/api/v1/incidents/{id}/votes` | ✅ | «¿Sigue ahí?» (`sigue: true/false`). 403 si es tuyo, 409 si ya votaste. Máx. 30 cada 10 min |
| GET | `/api/v1/routes/?tipo=` | — | Rutas de Transcaribe con su trazado GeoJSON (para dibujarlas en el mapa) |
| GET | `/api/v1/routes/{codigo}` | — | Página de una ruta: trazado, estaciones en el orden del recorrido, horario por tipo de día y si opera ahora |
| GET | `/api/v1/routes/{codigo}/live?desde_lat=&desde_lon=&hasta_lat=&hasta_lon=` | — | Cuándo llega el próximo bus a la subida, en el sentido de la bajada, según los viajeros; sin observaciones, `minutos` es null |
| GET | `/api/v1/routes/{codigo}/stop-request?latitud=&longitud=` | — | Cómo se pide la parada en ese paradero según los viajeros; `como` es null sin 3 respuestas y una mayoría clara |
| POST | `/api/v1/stop-requests` | ✅ | «¿Cómo pediste la parada?» (`ruta`, `como`, punto del paradero). Anónimo; vence al año. Máx. 5 cada 10 min |
| POST | `/api/v1/sightings` | ✅ | «Vi pasar el T103» o qué tan lleno va (`ocupacion`). Anónimo: no guarda quién; vence a los 30 min. Máx. 20 cada 10 min |
| POST | `/api/v1/trips` | ✅ | Empezar a compartir dónde va el bus; devuelve un identificador aleatorio de viaje, sin relación con el viajero |
| PUT | `/api/v1/trips/{viaje}` | ✅ | Nueva posición del bus (y ocupación); 404 si el viaje venció (5 min sin posiciones). Máx. 40 cada 10 min |
| DELETE | `/api/v1/trips/{viaje}` | ✅ | Dejar de compartir; el viaje se borra en el acto |
| POST | `/api/v1/routes/risk` | — | Calcular el riesgo de una ruta a partir de sus puntos (lat/lon) |
| POST | `/api/v1/routes/suggest` | — | Formas de llegar entre dos puntos, con tramos GeoJSON, transbordo y riesgo. `criterio`: `rapida`, `segura` o `sin_transbordo`; `salida`: hora de salida (por defecto, ahora). Si a esa hora no opera ninguna ruta útil, `aviso` dice cuándo sale la primera |
| GET | `/api/v1/places/search?q=` | — | Buscar lugares de Cartagena (sin tildes, por prefijo de palabra) o una dirección («Calle 9 # 3-50»), que sale primero |
| GET | `/api/v1/places/reverse?lat=&lon=` | — | Nombre del punto elegido en el mapa |
| GET | `/api/v1/stops/nearby?lat=&lon=` | — | Estaciones cercanas, con sus rutas y la distancia a pie |
| GET | `/api/v1/users/me/places` | ✅ | Listar los lugares guardados |
| POST | `/api/v1/users/me/places` | ✅ | Guardar un lugar (409 si ya hay 10) |
| PATCH | `/api/v1/users/me/places/{id}` | ✅ | Editar nombre, ícono o ubicación de un lugar propio |
| DELETE | `/api/v1/users/me/places/{id}` | ✅ | Eliminar un lugar propio |

Documentación interactiva (Swagger): <http://127.0.0.1:8000/api/v1/docs>. Para probar los endpoints
con sesión, inicia sesión, copia el `access_token` y pégalo en el botón **Authorize**.

**Privacidad (Ley 1581 de 2012):**
- **Lo que no se guarda:** ningún documento del tiempo real guarda quién lo envió. Los avistamientos vencen a los 30 minutos y los viajes compartidos a los 5 minutos sin posiciones, con índices TTL. Las respuestas a «¿Cómo pediste la parada?» guardan solo el paradero y la respuesta, y vencen al año.
- **Historial:** no existe historial de ubicaciones de nadie.
- **Cuenta invisible:** solo se guarda la huella SHA-256 de su secreto. Las que no se usan en 180 días se borran solas.

## Pruebas

```bash
# Backend: las pruebas de integración necesitan MongoDB (docker compose up -d mongo)
cd backend
pytest

# Frontend
cd frontend
flutter analyze
flutter test
```

## Diseño

| Inicio | Reportar | Detalles del reporte | Perfil y nivel |
|---|---|---|---|
| ![Inicio: mapa con la troncal, los reportes cercanos y la hoja con «¿A dónde vas?»](docs/capturas/inicio.jpg) | ![Reportar: los nueve tipos ilustrados en tres grupos](docs/capturas/reportar.jpg) | ![Detalles: ruta T103 y 20 min de espera, «Reportar: el T103 no pasa»](docs/capturas/detalles.jpg) | ![Perfil: alias, nivel y reputación](docs/capturas/perfil.jpg) |

Capturas de la versión web con datos de demostración, en Estación Bazurto; las dos primeras en tema oscuro y las
otras dos en tema claro (la app sigue el tema del teléfono).

La app sigue el sistema de diseño «Bahía» (noche de bahía con verde agua, y su versión clara para el sol),
con mapa vectorial de estilo propio e ilustraciones para cada tipo de reporte:
[`DESIGN.md`](DESIGN.md) describe el sistema de diseño, [`PRODUCT.md`](PRODUCT.md) el contexto del producto y
[`docs/auditoria-diseno.md`](docs/auditoria-diseno.md) la auditoría de usabilidad que motivó el rediseño.
Los datos de rutas, estaciones, lugares y el mapa de fondo son © colaboradores de OpenStreetMap (ODbL);
las teselas vectoriales las sirve OpenFreeMap.

## Planes de producto

Más allá del curso:
- [Datos de trancones y tráfico](docs/plan-datos-de-trafico.md): por qué no Waze, y cómo combinar datos propios con un proveedor externo.
- [Cómo se sostiene Karta sin anuncios](docs/plan-sostenibilidad.md): costos, analítica agregada y lo que nunca se hará.
- [Karta como código abierto](docs/plan-codigo-abierto.md): licencias, titularidad, secretos y tiendas.

## Licencias

Código abierto, © 2026 Camilo Andres Maestre Iglesias:
- el servidor (`backend/`) bajo la **GNU AGPL 3.0 o posterior**;
- la app (`frontend/`) bajo la **Apache 2.0**;
- la documentación bajo **CC BY 4.0**.

Los datos de OpenStreetMap (ODbL) y de Datos Abiertos de Cartagena (CC BY 4.0) conservan su licencia. Detalles en [LICENSE.md](LICENSE.md); para aportar, [CONTRIBUTING.md](CONTRIBUTING.md).

## Convenciones

- Commits con [Conventional Commits](https://www.conventionalcommits.org/es/): `feat(incidents): ...`, `fix(routing): ...`.
- Los secretos van en `backend/.env`, que nunca se sube al repositorio; `backend/.env.example` documenta las variables.
