# Transbordos en toda la red: antes y ahora

> Generado con `python -m scripts.analizar_transbordos --md ../docs/analisis-transbordos.md` (backend). **Antes:** cualquier punto a menos de 300 m servía para cambiar de bus, la caminata era la línea recta con un 30 % de rodeo y las rutas X se podían tomar en cualquier punto de la avenida. **Ahora:** Santa Lucía ↔ Madre Bernarda (40 m por la cebra) y el Patio Portal son transbordos integrados, entrar desde la calle a una estación troncal cuesta 2 minutos por cruzar la avenida, y sobre la troncal las X solo paran en estaciones.

Viajes simulados: **423** (cada alimentadora con estado confiable en OSM, un origen cada 1200 m de su recorrido a más de 900 m de la troncal, hacia cada estación troncal a más de 2,5 km). Salida en día hábil, todas las rutas en servicio.

| | Antes | Ahora |
|---|---|---|
| Viajes con transbordo | 207 | 232 |
| Caminata del transbordo, mediana | 19 m | 40 m |
| Caminata del transbordo, percentil 90 | 149 m | 60 m |
| Transbordos integrados (misma estación o Santa Lucía ↔ Madre Bernarda) | — | 204 |
| Transbordos de más de 200 m caminando | 21 | 0 |
| Tiempo total, mediana (viajes con transbordo) | 48 min | 49 min |
| Donde el cambio es en otro lugar: minutos de más (mediana) | — | +2 min |

## Dónde se cambia de bus

| Bajarse en → subirse en | Antes | Ahora |
|---|---|---|
| un paradero → un paradero | 91 | 28 |
| Santa Lucía → Madre Bernarda | 0 | 100 |
| un paradero → Madre Bernarda | 78 | 0 |
| Patio Portal → Patio Portal | 0 | 72 |
| La Castellana → La Castellana | 18 | 20 |
| un paradero → La Castellana | 19 | 0 |
| Bazurto → Bazurto | 0 | 10 |
| un paradero → Cuatro Vientos | 1 | 0 |
| La Popa → La Popa | 0 | 1 |
| Cuatro Vientos → Cuatro Vientos | 0 | 1 |

## Viajes en los que cambió el lugar del transbordo (156)

| Alimentadora → destino | Antes | Ahora |
|---|---|---|
| A101 → La Bodeguita | X104 → T100E: un paradero → un paradero, 90 m, 44 min | A101 → T100E: Patio Portal → Patio Portal, 60 m, 48 min |
| A101 → Los Ejecutivos | X104 → T103: un paradero → un paradero, 92 m, 26 min | A101 → T101: Patio Portal → Patio Portal, 60 m, 31 min |
| A101 → Bazurto | A101 → T103: un paradero → un paradero, 12 m, 43 min | A101 → T103: Patio Portal → Patio Portal, 60 m, 45 min |
| A101 → Centro | A101 → T100E: un paradero → un paradero, 15 m, 48 min | A101 → T100E: Patio Portal → Patio Portal, 60 m, 51 min |
| A101 → Chambacú | A101 → T102: un paradero → un paradero, 11 m, 48 min | A101 → T102: Patio Portal → Patio Portal, 60 m, 51 min |
| A101 → El Prado | A101 → T102: un paradero → un paradero, 11 m, 41 min | A101 → T102: Patio Portal → Patio Portal, 60 m, 44 min |
| A101 → La Bodeguita | A101 → T100E: un paradero → un paradero, 15 m, 50 min | A101 → T100E: Patio Portal → Patio Portal, 60 m, 53 min |
| A101 → Los Ejecutivos | A101 → T103: un paradero → un paradero, 12 m, 33 min | A101 → T101: Patio Portal → Patio Portal, 60 m, 35 min |
| A101 → María Auxiliadora | A101 → T100E: un paradero → un paradero, 15 m, 39 min | A101 → T100E: Patio Portal → Patio Portal, 60 m, 42 min |
| A101 → La Bodeguita | A101 → T100E: un paradero → un paradero, 15 m, 55 min | A101 → T100E: Patio Portal → Patio Portal, 60 m, 57 min |
| A101 → La Bodeguita | A101 → T100E: un paradero → un paradero, 15 m, 60 min | A101 → T100E: Patio Portal → Patio Portal, 60 m, 62 min |
| A102 → La Bodeguita | X101 → T100E: un paradero → Madre Bernarda, 213 m, 44 min | X106 → T100E: La Castellana → La Castellana, 60 m, 47 min |
| A102 → Bazurto | A102 → T103: un paradero → un paradero, 71 m, 48 min | A102 → T103: Patio Portal → Patio Portal, 60 m, 49 min |
| A102 → Centro | A102 → T100E: un paradero → un paradero, 14 m, 54 min | A102 → T100E: Patio Portal → Patio Portal, 60 m, 54 min |
| A102 → El Prado | A102 → T102: un paradero → un paradero, 68 m, 47 min | A102 → T102: Patio Portal → Patio Portal, 60 m, 48 min |
| A102 → La Bodeguita | A102 → T100E: un paradero → un paradero, 64 m, 56 min | A102 → T100E: Patio Portal → Patio Portal, 60 m, 56 min |
| A102 → La Bodeguita | X101 → T100E: un paradero → Madre Bernarda, 213 m, 43 min | X101 → T100E: Cuatro Vientos → Cuatro Vientos, 60 m, 46 min |
| A103 → Bazurto | A103 → T103: un paradero → Madre Bernarda, 17 m, 47 min | A103 → T103: Santa Lucía → Madre Bernarda, 40 m, 49 min |
| A103 → Centro | A103 → T100E: un paradero → Madre Bernarda, 17 m, 53 min | A103 → T100E: Santa Lucía → Madre Bernarda, 40 m, 54 min |
| A103 → Chambacú | A103 → T103: un paradero → Madre Bernarda, 17 m, 53 min | A103 → T103: Santa Lucía → Madre Bernarda, 40 m, 55 min |
| A103 → La Bodeguita | A103 → T100E: un paradero → Madre Bernarda, 13 m, 55 min | A103 → T100E: Santa Lucía → Madre Bernarda, 40 m, 57 min |
| A103 → Los Ejecutivos | A103 → T101: un paradero → Madre Bernarda, 17 m, 38 min | A103 → X106: un paradero → un paradero, 6 m, 37 min |
| A103 → María Auxiliadora | A103 → T100E: un paradero → Madre Bernarda, 13 m, 44 min | A103 → T100E: Santa Lucía → Madre Bernarda, 40 m, 46 min |
| A103 → Bazurto | A103 → T103: un paradero → Madre Bernarda, 17 m, 51 min | A103 → T103: Santa Lucía → Madre Bernarda, 40 m, 53 min |
| A103 → Centro | A103 → T100E: un paradero → Madre Bernarda, 17 m, 56 min | A103 → T100E: Santa Lucía → Madre Bernarda, 40 m, 58 min |
