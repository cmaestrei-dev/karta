# Lo que queda pendiente

**Estado:** inventario del 26 de octubre de 2026, al cerrar la parte de la fase 4 que no necesita viajeros.

**Decisión de Camilo (26 de octubre):** Karta se publica, y la prueba gente de afuera, **solo después de la respuesta de Transcaribe** a la petición. Los plazos vencen el 10 de noviembre (información) y el 18 (copias). Con los datos oficiales, la información de la app será más confiable. Hasta entonces se trabaja en lo que no depende de publicar.

Cada pendiente dice de qué depende:
- **Ya:** se puede hacer ahora.
- **Transcaribe:** espera su respuesta.
- **Viajeros:** necesita gente usando la app.
- **Camilo:** es una gestión suya.

## 1. Gestiones de Camilo

| Pendiente | Depende de | Por qué importa |
|---|---|---|
| **Crear un correo solo para Karta** y luego correr `deploy/aws/desplegar.sh --responsable` con el correo, el teléfono, la dirección y la fecha de vigencia | Camilo | Sin esos datos la política dice «[por definir]» y no se puede invitar a nadie. Se empezó el 26 de octubre y se canceló por falta del correo |
| Registrar el software en la DNDA (gratis, en línea) | Camilo | Prueba de autoría con fecha ([propiedad intelectual](propiedad-intelectual.md), §8) |
| Radicar la carta al Comité de Propiedad Intelectual de la UdeC | Camilo | Confirma que la universidad no reclama el software |
| Que José acepte el [acuerdo de contribución](acuerdo-de-contribucion.md) por sus aportes anteriores | Camilo y José | Sin él, esos aportes no se pueden relicenciar |
| Buscar la marca «Karta» en SIPI, antes del lanzamiento | Camilo | Hay un registro internacional «Karta» de Grab ([propiedad intelectual](propiedad-intelectual.md)) |
| Decidir cómo se reparte el APK: *release* de GitHub (público) o enlace privado | Camilo | Paso previo al piloto |
| Hacer seguimiento a las peticiones a Transcaribe y a la Alcaldía; si no responden de fondo, insistir y, en último caso, tutela | Transcaribe | Lo que pasa si no responden está en las [notas de la petición](legal/derecho-de-peticion-transcaribe-notas.md) |
| Más adelante: decidir si crear una S.A.S. | Camilo | Hace falta para facturar analítica y para que el responsable de los datos no sea una persona ([plan de datos y monetización](plan-datos-y-monetizacion.md)) |

## 2. Lo que se puede hacer ya, sin publicar

### Entrega del curso (fase 5)

La fase 5 pide la documentación final, los resultados del piloto, una presentación y un video demo. Casi todo se puede adelantar:
- **Diagramas UML** (`docs/diagramas`): son de la segunda entrega y les falta lo de las fases 1 a 4. Por ejemplo:
  - el viaje activo y su máquina de estados;
  - el tiempo real;
  - la cuenta invisible;
  - la política y el borrado de la cuenta;
  - el despliegue en AWS.
- **Modelo de datos y API:** las colecciones y los endpoints nuevos (`trip_results`, `daily_counts`, `/legal`, `/me/autorizacion`, `DELETE /me`, `/trip-results`).
- **DESIGN.md:** al día con «Bahía», el modo ligero y la accesibilidad.
- **Atributos de calidad:** el [plan de calidad](plan-calidad.md) sirve de base para esa sección de la entrega.
- **Falta una pregunta abierta del plan:** la fecha exacta de la entrega final y qué pide su plantilla.

### Calidad

Lo que salga del [plan de calidad](plan-calidad.md), sección «Qué hacer». Primero va lo que se debe resolver antes de publicar.

### Producto: brechas del estudio de reseñas (D21) que siguen abiertas

| Pendiente | Depende de |
|---|---|
| Consulta de un vistazo: una notificación o un widget con el próximo bus, para no sacar el celular en la calle | Ya |
| Planificar sin conexión, con las rutas, las estaciones y los lugares guardados en el teléfono | Ya |
| Reportar «ruta o paradero desactualizado» y publicar qué datos cambiaron | Ya |
| Publicar las reglas de moderación | Ya |

### Datos

| Pendiente | Depende de |
|---|---|
| **Rutas de Transcaribe que faltan:** la A118 (opera desde el 27 de octubre de 2025) y la extensión de la X106 hasta Turbaco en hora pico ([otros transportes](plan-otros-transportes.md), §0) | Transcaribe, o mapearla desde el bus |
| ~~**El mínimo de 10 por cifra cuenta viajes, no personas**~~ **Hecho el 27 de octubre:** cuenta personas distintas, y las horas de las subidas y de las respuestas de parada van redondeadas ([plan de datos](plan-datos-y-monetizacion.md), §6) | — |
| **Paraderos sin ubicar:** 724 de los 948 oficiales. Hoy hay 224; los demás llegan con la respuesta de Transcaribe o con «Marca este paradero» | Transcaribe o viajeros |
| **Esperas calibradas:** hoy son fijas (5, 8 y 10 minutos según el tipo de ruta). Mejoran con las frecuencias oficiales o con los avistamientos | Transcaribe o viajeros |
| **Velocidad de los buses por tramo** (fase A del [plan de datos de tráfico](plan-datos-de-trafico.md)): agregarla al recibir cada posición | Ya se puede construir; da datos con viajeros |
| **Otros transportes públicos:** busetas, lanchas, intermunicipales | [Plan de otros transportes](plan-otros-transportes.md) |

### Lo que falta probar en el teléfono

- La medición del viaje en un trayecto real en bus (el APK v6 ya está instalado).
- El modo ligero en un teléfono económico (D13).
- La letra grande en la pantalla del viaje, que la prueba automática no cubre.

### Deuda técnica

- **El campo `responsable` vacío de `/legal/politica`:** existe solo para las APK anteriores al 26 de octubre. Se quita cuando nadie use una de esas.

## 3. Lo que espera a publicar

| Pendiente | Depende de |
|---|---|
| El piloto: [plan](piloto/plan-del-piloto.md), [guía](piloto/guia-para-participantes.md) y [encuesta](piloto/encuesta-final.md) | Transcaribe, el correo de Karta y viajeros |
| Comparar con Google Maps y Moovit en viajes reales (D17) | Viajeros |
| Nombre de la comunidad, Guardianes y «Semana de los kartógrafos» ([plan-comunidad](plan-comunidad.md)) | Viajeros |
| Indicadores de comunidad y precisión de la llegada (los scripts ya están) | Viajeros |
| Google Play: cuenta de desarrollador (USD 25) y las pruebas cerradas que exige a las cuentas personales nuevas ([plan de código abierto](plan-codigo-abierto.md)) | Publicar |

## 4. Planes que vienen después

- **[Otros transportes públicos](plan-otros-transportes.md):** va primero, por decisión de Camilo.
- **Turistas:** después de los otros transportes. Se planea cuando Camilo lo retome.
- **[Datos y monetización](plan-datos-y-monetizacion.md):** cuánto guardar, qué vale y cómo venderlo sin vender datos personales.
- **Fuera de alcance por ahora:** iOS, la web y el saldo de la tarjeta (depende de los sistemas de Transcaribe). El transporte privado queda excluido.
