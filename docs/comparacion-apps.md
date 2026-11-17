# Comparación de rutas: Karta, Google Maps y Moovit

Primera comparación de D17, hecha el 25 de octubre de 2026 en el teléfono de Camilo (POCO X7 Pro).

## Cómo se hizo

- **Trayectos:** 10 trayectos típicos entre lugares conocidos, no entre ubicaciones de personas. Cubren la troncal, alimentadoras con transbordo, Santa Lucía, Bocagrande, el aeropuerto y destinos lejos de toda ruta.
- **Hora:** salida el lunes 26 de octubre a las 8:00 a. m. en las tres apps.
- **Cómo se consultó cada app:**
  - Google Maps y Moovit, con el uso normal de cada app: origen y destino por enlace, la hora en su selector y la lectura de lo que muestran en pantalla.
  - Karta, con su API local y los datos de hoy.
- **Qué se anota:** la opción que llega primero saliendo a las 8:00, sus rutas y los minutos a pie. No se copió ningún dato de las otras apps.
- **Ningún tiempo es la realidad:**
  - Google y Moovit usan horarios programados.
  - Karta usa esperas estimadas: la mitad de la frecuencia típica de cada tipo de ruta.
  - Cuál acierta se mide en el piloto, con viajes de verdad.

## Resultados

Hora de llegada de la opción más rápida. «Karta antes» es la versión previa a los arreglos de abajo, cuando cambió.

| Trayecto | Karta | Google Maps | Moovit |
|---|---|---|---|
| 1. Patio Portal → Puerta del Reloj | **8:34** · T100E · 8 min a pie | 8:39 · T100E · 11 min | 8:42 · X101 · 15 min |
| 2. Terminal de Transportes → C. C. Bocagrande | 8:57 · C016 → T103 · 3 min | **8:56** · A114 → T100E → X105 · 11 min | 8:59 · buseta → T103 · 8 min |
| 3. U. de Cartagena Zaragocilla → San Agustín | **8:34** · X103 · 11 min (antes: 8:39, T100E, 1,6 km a pie) | 8:38 · X103 · 15 min | 8:35 · X103 · 14 min |
| 4. Hospital El Pozón → Estación Bazurto | 8:50 · A117 → X104 · 3 min | 8:49 · A114 → T103 · 13 min | **8:45** · A117 → T103 · 0 min |
| 5. Olaya → Aeropuerto | 9:11 · X104 → T102 · 24 min | 9:24 · X101 → T102 · 41 min | **9:08** · X104 → buseta · 22 min |
| 6. Clínica Blas de Lezo → C. C. Plaza Bocagrande | **8:35** · T103 · 6 min | 8:49 · T103 · 17 min | 8:44 · X103 → X105 · 0 min |
| 7. Estación Los Ejecutivos → Parque de Castillogrande | 8:57 · T103 · 27 min (antes: ninguna opción) | 8:51 · X106 → X105 · 24 min | **8:41** · T103 → buseta · 2 min |
| 8. Ciudadela 2000 → India Catalina | 8:57 · X105 · 7 min (antes: 8:59) | **8:49** · A103 → X106 · 4 min | 9:07 · A103 → X106 · 4 min |
| 9. El Carmelo → Hospital Universitario | 8:34 · C001 · 5 min | 8:31 · C001 · 8 min | **8:23** · C001 · 6 min |
| 10. Crespo → Pie de la Popa | **8:35** · T102 → T103 · 10 min | 8:41 · T102 · 12 min | **8:35** · buseta · 12 min |

- **Karta llega primero, o a menos de 6 minutos de la mejor, en 7 de los 10 trayectos.**
- **En los otros tres pierde por 8 a 16 minutos:**
  - en el 8 y el 9, por las esperas que supone: 10 minutos para el A103 y el C001, cuando Google y Moovit tienen salidas programadas a las 8:05;
  - en el 7, porque llega a pie desde la troncal, mientras Google combina dos rutas X y Moovit una buseta.
- **Moovit es el más rápido en 4 trayectos y empata en otro.** En tres de esos cinco (5, 7 y 10) lo logra con las busetas tradicionales, que Karta no tiene.

## Lo que se arregló en Karta

1. **Destinos lejos de toda ruta (trayecto 7).** Karta no daba ninguna opción ni decía por qué. Ahora, si ninguna ruta pasa cerca, busca otra vez caminando hasta 2,5 km y lo avisa: «Ninguna ruta pasa cerca de tu origen o de tu destino: en estas opciones hay que caminar más de lo normal». Si el viajero puso un límite de caminata, se respeta.
2. **Las X fuera del carril (trayectos 3 y 9).** Karta trataba como «troncal» todo lo que estuviera a menos de 700 m de una estación, y ahí las rutas X solo paraban en estaciones. El X103 sale del carril y va por Piedra de Bolívar y Zaragocilla con paraderos de calle. Ahora:
   - las X solo paran en estaciones cuando van sobre el carril mismo de la troncal (a menos de 25 m de su recorrido);
   - en el carril van a la velocidad de la troncal.
3. **El aviso según su motivo.** El aviso de caminata salía con el título «Transcaribe no opera a esa hora». Ahora la API dice el motivo (`horario`, `caminata` o `caminata_larga`), y la app muestra el título y la acción que corresponden.

## Lo que aprendimos de las otras apps

- **Los datos existen en algún formato digital.**
  - Google Maps muestra horarios programados con el módulo de la estación («Horario programado: 8:10 a. m. desde Patio Portal A1») y paraderos de alimentadoras con nombre.
  - Moovit muestra salidas programadas.
  - Es la información que pide el [derecho de petición](legal/derecho-de-peticion-transcaribe.md); de dónde la sacan las dos apps no lo sabemos.
- **Ninguna tiene tiempo real de Transcaribe.** Google dice «Horario programado», y Moovit muestra salidas a horas fijas. Que la comunidad diga por dónde va el bus sigue siendo lo que solo Karta tendría.
- **«El que pase primero» ya existe en las dos:** «T103 o X105», «T100E o T102». Karta lo hace igual (D19).
- **Moovit incluye las busetas tradicionales** (Coointracar, Metrocar, Vehitrans…) y con ellas gana tres trayectos. Karta no las tiene; decidir si se agregan es una pregunta de producto, no un error.
- **Publicidad y ventas:**
  - en una sola consulta de Moovit hubo un anuncio a pantalla completa, una oferta de Moovit+ en ventana y un banner fijo;
  - las dos apps ponen primero, o mezclan con el bus, viajes en carro por app.
  - Karta no tiene nada de eso.
- **Google avisa de inundaciones en la ruta** («Inundaciones en Cartagena de Indias: tu ruta puede verse afectada»). Karta tiene los reportes de la comunidad, pero no avisos de toda la ciudad.
- **Las dos dejan elegir el día de salida.** Karta solo la hora: la próxima vez que llegue esa hora.

## Pendiente

- **Esperas calibradas.** Karta usa esperas fijas: 5 minutos en la troncal, 8 en las pretroncales y 10 en las alimentadoras. Con las frecuencias reales (si Transcaribe responde la petición) o con los avistamientos del piloto, los trayectos 8 y 9 dejarían de perder 8 y 11 minutos.
- ~~**El buscador.** Karta no encuentra «Mercado de Bazurto», «La Boquilla», «Hotel Caribe» ni «Caribe Plaza».~~
  **Hecho:** de OpenStreetMap ya se importan 1.517 lugares (antes 455):
  - mercados y zonas comerciales;
  - hoteles, iglesias, colegios, clínicas y supermercados;
  - estaciones de servicio, policía, corregimientos e islas.

  Cada sitio lleva su barrio, para distinguir los que se llaman igual («Terpel · Alto Bosque»).
- ~~**Elegir el día** de salida, no solo la hora.~~ **Hecho:** «Hoy, a otra hora», «Mañana» u «Otro día» (hasta un mes), y la cabecera dice «Vie 30 oct 8:00 a. m.».
- **Repetir esta comparación** en el piloto con viajes reales, midiendo la hora a la que se llega de verdad.
- ~~**Las rutas A104 y C017**, que Karta nunca sugería porque su recorrido en OSM salía cortado.~~ **Hecho:** se arregló el encadenado de las vías, y las 24 rutas quedaron completas (ver D18 en el plan).
