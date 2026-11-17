# Plan del piloto de Karta

El piloto de la fase 4 ([plan de reconstrucción](../plan-reconstruccion.md), §8): compañeros que usan Karta en sus viajes reales durante 4 o 5 días hábiles. La fase termina cuando «hay datos reales del piloto y no queda ningún error crítico abierto».

Lo acompañan:
- la [guía para participantes](guia-para-participantes.md), que es lo que se les envía;
- la [encuesta final](encuesta-final.md).

## 1. Qué se quiere saber

1. **Que Karta funciona en viajes reales:** planificar, empezar el viaje, los avisos de bajarse y llegar, sin errores críticos.
2. **Qué tan exacta es la hora de llegada** frente a la real y frente a Google Maps y Moovit (D17).
3. **Si la comunidad aporta datos:** viajes compartidos, reportes, confirmaciones y «Gracias» ([plan-comunidad](../plan-comunidad.md), §5).
4. **Cómo anda en teléfonos económicos:** fluidez y modo ligero (D13), batería y datos.
5. **Qué tan fácil es de usar:** la escala SUS y lo que cuentan los participantes.

## 2. Cuándo y con quiénes

- **Fechas:** del miércoles 18 al lunes 23 de noviembre de 2026, según el calendario. Puede empezar antes si la lista de la sección 3 está completa.
- **Participantes:** 10 a 15 compañeros, todos de **18 años o más**, que usen Transcaribe al menos tres días de la semana.
- **Teléfonos:** Android 7.0 o más reciente. Al menos dos deben ser económicos, de 3 GB de RAM o menos, para medir D13.
- **Cobertura:** que entre todos usen la troncal, varias alimentadoras y al menos un transbordo.
- **Equipo:**
  - Camilo es el responsable de los datos y quien decide.
  - José recluta y coordina a los participantes, si lo acepta.
  - Ambos atienden el grupo de soporte.

## 3. Antes de empezar

- [ ] **La política completa.** Correr `deploy/aws/desplegar.sh --responsable` con el correo, el teléfono, la dirección y la fecha de vigencia. Mientras la política diga «[por definir]», no se invita a nadie.
- [ ] **El APK del piloto**, firmado y con la dirección de la API ([despliegue](../despliegue-aws.md), «App»), con un número de versión nuevo.
- [ ] **Cómo se reparte el APK.** Opciones:
  - un *release* de GitHub marcado como prelanzamiento;
  - un enlace privado de Drive.

  Lo decide Camilo; el *release* es público.
- [ ] **Prueba de humo** en un teléfono limpio:
  1. instalar;
  2. aceptar el aviso;
  3. planificar y hacer un viaje corto en bus;
  4. reportar y confirmar un reporte desde otra cuenta;
  5. borrar la cuenta.
- [ ] **El grupo de soporte** (WhatsApp) con las reglas: no compartir ubicaciones ni capturas con datos de otros.
- [ ] **El tablero de errores:** una lista con cada error, quién lo vio, en qué teléfono y si es crítico (sección 6).
- [ ] **La encuesta final** creada sin pedir nombre ni correo. En Google Forms, desactivar «Recopilar direcciones de correo».

## 4. Qué hace cada participante

Está en la [guía](guia-para-participantes.md). En resumen:
- al menos **un viaje real al día** con «Empezar viaje», dejando prendido «Compartir dónde va el bus»;
- reportar lo que vea en el camino;
- confirmar o desmentir los reportes de otros;
- contar en el grupo cualquier error;
- responder la encuesta al final, en 5 minutos.

## 5. Cómo se mide

| Qué | Cómo | Dónde queda |
|---|---|---|
| Error de la hora de llegada de Karta | Automático: al llegar, la app compara lo estimado con lo real, en total y por bus | `python -m scripts.informe_de_precision --desde 2026-11-18` |
| Indicadores de comunidad | Automáticos: conteos diarios sin cuentas ni puntos | `python -m scripts.indicadores_del_piloto --desde 2026-11-18 --hasta 2026-11-23` |
| Karta frente a Google Maps y Moovit | Los 10 trayectos de la [primera comparación](../comparacion-apps.md), ahora **viajados de verdad** por el equipo. Al salir se anota lo que estima cada app; al llegar, la hora real | Una tabla nueva en `comparacion-apps.md` |
| A qué distancia suena el aviso de bajarse | En esos mismos viajes, cuántos paraderos o metros antes sonó el aviso de cada app | La misma tabla |
| Toques para empezar un viaje | Una tarea fija en las tres apps: de abrir la app a empezar el viaje hacia «Plaza de la Aduana» | La misma tabla |
| Batería y datos por hora de viaje | Ajustes de Android › Batería y › Uso de datos, por app, antes y después de una hora de viaje con cada una | La misma tabla |
| Fluidez en teléfonos económicos | Si apareció la oferta del modo ligero, y la pregunta de la encuesta | Encuesta y notas |
| Usabilidad | Escala SUS de la encuesta (0 a 100; el promedio de la industria ronda 68) | Encuesta |
| Errores | El grupo de soporte y los registros de la función (`aws logs tail /aws/lambda/karta-api --since 1d`) | Tablero de errores |

**Metas de comunidad:** las de [plan-comunidad](../plan-comunidad.md), §5. El script las muestra al lado de cada resultado.

**Meta de precisión (propuesta):** que 6 de cada 10 viajes lleguen a menos de 5 minutos de lo estimado. Aún no hay una medida de Google Maps ni de Moovit con viajes reales para compararla; los 10 trayectos viajados darán la primera.

**Ninguna cifra con menos de 10 casos.** Los dos scripts no la dan, y así los informes se pueden publicar en la entrega ([manual de datos](../legal/manual-de-datos-personales.md), «Estadísticas agregadas y anónimas»). Con 10 a 15 participantes, algunas cifras por ruta o por hora no saldrán: se informa el total.

## 6. Errores durante el piloto

- **Crítico:**
  - impide planificar, empezar o terminar un viaje;
  - la app se cierra;
  - un aviso de bajarse no suena;
  - se pierde o se expone un dato.

  Se corrige ese mismo día, se compila un APK nuevo y se avisa en el grupo.
- **Otro:** se anota y se corrige en la fase 5 o después de la entrega.
- **Incidente de datos:** se sigue el [manual](../legal/manual-de-datos-personales.md), sección 4.

## 7. Al terminar

1. Enviar la [encuesta](encuesta-final.md) el último día y cerrarla a los tres días.
2. Correr los dos scripts y guardar su Markdown en `docs/` con `--md`.
3. Una semana después del primer día, correr de nuevo `indicadores_del_piloto` para «vuelven la semana siguiente».
4. Escribir los resultados para la fase 5: qué se cumplió, qué no, qué se corrigió y qué queda.
5. Agradecer en el grupo con los resultados. Si se adoptó un nombre, también: «Gracias, karteños: con sus viajes…».
6. **Los participantes no tienen que hacer nada con sus datos.** Las cuentas sin correo se borran solas a los 180 días sin uso, y cada quien puede borrar la suya antes desde Perfil › Privacidad.
