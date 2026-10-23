---
name: Karta
description: Cómo moverse por Cartagena en Transcaribe y a pie, con el riesgo de cada recorrido a la vista.
colors:
  cal: "#FBFAF6"
  azulejo: "#FFFFFF"
  cal-baja: "#F6F4EE"
  cal-media: "#F0EEE7"
  cal-alta: "#EAE7DF"
  tinta: "#1B1B1F"
  tinta-suave: "#4A4B55"
  filete-gris: "#75767F"
  junta: "#D5D2C8"
  cobalto: "#1D3A8A"
  cobalto-claro: "#DCE3F7"
  cobalto-hondo: "#0D1F52"
  ocre: "#E3A72F"
  tinta-sobre-ocre: "#2A1E00"
  ocre-claro: "#FBE7BC"
  balcon: "#2E7D4F"
  ladrillo: "#B23A26"
  ladrillo-profundo: "#7F1D12"
  ladrillo-claro: "#F8DCD6"
  troncal: "#0B6E6E"
  pretroncal: "#A61E5A"
  alimentadora: "#7A4A1C"
  complementaria: "#5B3A8C"
  noche: "#12141B"
  noche-azulejo: "#282A32"
  noche-tinta: "#E6E4DD"
  cobalto-farol: "#B7C6F5"
  ocre-farol: "#F0C064"
typography:
  headline-lg:
    fontFamily: "Source Serif 4, Georgia, serif"
    fontSize: "32px"
    fontWeight: 700
    lineHeight: 1.25
    letterSpacing: "0"
  headline-md:
    fontFamily: "Source Serif 4, Georgia, serif"
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.29
    letterSpacing: "0"
    fontFeature: "tnum"
  headline-sm:
    fontFamily: "Source Serif 4, Georgia, serif"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.33
    letterSpacing: "0"
  title-lg:
    fontFamily: "Source Serif 4, Georgia, serif"
    fontSize: "22px"
    fontWeight: 600
    lineHeight: 1.27
    letterSpacing: "0"
  title-md:
    fontFamily: "Source Serif 4, Georgia, serif"
    fontSize: "16px"
    fontWeight: 600
    lineHeight: 1.5
    letterSpacing: "0"
  title-sm:
    fontFamily: "Roboto, sans-serif"
    fontSize: "14px"
    fontWeight: 500
    lineHeight: 1.43
    letterSpacing: "0.1px"
  body-lg:
    fontFamily: "Roboto, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "0.5px"
  body-md:
    fontFamily: "Roboto, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.43
    letterSpacing: "0.25px"
  body-sm:
    fontFamily: "Roboto, sans-serif"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.33
    letterSpacing: "0.4px"
  label-lg:
    fontFamily: "Roboto, sans-serif"
    fontSize: "14px"
    fontWeight: 500
    lineHeight: 1.43
    letterSpacing: "0.1px"
  label-md:
    fontFamily: "Roboto, sans-serif"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1.33
    letterSpacing: "0.5px"
  label-sm:
    fontFamily: "Roboto, sans-serif"
    fontSize: "11px"
    fontWeight: 500
    lineHeight: 1.45
    letterSpacing: "0.5px"
rounded:
  asa: "2px"
  filete-interior: "3px"
  atribucion: "4px"
  placa: "6px"
  boton: "8px"
  fab: "12px"
  hoja: "16px"
  redondo: "9999px"
spacing:
  xxs: "2px"
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "24px"
  placa: "10px 14px"
components:
  button-primary:
    backgroundColor: "{colors.cobalto}"
    textColor: "{colors.azulejo}"
    typography: "{typography.label-lg}"
    rounded: "{rounded.boton}"
    height: "48px"
    padding: "0 24px"
  button-outlined:
    backgroundColor: "{colors.cal}"
    textColor: "{colors.cobalto}"
    typography: "{typography.label-lg}"
    rounded: "{rounded.boton}"
    height: "48px"
    padding: "0 24px"
  button-text:
    textColor: "{colors.cobalto}"
    typography: "{typography.label-lg}"
    rounded: "{rounded.boton}"
    height: "48px"
    padding: "0 12px"
  fab-reportar:
    backgroundColor: "{colors.ocre}"
    textColor: "{colors.tinta-sobre-ocre}"
    typography: "{typography.label-lg}"
    rounded: "{rounded.fab}"
    height: "56px"
    padding: "0 20px"
  plaque:
    backgroundColor: "{colors.azulejo}"
    textColor: "{colors.cobalto}"
    rounded: "{rounded.placa}"
    padding: "{spacing.placa}"
  plaque-noche:
    backgroundColor: "{colors.noche-azulejo}"
    textColor: "{colors.cobalto-farol}"
    rounded: "{rounded.placa}"
    padding: "{spacing.placa}"
  mini-plaque:
    backgroundColor: "{colors.azulejo}"
    textColor: "{colors.cobalto}"
    typography: "{typography.label-lg}"
    rounded: "{rounded.placa}"
    height: "48px"
    padding: "7px 10px"
  route-capsule-troncal:
    backgroundColor: "{colors.troncal}"
    textColor: "{colors.azulejo}"
    typography: "{typography.label-md}"
    rounded: "{rounded.placa}"
    padding: "2px 7px"
  route-capsule-pretroncal:
    backgroundColor: "{colors.pretroncal}"
    textColor: "{colors.azulejo}"
    typography: "{typography.label-md}"
    rounded: "{rounded.placa}"
    padding: "2px 7px"
  route-capsule-alimentadora:
    backgroundColor: "{colors.alimentadora}"
    textColor: "{colors.azulejo}"
    typography: "{typography.label-md}"
    rounded: "{rounded.placa}"
    padding: "2px 7px"
  route-capsule-complementaria:
    backgroundColor: "{colors.complementaria}"
    textColor: "{colors.azulejo}"
    typography: "{typography.label-md}"
    rounded: "{rounded.placa}"
    padding: "2px 7px"
  route-capsule-grande:
    typography: "{typography.title-sm}"
    rounded: "{rounded.placa}"
    padding: "4px 10px"
  risk-badge-bajo:
    backgroundColor: "{colors.balcon}"
    textColor: "{colors.azulejo}"
    typography: "{typography.label-md}"
    rounded: "{rounded.placa}"
    padding: "4px 8px"
  risk-badge-medio:
    backgroundColor: "{colors.ocre}"
    textColor: "{colors.tinta-sobre-ocre}"
    typography: "{typography.label-md}"
    rounded: "{rounded.placa}"
    padding: "4px 8px"
  risk-badge-alto:
    backgroundColor: "{colors.ladrillo}"
    textColor: "{colors.azulejo}"
    typography: "{typography.label-md}"
    rounded: "{rounded.placa}"
    padding: "4px 8px"
  risk-badge-critico:
    backgroundColor: "{colors.ladrillo-profundo}"
    textColor: "{colors.azulejo}"
    typography: "{typography.label-md}"
    rounded: "{rounded.placa}"
    padding: "4px 8px"
  risk-badge-sin-datos:
    backgroundColor: "{colors.tinta-suave}"
    textColor: "{colors.azulejo}"
    typography: "{typography.label-md}"
    rounded: "{rounded.placa}"
    padding: "4px 8px"
  input:
    backgroundColor: "{colors.azulejo}"
    textColor: "{colors.tinta}"
    typography: "{typography.body-lg}"
    rounded: "{rounded.placa}"
  bottom-sheet:
    backgroundColor: "{colors.cal}"
    textColor: "{colors.tinta}"
    rounded: "{rounded.hoja}"
    padding: "0 24px 24px"
  map-icon-button:
    backgroundColor: "{colors.cal}"
    textColor: "{colors.cobalto}"
    rounded: "{rounded.redondo}"
    size: "48px"
---

# Design System: Karta

## Overview

**Creative North Star: "Cal y azulejo"**

Karta lee Cartagena como sus propios muros: cada lugar, estación y forma de llegar lleva su placa de azulejo sobre cal blanca, como las placas con el nombre de las calles del Centro. El fondo es cal cálida, la tinta es el azul cobalto del azulejo y los colores de fachada (ocre, ladrillo, verde de balcón, verde mar, madera) aparecen solo cuando codifican algo: tipo de ruta, nivel de riesgo, intensidad de un incidente. El mapa de OpenStreetMap va a sangre, claro y algo desaturado, para que esos códigos se lean sobre él a pleno sol.

La densidad es la de una herramienta de calle: pocas piezas por pantalla, cifras grandes y tabulares, objetivos de 48 dp o más y una sola acción de color cálido, el botón ocre «Reportar». La jerarquía la dan el serif de las placas (Source Serif 4) contra el Roboto del sistema, y el doble filete de las placas, no la sombra ni el color de relleno. El esquema claro es el principal por la luz solar; el oscuro es secundario y se llama «cal bajo farol»: el mismo mundo de noche, nunca un mapa invertido.

El sistema rechaza el default de la categoría: mapa oscuro invertido, tarjetas flotantes con sombra difusa y acento neón.

**Key Characteristics:**
- Placa de azulejo con doble filete en tinta cobalto como contenedor de todo lo que tiene nombre.
- Colores de fachada como código, nunca como adorno, siempre con ícono y texto o cifra.
- Una sola escala de color para riesgo de ruta e intensidad de incidente.
- Serif de placa para títulos y cifras grandes; Roboto del sistema para cuerpo y etiquetas.
- Cifras tabulares y espacio no separable entre número y unidad («90 m», «23 min»).
- Mapa claro desaturado de día y «cal bajo farol» de noche, nunca invertido.

## Colors

Muro encalado, tinta de azulejo y colores de fachada usados como código: la superficie es casi toda cal y cobalto, y el color saturado siempre significa algo.

### Primary
- **Cobalto de azulejo** (cobalto): la tinta de la interfaz. Filetes de las placas, texto de nombres en placas, íconos de acción, botón principal, punto de «tu ubicación», alfiler del mapa, borde de foco de los campos. Contraste 9,9:1 sobre cal. De noche pasa a **cobalto bajo farol** (cobalto-farol).
- **Cobalto claro / hondo** (cobalto-claro, cobalto-hondo): contenedor primario y su tinta, para estados seleccionados de Material 3.

### Secondary
- **Ocre de fachada** (ocre) con **tinta sobre ocre** (tinta-sobre-ocre): el único acento cálido de la interfaz, reservado para el botón extendido «Reportar» y, como código, para riesgo MEDIO e intensidad 3. Nunca lleva texto blanco: siempre la tinta oscura (7,7:1). De noche el rol secundario sube a ocre-farol.

### Tertiary
- **Verde de balcón** (balcon): riesgo BAJO e intensidad 1–2. Rol terciario del esquema.
- **Ladrillo** (ladrillo): riesgo ALTO, intensidad 4 y color de error. **Ladrillo profundo** (ladrillo-profundo): riesgo CRÍTICO e intensidad 5, y tinta sobre el contenedor de error (ladrillo-claro).

### Códigos de tipo de ruta (Transcaribe)
- **Verde mar** (troncal), **pretroncal** (pretroncal), **madera de balcón** (alimentadora) y **complementaria** (complementaria). Se usan en la cápsula de la ruta, en la polilínea del tramo en bus, en el riel del tramo y en las paradas de subida y bajada. Todos admiten texto blanco con 6:1 o más. Una ruta sin tipo conocido cae a tinta-suave.

### Neutral
- **Cal** (cal): fondo de pantallas, hojas inferiores y barra superior.
- **Azulejo** (azulejo): la cara blanca de las placas y el relleno de los campos de texto. De noche la placa usa noche-azulejo, un escalón sobre el fondo noche.
- **Cal baja / media / alta** (cal-baja, cal-media, cal-alta): contenedores tonales; cal-media es el recuadro de «Se reportará en…».
- **Tinta** (tinta): texto principal. **Tinta suave** (tinta-suave): texto secundario y riesgo sin datos (8,3:1 sobre cal).
- **Filete gris** (filete-gris): borde de campos y asa de las hojas. **Junta** (junta): divisores, como la junta entre azulejos.

### Named Rules
**The Fachada Es Código Rule.** Ocre, ladrillo, verde de balcón y los cuatro colores de ruta solo aparecen para codificar tipo de ruta, riesgo, intensidad o la acción de reportar. Nunca como fondo decorativo, ilustración o acento de marca.

**The Una Escala Rule.** Riesgo e intensidad comparten escala: BAJO e intensidad 1–2 en verde de balcón; MEDIO e intensidad 3 en ocre con tinta oscura; ALTO e intensidad 4 en ladrillo; CRÍTICO e intensidad 5 en ladrillo profundo. Un nivel desconocido se pinta en tinta suave, nunca como seguro.

**The Nunca Solo Color Rule.** El color nunca lleva el significado solo: el riesgo va con ícono y texto («Riesgo alto · 3 reportes»), la intensidad con su cifra 1–5 en la pastilla blanca y su categoría con el glifo.

**The Ruta No Es Botón Rule.** Ningún color de ruta repite el cobalto de la interfaz ni un color de riesgo: una cápsula nunca debe parecer un botón ni una alerta.

## Typography

**Display Font:** Source Serif 4 SemiBold y Bold, empaquetada (OFL), con Georgia y serif de respaldo
**Body Font:** Roboto, la del sistema Android

**Character:** El serif es la letra de la placa: nombres de lugares y estaciones, títulos de pantalla y de hoja, los minutos grandes de cada opción. El Roboto del sistema hace el trabajo de lectura corrida, etiquetas y cifras pequeñas. Ambas a espaciado 0 en los roles serif.

### Hierarchy
- **Headline** (Source Serif 4 700, 32 / 28 / 24 px): headline-lg en cobalto dentro de una placa, como título de las pantallas de entrada (inicio de sesión, registro); headline-md con cifras tabulares para los minutos de cada placa de opción («23» sobre «min aprox.»); headline-sm para títulos de hoja («Reportar incidente», nombre de la categoría) y el tiempo total del detalle.
- **Title** (Source Serif 4 600, 22 px y 16 px): title-lg para «¿A dónde vas?», la cabecera «Origen → Destino» y la barra superior; title-md para nombres en placas (estación, «Sube en…», «Bájate en…»). title-sm (Roboto 500, 14 px) para subtítulos de sección como «¿Qué está pasando?» y «Lugares guardados», en mayúscula inicial.
- **Body** (Roboto 400, 16 / 14 / 12 px): body-md es el texto secundario por defecto, en tinta suave; body-lg para el resumen junto al tiempo total; body-sm para el nombre largo de la ruta y la distancia a pie de una estación.
- **Label** (Roboto 500, 14 / 12 / 11 px): label-lg en botones, mini-placas (700) y secuencia de tramos; label-md en cápsulas de ruta (800, cifras tabulares) e insignias de riesgo (700); label-sm para «min aprox.» y la atribución de OpenStreetMap.

### Named Rules
**The Placa Lleva Serif Rule.** Todo nombre propio que vive en una placa (lugar, estación, parada) y todo título va en Source Serif 4; el cuerpo, las etiquetas y los controles se quedan en Roboto.

**The Cifra Tabular Rule.** Minutos, metros y códigos de ruta usan cifras tabulares, y la cifra va unida a su unidad por un espacio no separable: con letra grande, «90 m» nunca se parte en dos renglones.

**The Letra Del Sistema Manda Rule.** El texto respeta el tamaño de fuente del sistema (verificado a 1,3×); los contenedores crecen y las filas bajan de renglón en vez de recortar. La única excepción es la cifra de intensidad dentro de la pastilla del marcador, que no escala porque mide lo mismo que el marcador.

## Layout

El mapa va a sangre detrás de todo. Encima, arriba, una fila con la placa de búsqueda (alto mínimo 56 dp) y el botón redondo de cuenta, y debajo la fila horizontal de mini-placas de lugares guardados; margen de 12 dp a los lados y 8 dp arriba, dentro del área segura. Abajo, una hoja de cal arrastrable (14 %, 42 % y 62 % del alto) con las placas de estaciones cercanas. El botón «Reportar» flota 16 dp sobre el borde de la hoja, a la derecha, al alcance del pulgar; centrar ubicación y la atribución de OSM van a la izquierda, 12 dp sobre la hoja, con la atribución limitada a media pantalla de ancho.

El ritmo es de 4 dp: 4 y 8 dp entre piezas de una misma placa, 12 dp entre ícono y texto, 16 dp de margen de pantalla en listas, 20 dp entre grupos de un formulario en hoja y 24 dp de margen lateral en hojas modales. Las placas usan un relleno propio de 10 × 14 dp dentro del doble filete, y 8 dp de separación entre placas apiladas. Las listas de opciones terminan con una nota de método y fuente en body-md.

En el detalle de ruta, el mapa ocupa la pantalla con la hoja inicial al 42 %; el recorrido se encuadra con 40 dp a los lados y deja libre el alto de la hoja. Los tramos se leen como una secuencia vertical con un riel de 40 dp a la izquierda: punteado en tinta para caminar, continuo en el color de la ruta para el bus.

**Brecha conocida (no es una decisión).** Todas las capturas finales salen del build web a 412 × 915 dp. No hay captura de un dispositivo o emulador Android: los insets del sistema, el comportamiento del teclado (IME) y el gesto de Atrás predictivo no están verificados.

## Elevation & Depth

El sistema es plano en reposo y separa por filete y por tono, no por sombra. Las placas en flujo (opciones de ruta, estaciones, tramo en bus) no tienen sombra: el doble filete basta. La sombra solo aparece en lo que flota sobre el mapa, para despegarlo de las calles, y siempre es corta y oscura, nunca difusa ni de color.

### Shadow Vocabulary
- **Placa sobre el mapa** (elevación Material 4, sombra negra al 35 %): placa de búsqueda y mini-placas de lugares guardados.
- **Botón sobre el mapa** (elevación 3, negro al 35 %): botones redondos de volver, cuenta y centrar.
- **Hoja sobre el mapa** (elevación 8, negro al 40 %): hojas arrastrables de inicio, detalle de ruta y elegir en el mapa.
- **Marcador** (`0 2px 6px rgba(0,0,0,0.35)` en la baldosa de incidente; `0 1px 4px rgba(0,0,0,0.25)` en el punto de ubicación): solo para que el marcador se lea sobre el mapa.

### Named Rules
**The Filete Antes Que Sombra Rule.** Una placa en una lista o una hoja nunca lleva sombra; solo la lleva cuando flota directamente sobre el mapa.

**The Cal Bajo Farol Rule.** De noche el mapa no se invierte: se desatura al 35 %, se calienta un poco y se oscurece restando luz (desplazamiento de −140), para que calles, agua y manzanas sigan distinguiéndose. De día el mapa se desatura al 55 %, para que no compita con los códigos de ruta y riesgo.

## Shapes

Esquinas pequeñas y firmes, como baldosa cortada: 6 dp en la placa, la cápsula de ruta, la insignia de riesgo, los campos de texto y la parada en el mapa; 3 dp en el filete interior de la placa. Los botones de texto y contorno usan 8 dp, el botón extendido «Reportar» 12 dp y las hojas inferiores 16 dp solo arriba. Lo redondo queda para lo que señala un punto: el punto de ubicación, los nodos del riel de tramos y los botones sobre el mapa con borde cobalto de 1,5 dp.

La forma propia del sistema es el **doble filete**: un filete exterior de 2 dp, 2 dp de aire en el color de la placa y un filete interior de 1 dp, ambos en la tinta primaria. Los marcadores sobre el mapa llevan, en cambio, un borde blanco de 2 dp (baldosa de incidente, parada, punto de ubicación, alfiler) o un halo blanco de 2,5 dp en la polilínea del bus, para recortarse contra cualquier calle.

## Components

### Buttons
Firmes y a la medida del pulgar.
- **Shape:** esquinas de 8 dp; alto mínimo 48 dp en todas las variantes, incluidos los botones de texto (48 × 48) y los botones segmentados.
- **Primary:** relleno cobalto con texto blanco en label-lg («Enviar reporte», «Elegir el origen»). Mientras envía, el ícono cambia por un indicador de progreso y el texto por «Enviando…».
- **Outlined:** contorno cobalto de 1,5 dp sobre cal.
- **Text:** cobalto, para acciones de salida como «Reintentar».
- **Reportar (signature):** botón extendido de acción en ocre con tinta sobre ocre, label-lg en 700, esquinas de 12 dp, ícono de megáfono. Es la única pieza de ocre que no codifica un nivel.

### Placa (signature)
El contenedor de todo lo que tiene nombre.
- **Corner Style:** 6 dp exterior, 3 dp en el filete interior.
- **Background:** azulejo (blanco) de día, noche-azulejo de noche.
- **Border:** doble filete en la tinta primaria (2 dp, 2 dp de aire, 1 dp).
- **Shadow Strategy:** ninguna en flujo; elevación 4 solo sobre el mapa.
- **Internal Padding:** 10 × 14 dp por defecto.
- **Variantes:** placa de búsqueda «¿A dónde vas?» (title-lg cobalto, alto mínimo 56 dp); placa de opción de ruta (minutos en headline-md a la izquierda en una columna de 64 dp, secuencia de tramos, detalle, insignia de riesgo y chevrón); placa de estación (ícono de bus, nombre en title-md, distancia a pie, cápsulas de rutas, máximo seis y «+N más»); placa del tramo en bus en el detalle (cápsula grande, «Sube en…» y «Bájate en…» en title-md cobalto).

### Mini-placa
Acceso rápido a un lugar guardado o a «Guardar Casa». La misma placa con doble filete, alto mínimo 48 dp, relleno de 7 × 10 dp, ícono de 18 dp y etiqueta en label-lg 700 cobalto, en una fila horizontal desplazable.

### Cápsula de ruta
El letrero del bus: el código («T103», «X105») en blanco, label-md 800 con cifras tabulares, sobre el color de su tipo de ruta, esquinas de 6 dp. La variante grande (title-sm, 4 × 10 dp) encabeza la placa del tramo en bus. Lee en voz «Ruta T103, troncal».

### Insignia de riesgo
Rectángulo de 6 dp con ícono de 16 dp y texto en label-md 700: «Riesgo bajo / medio / alto / crítico / sin datos», con «· N reportes» cuando hay incidentes. Colores de la escala única; MEDIO lleva tinta oscura.

### Inputs / Fields
- **Style:** relleno azulejo, contorno filete-gris de 1 dp, esquinas de 6 dp.
- **Focus:** el contorno pasa a cobalto de 2 dp.
- **Error:** ladrillo, con su mensaje debajo.

### Marcadores del mapa
- **Baldosa de incidente:** cuadrado de 32 dp (48 en el detalle), esquinas al 22 % del lado, borde blanco de 2 dp, relleno del color de su intensidad y glifo de la categoría (carro para Tráfico, escudo para Seguridad). En la esquina superior derecha, una pastilla blanca con la cifra 1–5 en tinta y borde del color de la intensidad. Objetivo táctil de 48 dp. En el detalle de ruta, los incidentes a más de 500 m del recorrido quedan al 45 % de opacidad; los que caen sobre una parada se corren arriba a la izquierda para que ambos se vean.
- **Parada de subida y bajada:** cuadrado de 28 dp en el color de la ruta, borde blanco y ícono de bus.
- **Punto de ubicación:** círculo cobalto de 16 dp con borde blanco de 3 dp y halo cobalto al 18 %.
- **Alfiler:** gota maciza cobalto con borde y centro blancos; su punta marca el punto.
- **Botón redondo sobre el mapa:** 48 dp, fondo cal, borde cobalto de 1,5 dp, ícono cobalto.
- **Atribución de OSM:** «© colaboradores de OpenStreetMap» en label-sm sobre cal al 85 %, esquinas de 4 dp, siempre visible.

### Recorrido en el mapa
La caminata es una línea punteada en tinta de 5 dp; el bus, una línea continua de 6 dp en el color de su ruta con halo blanco de 2,5 dp. El recorrido se dibuja de origen a destino una sola vez en 900 ms con salida cúbica; si el sistema desactiva las animaciones, aparece completo.

### Hojas inferiores
Fondo cal, esquinas superiores de 16 dp, asa de 32 × 4 dp en filete gris. Las modales (reportar, detalle de incidente, editar lugar) usan 24 dp de margen lateral y suben con el teclado. El formulario de reporte usa botones segmentados de 48 dp para categoría (con glifo) e intensidad (1–5, anclada con «Leve» y «Grave» y el nombre del nivel elegido), y un recuadro cal-media que dice dónde caerá el reporte.

### Navigation
Pila de pantallas con barra superior plana en cal (sin tinte, elevación 2 al desplazar) y título en title-lg serif. Sobre el mapa no hay barra: volver es un botón redondo de 48 dp. Los avisos usan un snackbar flotante en superficie inversa.

## Do's and Don'ts

### Do:
- **Do** poner todo lugar, estación, opción de ruta y tramo en bus dentro de una placa con doble filete (2 dp, 2 dp, 1 dp) en la tinta primaria.
- **Do** pintar el riesgo y la intensidad con la escala única (balcón, ocre, ladrillo, ladrillo profundo) y el riesgo desconocido en tinta suave.
- **Do** acompañar cada color de código con ícono y texto, o con su cifra.
- **Do** usar cifras tabulares y el espacio no separable entre número y unidad en minutos y distancias.
- **Do** mantener objetivos táctiles de 48 dp o más, incluidos marcadores, segmentos y botones de texto.
- **Do** dejar visible la atribución de OpenStreetMap en todo mapa.
- **Do** respetar la desactivación de animaciones del sistema: el recorrido aparece completo.
- **Do** rotular los tiempos como aproximados («min aprox.», «Espera aprox.»).

### Don't:
- **Don't** invertir el mapa en modo oscuro; usar la matriz «cal bajo farol».
- **Don't** usar ocre, ladrillo, verde de balcón ni colores de ruta como decoración o acento de marca.
- **Don't** dar a un color de ruta el cobalto de la interfaz ni un color de riesgo.
- **Don't** poner texto blanco sobre ocre; va la tinta sobre ocre.
- **Don't** presentar un riesgo sin datos como bajo o seguro.
- **Don't** poner sombra a una placa que vive dentro de una lista u hoja.
- **Don't** usar Source Serif 4 en cuerpo, etiquetas o controles, ni Roboto en nombres de placa y títulos.
