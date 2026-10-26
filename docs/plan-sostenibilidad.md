# Plan: cómo se sostiene Karta sin anuncios

**Estado:** propuesta, 24 de octubre de 2026.

**Alcance:** después de la entrega final del curso. Lo único que se hace antes es no cerrar puertas, por ejemplo escribir desde ya la finalidad de los datos en la política (sección 5).

## 1. Principios

- **Sin anuncios.** Es una de las razones para dejar Moovit y pasarse a Karta.
- **Nunca vender ubicaciones ni trayectorias de personas.** Solo se venden agregados anónimos, explicados en la política de datos.
- **Nada básico ni de seguridad detrás de un pago:** planificar, viajar con avisos, ver las llegadas y reportar son gratis siempre.
- **Sin transporte privado:** ni integraciones ni comisiones de apps de taxi o de viajes en carro particular.

## 2. Cuánto cuesta

Cifras de orden de magnitud, que se verifican antes de cada etapa:

| Etapa | Usuarios | Infraestructura | Costo aproximado |
|---|---|---|---|
| Piloto (fase 4) | Decenas | MongoDB Atlas M0 (512 MB, gratis), la API en AWS Lambda con su Function URL (capa siempre gratuita) y teselas de OpenFreeMap | **USD 0** al mes; tras un arranque en frío, la primera petición tarda unos segundos más |
| Ciudad | Algunos miles | Un servidor pequeño siempre encendido y una base de datos pagada (o MongoDB en el mismo servidor) | **USD 20–80** al mes |
| Tiendas | — | Google Play: pago único de USD 25. Apple: USD 99 al año. Dominio: ~USD 15 al año | Pagos fijos |

Lo más costoso a escala no es el servidor, sino el tiempo de quien mantiene la app.

## 3. Fuentes de ingreso, en orden de prioridad

### 3.1 Analítica agregada para entidades (la principal)

Para Transcaribe, el DATT, la Alcaldía y la academia. Los productos posibles:
- **Confiabilidad:** la espera real frente a la programada, por ruta y hora.
- **Ocupación por franja:** «el T103 va muy lleno entre 6:30 y 7:30 a. m. desde Los Ejecutivos».
- **Buses en racimo:** dos o tres buses de la misma ruta seguidos y luego un hueco largo.
- **Desvíos frecuentes** y zonas con más incidentes, por tipo.
- **Tramos lentos** ([plan de datos de tráfico](plan-datos-de-trafico.md)).

Cómo se hace:
- **Agregación con umbral mínimo:** ninguna celda (ruta × tramo × franja) con menos de 10 viajes distintos. Nunca trayectorias.
- **El primer cliente, gratis a cambio de datos:** por ejemplo, un piloto con Transcaribe a cambio de las coordenadas oficiales de los paraderos. Ese piloto sirve de caso de éxito.
- **Riesgo:** las compras públicas son lentas. Por eso conviene empezar con un convenio académico o de innovación.

### 3.2 Convocatorias y apoyo institucional

Para pagar la infraestructura del primer año: la propia universidad, la Alcaldía y las convocatorias nacionales de innovación y emprendimiento. Hay que revisar las vigentes en su momento.

### 3.3 Cosméticos a la venta (más adelante)

Marcos y temas del avatar vendidos dentro de la app (con Google Play Billing, que cobra comisión):
- **Los que se ganan siguen siendo gratis:** los marcos por nivel y las insignias (D10).
- **Los de pago se ven claramente distintos de los de nivel.** El marco por nivel le dice a los demás qué tan confiable es quien reporta; uno comprado no puede imitarlo.

### 3.4 Karta Plus, sin anuncios

Para quien usa mucho la app:
- alertas proactivas de las rutas frecuentes («tu T103 de las 7:00 viene lleno»);
- historial de viajes guardado en la cuenta;
- más lugares guardados.

Nunca seguridad, avisos de bajada ni llegadas.

### 3.5 Aportes voluntarios

Un «Apoya a Karta» en el perfil. Antes hay que revisar qué permite la política de pagos de cada tienda.

## 4. Qué hace falta para cobrar

- **Una persona jurídica:** para facturarle a una entidad hace falta una empresa (en Colombia, una SAS puede tener un solo socio) o canalizarlo por la universidad (extensión o consultoría).
- **Política de tratamiento de datos (Ley 1581)** publicada, con la finalidad de la analítica agregada escrita **antes** de recolectar los datos que se van a usar.
- **Registro Nacional de Bases de Datos (SIC):** según el Decreto 090 de 2018, es obligatorio para sociedades con activos superiores a 100.000 UVT. Una empresa pequeña no está obligada, pero sí a todo lo demás de la Ley 1581.

## 5. Qué se hace desde ya (sin cobrar)

- **Escribir en la política de datos de la fase 4** que los datos de viajes se usan, agregados y anónimos, para mejorar el servicio y producir estadísticas de movilidad. Así no hay que volver a pedir autorización después.
- **Medir desde el piloto** lo que más adelante sería el producto de analítica: espera real frente a la programada, ocupación y desvíos.
- **Mantener el costo en USD 0** hasta tener la primera fuente de ingreso.

## 6. Lo que no se hará

| No | Por qué |
|---|---|
| Anuncios | Es la razón para preferir Karta sobre Moovit. |
| Vender ubicaciones individuales o trayectorias | Riesgo legal (Ley 1581) y la pérdida de la confianza, que es lo que hace funcionar el tiempo real comunitario. |
| Comisiones de transporte privado | Karta es para el transporte público. |
| Cobrar por avisos de seguridad o de bajada | Son el núcleo del producto. |
