# Karta — Sistema de enrutamiento de transporte público

Proyecto de aula de **Ingeniería de Servicios de Internet**, Universidad de Cartagena (2026-2).

Karta ayuda al viajero de Cartagena a moverse con menos incertidumbre: muestra en un mapa los
incidentes que reporta la comunidad (tráfico y seguridad) y evalúa el riesgo de una ruta antes de tomarla.
El alcance del prototipo es el área urbana de Cartagena de Indias.

## Estado actual

| Funcionalidad | Estado |
|---|---|
| Reportar incidente (Tráfico / Seguridad, intensidad 1–5, ubicación GPS) | ✅ |
| Ver los incidentes en el mapa | ✅ |
| Trazar una ruta desde la ubicación actual (OSRM) | ✅ destino fijo de prueba: Bocagrande |
| Escanear el riesgo de la ruta | ✅ |
| Registro e inicio de sesión | ⏳ pendiente — la app reporta como `id_usuario=1` |
| Validación de incidentes por la comunidad | ⏳ pendiente |
| Migración a MongoDB | ⏳ pendiente — hoy usa PostgreSQL + PostGIS |

## Arquitectura

```
Flutter (BLoC) ──HTTP/JSON──▶ FastAPI ──SQLAlchemy + GeoAlchemy2──▶ PostgreSQL + PostGIS
      │
      └──HTTP──▶ OSRM (servidor público de rutas)
```

| Carpeta | Contenido |
|---|---|
| `backend/src/domain` | Esquemas Pydantic: contratos y validación de la API |
| `backend/src/application` | Servicios con la lógica de negocio |
| `backend/src/infrastructure` | FastAPI, routers, modelos ORM, conexión a la BD y scripts de arranque |
| `frontend/lib/core` | Configuración y servicios compartidos (URL de la API, GPS) |
| `frontend/lib/features/<funcionalidad>` | `data` (repositorios HTTP), `domain` (modelos), `presentation` (BLoC y pantallas) |

## Puesta en marcha

### Opción A: Docker (recomendada)

Requiere Docker Desktop, o Docker Engine con Compose. Desde la raíz del repositorio:

```bash
docker compose up --build
```

- API: <http://localhost:8000> (redirige a Swagger, en `/api/v1/docs`)
- PostgreSQL: `localhost:5433` — usuario, clave y base: `karta` / `karta` / `karta_db`

Al arrancar, la API crea las tablas y carga los datos semilla (modalidades y el usuario de
desarrollo `id_usuario=1`); ambos pasos son idempotentes. Los cambios en `backend/src` recargan la API solos.

### Opción B: instalación local

Requiere Python 3.12 y PostgreSQL con la extensión PostGIS.

1. Crea la base de datos y habilita PostGIS (sin esto no se pueden crear las tablas):

   ```sql
   CREATE DATABASE karta_db;
   \c karta_db
   CREATE EXTENSION postgis;
   ```

2. Desde la carpeta `backend/` (los imports parten de `src.`, así que los comandos deben correr ahí):

   ```bash
   python -m venv .venv
   source .venv/bin/activate          # Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   cp .env.example .env               # Windows: copy .env.example .env — luego ajusta DATABASE_URL
   python -m src.infrastructure.init_db
   python -m src.infrastructure.seed
   uvicorn src.infrastructure.main:app --reload
   ```

### App Flutter

Desde la carpeta `frontend/`:

```bash
flutter pub get
flutter run -d chrome     # la forma más rápida de probar
flutter run -d linux      # escritorio Linux
```

La URL de la API se define con `--dart-define`; por defecto es `http://127.0.0.1:8000/api/v1`.

| Dónde corre la app | Cómo ejecutarla |
|---|---|
| Chrome o escritorio, en el mismo equipo que la API | `flutter run` sin parámetros extra |
| Emulador de Android | `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1` |
| Celular físico en la misma red Wi-Fi | `flutter run --dart-define=API_BASE_URL=http://<IP-de-tu-PC>:8000/api/v1`, con uvicorn arrancado con `--host 0.0.0.0` |

En modo debug, si el GPS no responde en 5 segundos (común en Linux de escritorio), la app usa una
coordenada de respaldo en Cartagena y lo avisa. En release nunca inventa la ubicación.

## Endpoints

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/v1/health` | Estado del servicio |
| POST | `/api/v1/users/` | Registrar un viajero (`tipo_viajero`: `Residente` o `Turista`) |
| POST | `/api/v1/incidents/` | Reportar un incidente |
| GET | `/api/v1/incidents/` | Listar los incidentes |
| POST | `/api/v1/routes/risk` | Calcular el riesgo de una ruta a partir de sus puntos (lat/lon) |

Documentación interactiva (Swagger): <http://127.0.0.1:8000/api/v1/docs>

## Pruebas

```bash
cd frontend
flutter analyze
flutter test
```

## Convenciones

- Commits con [Conventional Commits](https://www.conventionalcommits.org/es/): `feat(incidents): ...`, `fix(routing): ...`.
- Los secretos van en `backend/.env`, que nunca se sube al repositorio; `backend/.env.example` documenta las variables.
