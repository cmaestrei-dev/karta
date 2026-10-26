# Manual interno de datos personales de Karta

Lo que exige la Ley 1581 de 2012 (art. 17 k) y el principio de responsabilidad demostrada (Decreto 1074 de 2015, arts. 2.2.2.25.6.1 y 2.2.2.25.6.2), en proporción a un proyecto pequeño. Acompaña a la [política de tratamiento](../../backend/data/legal/politica-de-tratamiento.md), que es lo que ven los viajeros.

- **Normas revisadas el 26 de octubre de 2026:**
  - la Ley 1581 y el Decreto 1074 no han cambiado;
  - la reforma de 2025 (PLE 214 y 274 de 2025 Cámara) se archivó;
  - el PLE 282 de 2026 Cámara está en su primer trámite.
- **Responsable:** Camilo Andrés Maestre Iglesias, persona natural. Sus datos de contacto están en la configuración del servidor, no en este repositorio público (sección 6).
- **Registro Nacional de Bases de Datos:** no aplica, porque solo deben inscribirse sociedades y entidades sin ánimo de lucro con activos de más de 100.000 UVT, y las entidades públicas (Decreto 090 de 2018). Aun así, sí aplican la política, la autorización, la atención de solicitudes y el reporte de incidentes.

## 1. Inventario

Todas las bases están en MongoDB Atlas (AWS us-east-1). Los encargados son MongoDB, Inc. y Amazon Web Services, Inc.

| Colección | Datos personales | Finalidad | Plazo |
|---|---|---|---|
| `users` | Cuenta invisible (huella del secreto del teléfono) o cuenta con correo (correo, nombre, alias, tipo de viajero, hash argon2 de la contraseña); reputación; impacto; lugares guardados (nombre y punto); `autorizaciones` (versión de la política y fecha) | Identificar la cuenta, reputación, lugares frecuentes, prueba de la autorización | Invisible: 180 días sin uso (índice TTL). Con correo: hasta que se borre. Siempre se puede borrar desde la app |
| `incidents` | Tipo, detalles, punto, hora, id de quien reportó, nivel y alias | Avisar a la comunidad; reputación | 30 min a 12 h según el tipo (TTL) |
| `incident_votes`, `incident_thanks`, `incident_views` | Id del viajero e id del reporte | Una persona, un voto; «Tu impacto» | 2 días (TTL) |
| `stop_marks` | Paradero, punto, id de quien marcó y de quienes votaron | Mapa comunitario de paraderos; reputación | Sin plazo, porque la ubicación del paradero es dato comunitario. El vínculo con la cuenta se borra al borrarla |
| `boardings` | Ruta, punto, hora y módulo, sin cuenta | Ubicar paraderos y lados de las estaciones | 180 días (TTL) |
| `sightings` | Ruta, punto, hora y ocupación, sin cuenta | Tiempo real | 30 min (TTL) |
| `live_trips` | Código al azar, ruta, posición y ocupación, sin cuenta | Tiempo real | 5 min después de la última posición (TTL) |
| `stop_answers` | Ruta, punto y respuesta, sin cuenta | Base de conocimiento de cómo pedir la parada | 1 año (TTL) |
| `rate_limits` | IP o id del viajero, más un contador | Evitar abusos | La ventana: 1 min a 1 h (TTL) |
| Registros de AWS Lambda (CloudWatch) | Datos técnicos de peticiones que fallaron | Corregir errores | 7 días (retención del grupo) |

**No se guardan:**
- los puntos de partida y de destino de las consultas;
- el recorrido de las caminatas;
- ningún historial de ubicación.

**Aunque no lleven cuenta, se tratan como datos personales** los viajes compartidos, los avistamientos, los puntos de subida y las respuestas de parada. Al recogerse llegan con la IP, y la ley colombiana no define la anonimización. Por eso están en la política, con su plazo.

### Estadísticas agregadas y anónimas

Son la base de la analítica para entidades del [plan de sostenibilidad](../plan-sostenibilidad.md) (§3.1). Pueden publicarse, compartirse o venderse.

- **Por qué se pueden vender:**
  - Una estadística que no puede asociarse a ninguna persona no es un dato personal (Ley 1581, art. 3 c), así que lo que se entrega queda fuera de la ley.
  - Calcularla, en cambio, sí es tratar datos personales. Por eso es una finalidad declarada en la política desde la versión 1.1 y el viajero la acepta en el aviso (art. 4 b; Decreto 1074, art. 2.2.2.25.2.2).
  - Vender los datos mismos, o cualquier tabla con una fila por viaje, por reporte o por cuenta, sigue prohibido por la política.
- **Reglas de cada tabla que salga de la base:**
  - Solo conteos, promedios o percentiles por celda: ruta, estación o tramo, franja de al menos 15 minutos y tipo de día.
  - Cada celda reúne al menos **10 viajes o reportes distintos**: códigos de viaje distintos para el tiempo real, cuentas distintas para los reportes. Las celdas con menos se suprimen, no se redondean.
  - Nunca salen cuentas, correos, alias, IP, códigos de viaje ni la secuencia de puntos de un mismo viaje (recorridos).
  - No se cruzan con otras fuentes que permitan reidentificar, ni se calculan para un grupo tan pequeño que señale a alguien (por ejemplo, un paradero con un solo usuario).
- **Cuándo:** antes de que el TTL borre los datos de origen. Las tablas resultantes se conservan sin plazo.
- **A quién se entregan:** con un acuerdo que prohíba intentar reidentificar a alguien y entregar la tabla a terceros sin estas reglas.

## 2. Autorización y su prueba

- **Al abrir la app por primera vez,** el aviso de privacidad se muestra antes de crear la cuenta o de pedir la ubicación (`frontend/lib/features/legal/presentation/aviso_de_privacidad.dart`).
  - Para aceptar hay que marcar «Tengo 18 años o más» y tocar «Acepto y continuar».
  - Es un acto afirmativo: no hay casillas premarcadas ni aceptación por seguir usando la app (C-748 de 2011).
- **La prueba:** al existir la cuenta, la app envía `POST /api/v1/users/me/autorizacion` y el servidor guarda en `users.autorizaciones` la versión y la fecha (art. 2.2.2.25.2.5).
- **Compartir el bus** tiene su propio aviso antes del primer viaje en bus.
- **La ubicación** se pide con el permiso del sistema y se puede negar.
- **Si cambia la política:**
  1. Cambiar `VERSION_POLITICA` en `backend/src/domain/politica.py` y la fecha `POLITICA_VIGENTE_DESDE`.
  2. Guardar la versión anterior en el historial de git.
  3. Desplegar: la app vuelve a mostrar el aviso a todos antes de seguir.

  Si cambia una finalidad, eso es una nueva autorización (art. 2.2.2.25.2.2).

  **Historial:**
  - 1.0: primera versión.
  - 1.1 (26 de octubre de 2026): se agregó la finalidad de las estadísticas agregadas y anónimas, que pueden venderse.

## 3. Atención de consultas y reclamos

Las atiende el responsable, por el correo de la política.

1. **Registrar** cada solicitud en una hoja privada, fuera del repositorio, con:
   - la fecha de recibo;
   - quién la hace y qué pide;
   - el vencimiento: consulta, 10 días hábiles (+5 con aviso); reclamo, 15 días hábiles (+8 con aviso);
   - la respuesta y su fecha.
2. **Verificar la identidad:**
   - Cuenta con correo: la solicitud debe venir desde ese correo.
   - Cuenta invisible: no tiene dato que la identifique. Se responde que se ejerce desde la app, en ese teléfono (Perfil › Privacidad), y que no hay otra forma segura.
   - Representantes de menores o apoderados: documento que lo acredite.
3. **Resolver:**
   - Conocer los datos: se consulta la cuenta en Atlas por su correo.
   - Corregirlos o borrarlos: con la misma regla de `DELETE /api/v1/users/me`, que borra la cuenta y lo que la identifica y desliga lo comunitario.
4. **Reclamo incompleto:** se pide lo que falta dentro de los 5 días siguientes, contados como días calendario por prudencia. Si en 2 meses no llega, se entiende desistido.
5. **Reclamo en trámite:** marcarlo así en la hoja dentro de los 2 días hábiles.

## 4. Incidentes de seguridad

Un incidente es, por ejemplo, una llave de AWS o la contraseña de Atlas filtradas, o un acceso indebido a la base.

1. **Contener:**
   - Desactivar la llave (IAM).
   - Cambiar la contraseña de `karta-api` en Atlas y actualizar la función con `deploy/aws/desplegar.sh --cambiar-base`.
   - Si hace falta, cerrar la Function URL.
2. **Evaluar:** qué datos, cuántas personas y desde cuándo.
3. **Reportar a la SIC** en su aplicativo de incidentes dentro de los **15 días hábiles** siguientes a conocerlo (Circular Única, Título V, numeral 2.1 f(ii)).
4. **Avisar a las personas afectadas** cuando el incidente pueda perjudicarlas: aviso en la app o publicación.
5. **Anotar** el incidente, la causa y lo que se cambió.

## 5. Riesgos y cómo se mitigan

| Riesgo | Mitigación |
|---|---|
| Los lugares guardados revelan dónde vive alguien | Solo los ve su dueño (`/users/me/places` exige sesión); se borran con la cuenta |
| Reidentificar a alguien por sus viajes | Solo el tramo en bus, con código al azar, sin cuenta, 5 minutos y sin historial |
| El alias en los reportes identifica a alguien | Solo primer nombre e inicial; sin cuenta, «Viajero sin cuenta»; se informa en la política |
| Una IP en los límites de peticiones | Ventanas de 1 min a 1 h, borradas por TTL |
| Llaves y secretos | Mínimo privilegio en IAM (política `karta-despliegue`); secretos solo en la configuración de Lambda; Atlas con usuario limitado a la base `karta` y TLS |
| Atlas abierto a cualquier IP (Lambda no tiene IP fija) | Contraseña larga generada por Atlas, TLS obligatorio, usuario sin otros permisos |
| Reidentificar a alguien con las estadísticas que se venden o publican | Mínimo 10 viajes o reportes distintos por celda; nada de recorridos, códigos ni cuentas; acuerdo con quien las recibe (sección 1) |
| Uso por menores | El aviso pide confirmar 18 años o más durante el piloto; si se detecta un menor, se borran sus datos |

## 6. Encargados y transmisión internacional

- **Quiénes:** Amazon Web Services, Inc. (Lambda, CloudWatch, EventBridge) y MongoDB, Inc. (Atlas), en Virginia, Estados Unidos.
- **Su papel:** son encargados, así que esto es transmisión, no transferencia.
- **Estados Unidos** está en la lista de países con nivel adecuado de la SIC (Circular Única, Título V, numeral 3.2, versión del 9 de enero de 2026).
- **Los contratos:**
  - el [DPA de AWS](https://d1.awsstatic.com/legal/aws-gdpr/AWS_GDPR_DPA.pdf) se incorpora a los términos del servicio;
  - el [DPA de MongoDB](https://www.mongodb.com/legal/data-processing-agreement) se incorpora a los términos de Atlas.

  Ambos exigen tratar los datos solo por instrucciones, con seguridad y confidencialidad (art. 2.2.2.25.5.2). Anotar en la hoja privada la fecha en que se aceptaron, que es la de creación de cada cuenta.
- **OpenFreeMap (Hungría)** sirve las imágenes del mapa directamente al teléfono. Se informa en la política.
- **Datos del responsable en la política.** El servidor los toma de la configuración de la función `karta-api`:
  - `RESPONSABLE_CORREO`, `RESPONSABLE_TELEFONO` y `RESPONSABLE_DIRECCION`;
  - `POLITICA_VIGENTE_DESDE`.

  Mientras falten, la política dice «[por definir]» y no se debe invitar a nadie al piloto.

## 7. Revisión

Cada año, o antes si cambia la app o la norma:
- revisar el inventario;
- revisar los plazos;
- revisar la política;
- revisar los permisos de AWS y Atlas;
- buscar cambios en la ley (el PLE 282 de 2026 Cámara y las circulares de la SIC).

## Fuentes

- [Ley 1581 de 2012](http://www.secretariasenado.gov.co/senado/basedoc/ley_1581_2012.html) y [Decreto 1074 de 2015](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=76608), Capítulo 25.
- [Circular Única de la SIC, Título V (9 de enero de 2026)](https://sedeelectronica.sic.gov.co/transparencia/normativa/titulo-v-actualizado-el-9-de-enero-de-2026).
- [Decreto 090 de 2018](https://www.alcaldiabogota.gov.co/sisjur/normas/Norma1.jsp?dt=S&i=74862) (RNBD).
- [Corte Constitucional, C-748 de 2011](https://www.corteconstitucional.gov.co/relatoria/2011/C-748-11.htm) y [T-294 de 2023](https://www.corteconstitucional.gov.co/Relatoria/2023/T-294-23.htm).
- [Guía de responsabilidad demostrada de la SIC](https://www.sic.gov.co/sites/default/files/files/Publicaciones/Guia-Accountability.pdf) y [guía de gestión de incidentes](https://www.sic.gov.co/sites/default/files/files/Publicaciones/Guia_gestion_incidentes_dic21_2020.pdf).
