# Plan: datos de trancones y tráfico

**Estado:** propuesta, 24 de octubre de 2026.

**Alcance:** la fase A cabe en el proyecto del curso; las fases B y C quedan para después de la entrega final.

## 1. Qué se busca

Saber dónde hay trancones que afectan a los buses, para dos cosas:
- que la llegada estimada sea mejor que la de cualquier otra app;
- avisarle al viajero antes de que se monte en un bus que va a quedar atascado.

Al pasajero no le sirve saber cómo va el tráfico de los carros. Le sirve saber cómo va su bus.

## 2. Opciones evaluadas

| Fuente | Costo | ¿Karta puede usarla? | Comentario |
|---|---|---|---|
| **Waze** | Gratis con Waze for Cities | **No directamente.** [Waze for Cities](https://support.google.com/waze/partners/answer/10453062?hl=en) acepta entidades públicas, operadores viales y organizadores de eventos; una app privada no califica | No hay una API pública para apps. Leer su mapa en vivo de forma automática viola sus términos. |
| **TomTom Traffic** | [Plan gratis](https://frontdeskreview.com/software/maps-api/tomtom/): 2.500 consultas y 50.000 teselas al día, con uso comercial permitido | Sí | Cambió precios el 1 de julio de 2026: hay que confirmar las condiciones vigentes antes de usarlo. |
| **Google Maps Platform** (rutas con tráfico) | Pago por consulta, con un cupo gratis mensual por producto | Sí | Es más caro a escala y lo cobra por cada ruta calculada. |
| **Datos propios de Karta** | Gratis | Sí | Es lo único que nadie más tiene, pero necesita viajeros compartiendo. |

## 3. Decisión: híbrido, con datos propios desde el primer día

### Fase A · Velocidad de los buses (ya se puede)

Los viajes compartidos (fase 3) mandan la posición del bus cada ~30 s. De ahí sale la velocidad real por tramo:
- **Tramos de ~500 m** sobre cada ruta.
- **Velocidad en ventanas de 15 minutos**, comparada con la velocidad típica de ese tramo a esa hora.
- **Un tramo «lento»** (por debajo del 50 % de lo típico) aparece en el mapa y en la llegada estimada: «el T103 va lento entre Bazurto y La Popa».

Se suman los reportes de la comunidad de «vía bloqueada» y «trancón», con su vigencia y sus votos.

**Privacidad:** solo se guardan los agregados por tramo y ventana, nunca los viajes. Las posiciones siguen venciendo a los 5 minutos.

### Fase B · Complemento externo mientras hay pocos usuarios

En los tramos sin viajes compartidos recientes se consulta TomTom Traffic Flow:
- **A demanda:** solo los tramos de los viajes que alguien está planificando, no la ciudad entera.
- **Con caché de 10 minutos por tramo** y una alarma al llegar a 2.000 consultas en el día, para no salirse del plan gratis.
- **Con la atribución de TomTom visible** donde se muestre su dato.

Se apaga ruta por ruta cuando los datos propios alcanzan (sección 4).

### Fase C · Alianza con una entidad pública

Una entidad que sí puede entrar a Waze for Cities (el DATT, Transcaribe, la Alcaldía o la universidad) se asocia con Karta:
- **Intercambio:** la entidad recibe los agregados de Karta (velocidad de buses, ocupación, desvíos), que también son el producto de analítica del [plan de sostenibilidad](plan-sostenibilidad.md). Karta recibe acceso a datos de tráfico de la ciudad.
- **Antes de mostrar en Karta cualquier dato de Waze**, hay que revisar sus términos de uso: el programa está pensado para la gestión pública del tráfico, no para redistribuirlo en otra app.

## 4. Cuándo se apaga lo externo

**Cobertura** = porcentaje de las ventanas de 15 minutos en hora pico (6–9 a. m. y 5–8 p. m.) en las que un tramo tiene al menos 3 posiciones de buses compartidos.

| Cobertura de la ruta | Fuente |
|---|---|
| Menos del 40 % | Karta + TomTom |
| 40 a 70 % | Karta, y TomTom solo en los tramos sin datos |
| Más del 70 % durante dos semanas | Solo Karta |

## 5. Riesgos

| Riesgo | Mitigación |
|---|---|
| Pocos viajeros comparten al principio | Compartir viene activado por defecto (D3); fase B como respaldo; piloto en la fase 4. |
| Un bus detenido en una estación parece un trancón | Se descartan las posiciones a menos de 60 m de una estación o paradero conocido. |
| TomTom cambia precios o condiciones | Caché, consultas a demanda y la posibilidad de apagarlo; el núcleo nunca depende de un tercero. |
| Velocidades falsas enviadas a propósito | Se cruzan con la ruta (deben estar sobre ella), límite de envíos por cuenta y peso por reputación (fase 3b). |

## Fuentes

- [Apply for Waze for Cities — Waze Partners Help](https://support.google.com/waze/partners/answer/10453062?hl=en)
- [Waze for Cities](https://www.waze.com/wazeforcities/)
- [TomTom pricing (revisado el 2 de septiembre de 2026)](https://frontdeskreview.com/software/maps-api/tomtom/)
