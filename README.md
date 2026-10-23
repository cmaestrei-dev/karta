# Karta — Sistema de enrutamiento de transporte público

Proyecto de aula de **Ingeniería de Servicios de Internet**, Universidad de Cartagena (2026-2).

Karta ayuda al viajero de Cartagena a moverse en Transcaribe con menos incertidumbre: busca su destino,
le sugiere cómo llegar (caminata + ruta + caminata) con el riesgo de cada opción y muestra en el mapa los
incidentes que reporta la comunidad (tráfico y seguridad). El alcance del prototipo es el área urbana de
Cartagena de Indias.

## Estado actual

| Funcionalidad | Estado |
|---|---|
| Registro e inicio de sesión (JWT, sesión guardada en almacenamiento seguro) | ✅ |
| Reportar incidente (Tráfico / Seguridad, intensidad 1–5, ubicación GPS) | ✅ requiere sesión |
| Ver los incidentes vigentes en el mapa | ✅ expiran solos (Tráfico 3 h, Seguridad 12 h) |
| Buscar un lugar de Cartagena o elegir el punto en el mapa | ✅ 453 lugares de OpenStreetMap |
| Rutas sugeridas de Transcaribe con su riesgo | ✅ 24 rutas y 17 estaciones de OpenStreetMap |
| Estaciones cercanas con sus rutas | ✅ |
| Lugares guardados (Casa, Trabajo…) | ✅ CRUD, máximo 10 por viajero |
| Validación de incidentes por la comunidad | ⏳ pendiente |
| Límite de frecuencia de peticiones (rate limiting) | ⏳ pendiente |

## Arquitectura

```
Flutter (BLoC) ──HTTP/JSON + Bearer JWT──▶ FastAPI ──PyMongo──▶ MongoDB
      │
      └──HTTPS──▶ teselas de OpenStreetMap (solo el mapa de fondo)
```

El backend sigue una arquitectura hexagonal (puertos y adaptadores):

| Carpeta | Contenido |
|---|---|
| `backend/src/domain` | Entidades, reglas de negocio (`trip_planning.py`, `route_risk.py`, `geo.py`), puertos (`ports.py`) y esquemas Pydantic de la API. No depende de FastAPI ni de MongoDB |
| `backend/src/application` | Casos de uso: `AuthService`, `IncidentService`, `PlaceService` (buscador y lugares guardados) y `TripService` (rutas sugeridas, estaciones cercanas) |
| `backend/data`, `backend/scripts` | Rutas, estaciones y lugares importados de OpenStreetMap (`importar_osm.py`); se cargan al arrancar la API |
| `backend/src/infrastructure` | Adaptadores: FastAPI y routers, repositorios MongoDB, Argon2 + JWT, configuración |
| `frontend/lib/core` | Configuración y servicios compartidos (URL de la API, GPS, errores de la API) |
| `frontend/lib/features/<funcionalidad>` | `data` (repositorios HTTP), `domain` (modelos), `presentation` (BLoC y pantallas) |

### Modelo de datos (MongoDB)

| Colección | Documento | Índices |
|---|---|---|
| `users` | `email`, `password_hash` (Argon2id), `nombre`, `tipo_viajero`, `reputacion`, `terminos_aceptados_en`, `creado_en`, `lugares_guardados` (embebidos, máx. 10) | único en `email` |
| `incidents` | `reportado_por` (ObjectId), `categoria`, `intensidad`, `ubicacion` (GeoJSON Point), `creado_en`, `expira_en` | `2dsphere` en `ubicacion`; TTL en `expira_en` |
| `places` | `nombre`, `tipo`, `ubicacion` (Point), `tokens` (palabras normalizadas) | `2dsphere`; `tokens` |
| `stations` | `nombre`, `ubicacion` (Point), `rutas` | `2dsphere` |
| `transit_routes` | `nombre`, `tipo`, `desde`, `hasta`, `geometria` (LineString) | `2dsphere` en `geometria` |

El riesgo de una ruta se calcula trazando un corredor de 500 m alrededor de la polilínea
(en UTM 18N, EPSG:32618, para medir en metros) y consultándolo con `$geoWithin` sobre el índice `2dsphere`.
Las rutas sugeridas parten de las rutas que pasan a menos de 800 m del origen y del destino (`$geoIntersects`),
eligen la mejor subida y bajada en cada una y se ordenan por tiempo más una penalización por riesgo.

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
| POST | `/api/v1/auth/register` | — | Registrar un viajero (exige `acepta_terminos: true`); devuelve el token |
| POST | `/api/v1/auth/login` | — | Iniciar sesión; devuelve un token Bearer (JWT) |
| GET | `/api/v1/users/me` | ✅ | Perfil del viajero autenticado |
| POST | `/api/v1/incidents/` | ✅ | Reportar un incidente (el autor sale del token) |
| GET | `/api/v1/incidents/` | — | Listar los incidentes vigentes (sin datos del autor) |
| POST | `/api/v1/routes/risk` | — | Calcular el riesgo de una ruta a partir de sus puntos (lat/lon) |
| POST | `/api/v1/routes/suggest` | — | Rutas sugeridas de Transcaribe entre dos puntos, con tramos GeoJSON y riesgo |
| GET | `/api/v1/places/search?q=` | — | Buscar lugares de Cartagena (sin tildes, por prefijo de palabra) |
| GET | `/api/v1/places/reverse?lat=&lon=` | — | Nombre del punto elegido en el mapa |
| GET | `/api/v1/stops/nearby?lat=&lon=` | — | Estaciones cercanas, con sus rutas y la distancia a pie |
| GET | `/api/v1/users/me/places` | ✅ | Listar los lugares guardados |
| POST | `/api/v1/users/me/places` | ✅ | Guardar un lugar (409 si ya hay 10) |
| PATCH | `/api/v1/users/me/places/{id}` | ✅ | Editar nombre, ícono o ubicación de un lugar propio |
| DELETE | `/api/v1/users/me/places/{id}` | ✅ | Eliminar un lugar propio |

Documentación interactiva (Swagger): <http://127.0.0.1:8000/api/v1/docs>. Para probar los endpoints
con sesión, inicia sesión, copia el `access_token` y pégalo en el botón **Authorize**.

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

| Inicio | Buscar | Cómo llegar | Recorrido |
|---|---|---|---|
| ![Inicio](docs/capturas/inicio.jpg) | ![Buscar](docs/capturas/buscar.jpg) | ![Cómo llegar](docs/capturas/como-llegar.jpg) | ![Recorrido](docs/capturas/detalle-ruta.jpg) |

La app sigue la dirección visual «Cal y azulejo» (placas de nombres de calle del Centro Histórico):
[`DESIGN.md`](DESIGN.md) describe el sistema de diseño, [`PRODUCT.md`](PRODUCT.md) el contexto del producto y
[`docs/auditoria-diseno.md`](docs/auditoria-diseno.md) la auditoría de usabilidad que motivó el rediseño.
Los datos de rutas, estaciones, lugares y el mapa de fondo son © colaboradores de OpenStreetMap (ODbL).

## Convenciones

- Commits con [Conventional Commits](https://www.conventionalcommits.org/es/): `feat(incidents): ...`, `fix(routing): ...`.
- Los secretos van en `backend/.env`, que nunca se sube al repositorio; `backend/.env.example` documenta las variables.
