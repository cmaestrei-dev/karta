# Auditoría de diseño y usabilidad de la app Karta (antes del rediseño)

Método: dos evaluaciones independientes (revisión de diseño y evidencia del detector automático) más una auditoría técnica nativa de Android, hechas el 23 de octubre de 2026 sobre la versión de la app anterior al rediseño «Cal y azulejo». El detector automático de Impeccable solo lee HTML/CSS: sobre el código Dart no encontró nada que analizar, y eso **no** significa que la app pase. Por eso la evidencia mecánica es un conteo estático del código fuente.

## Resumen

| Evaluación | Resultado |
|---|---|
| Heurísticas de Nielsen | **17/40 — Pobre** |
| Auditoría técnica nativa (Android) | **9/20 — Deficiente** |
| Detector automático | No aplica a Dart (0 archivos analizables); se reemplazó por conteo estático |

**Veredicto de especificidad:** el diseño es intercambiable con cualquier demo de la categoría. "Mapa oscuro + tarjeta flotante + dos botones" no muestra nada de Cartagena ni de Transcaribe: ni estaciones, ni códigos de ruta, ni la ubicación del usuario. El único nombre local, "Bocagrande", está escrito fijo en el código.

## Heurísticas de Nielsen

| # | Heurística | Nota | Problema clave |
|---|---|---|---|
| 1 | Visibilidad del estado | 2 | Spinners sin contexto; si fallan los incidentes no se avisa y el mapa vacío parece "zona segura"; los incidentes no se refrescan aunque expiran. |
| 2 | Coincidencia con el mundo real | 1 | Jerga militar ("Radar Táctico", "Cerebro Digital"), "Score" en inglés, "Ruta Satelital" falso, "Destino Frecuente" que no es de nadie. |
| 3 | Control y libertad | 2 | "Comprendido" borra la ruta; no se puede cambiar el destino; "Cerrar sesión" a un toque y a 8 dp de "Reportar". |
| 4 | Consistencia y estándares | 2 | 67 colores escritos a mano, sin `ColorScheme`; acentos mezclados con el morado por defecto de Material 3; controles inventados. |
| 5 | Prevención de errores | 2 | El reporte se publica sin confirmar dónde queda y sin poder deshacerlo. |
| 6 | Reconocer en vez de recordar | 2 | Botón de reportar sin etiqueta; todos los incidentes con el mismo pin rojo; puntaje de riesgo sin escala. |
| 7 | Flexibilidad y eficiencia | 1 | Un solo camino fijo: sin búsqueda, sin lugares guardados, sin recientes. |
| 8 | Diseño minimalista | 3 | Limpio y con el mapa como protagonista, pero la tarjeta ocupa el 40 % de la pantalla para un destino fijo. |
| 9 | Recuperación de errores | 1 | Errores técnicos en cadena ("Fallo satelital OSRM: Código 500"); "Volver a intentar" no reintenta. |
| 10 | Ayuda | 1 | No se explica el puntaje, la escala de intensidad ni para qué sirve Residente/Turista. |

## Auditoría técnica nativa

| # | Dimensión | Nota | Hallazgo clave |
|---|---|---|---|
| 1 | Accesibilidad | 2 | Botón de reportar sin etiqueta para TalkBack; texto blanco sobre acentos entre 1,9:1 y 3,3:1 (mínimo 4,5:1). |
| 2 | Rendimiento y red | 2 | Arranque bloqueado por la red; peticiones sin tiempo límite; un fallo de carga se ve como "sin incidentes". |
| 3 | Apariencia y tema | 1 | Sin roles de color; solo tema oscuro con el mapa invertido (inversión rápida que la guía de Android prohíbe). |
| 4 | Conformidad con Android | 2 | Tarjeta y atribución de OSM tapadas por la barra de navegación; acción principal fuera del alcance del pulgar. |
| 5 | Adaptabilidad | 2 | Tarjeta rígida sin scroll: en horizontal o con fuente grande tapa la barra superior. |

## Lo que funcionaba

1. El riesgo no depende solo del color: cada nivel lleva ícono, texto y color, y un nivel desconocido no se muestra como "seguro".
2. Reportar era corto: dos toques con valores por defecto y un agradecimiento al final.
3. La autenticación era sólida: validación en línea, errores claros, consentimiento de la Ley 1581 y token en almacenamiento seguro.

## Problemas prioritarios y cómo los resuelve el rediseño

| Prioridad | Problema | Respuesta en «Cal y azulejo» |
|---|---|---|
| P0 | La tarea central es imposible: destino fijo, ruta en modo carro (OSRM `driving`) y sin la ubicación del usuario. | Buscador «¿A dónde vas?», elegir en el mapa, lugares guardados y rutas sugeridas de Transcaribe del backend; punto de "mi ubicación". |
| P1 | El riesgo alarma pero no deja actuar (trazar y escanear por separado, puntaje sin escala). | El riesgo va dentro de cada opción y las opciones se ordenan por tiempo y riesgo. |
| P1 | Con mala señal se cae: sin timeouts, errores invisibles, sesión perdida sin red. | Cliente HTTP común con tiempo límite, estados de error con reintento real y aviso cuando los incidentes no cargan. |
| P1 | Reportar está escondido, sin etiqueta y sin mostrar dónde cae el reporte. | Botón extendido «Reportar» al alcance del pulgar; la hoja muestra el nombre del lugar donde se reporta; cerrar sesión pasa a un menú con confirmación. |
| P1 | La voz y el tema contradicen el contexto (jerga militar, tema oscuro invertido, contraste bajo al sol). | Español llano; esquema claro de alto contraste como principal, con roles de color Material 3 y colores `on-*` verificados. |

## Señales de alerta por persona

- **Viajero diario** (de pie en el bus, una mano, señal débil): no puede poner su destino, reportar le queda lejos del pulgar, el spinner no termina y el mapa invertido se lava al sol.
- **Turista:** no puede buscar "Castillo San Felipe"; "Score: 58" no le dice si es seguro; "CRÍTICO" lo asusta sin ofrecerle alternativa.
- **TalkBack:** el botón de reportar se anuncia sin nombre y las categorías no dicen cuál está seleccionada.

## Evidencia estática del código (reemplazo del detector)

- `Color(0x…)`: 8 líneas en 4 archivos; `Colors.…`: 59 usos en 6 archivos; `Theme.of`/`colorScheme`/`textTheme`: 0.
- `fontSize:` fijo: 15 usos con 8 tamaños distintos.
- `IconButton` sin `tooltip`: 1 (el de reportar). `Semantics(`: 0.
- Textos con jerga: "Táctico", "Satelital", "Cerebro Digital" (2), "Error del radar".
