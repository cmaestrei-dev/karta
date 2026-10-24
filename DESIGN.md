---
name: Karta
description: Cómo moverse por Cartagena en Transcaribe y a pie, con lo que reporta la comunidad a la vista.
colors:
  fondo-oscuro: "#0B1621"
  hoja-oscura: "#0F1C29"
  tarjeta-oscura: "#162738"
  campo-oscuro: "#1D3246"
  asa-oscura: "#3A5168"
  texto-oscuro: "#EAF2F7"
  texto-suave-oscuro: "#9DB2C4"
  divisor-oscuro: "#EAF2F714"
  acento-oscuro: "#3DDBB5"
  sobre-acento-oscuro: "#04261D"
  acento-suave-oscuro: "#3DDBB524"
  reportar-oscuro: "#FFC247"
  sobre-reportar: "#2A1C00"
  en-vivo-oscuro: "#4BE38B"
  servicio-oscuro: "#7FA8FF"
  via-oscura: "#FFC247"
  seguridad-oscura: "#FF7A6B"
  servicio-suave-oscuro: "#7FA8FF29"
  via-suave-oscura: "#FFC24729"
  seguridad-suave-oscura: "#FF7A6B29"
  troncal-oscura: "#2EC4B6"
  fondo-claro: "#EEF3F6"
  hoja-clara: "#FFFFFF"
  tarjeta-clara: "#F1F5F8"
  campo-claro: "#E8EFF3"
  asa-clara: "#C3CFD6"
  texto-claro: "#0B1621"
  texto-suave-claro: "#4B5F70"
  divisor-claro: "#0B162114"
  acento-claro: "#0B7F66"
  sobre-acento-claro: "#FFFFFF"
  acento-suave-claro: "#0B7F661F"
  reportar-claro: "#FFB61E"
  en-vivo-claro: "#0E8F4A"
  servicio-claro: "#2F5BD3"
  via-clara: "#D99400"
  seguridad-clara: "#D23B2C"
  servicio-suave-claro: "#2F5BD31F"
  via-suave-clara: "#E9A40029"
  seguridad-suave-clara: "#D23B2C1F"
  tinta-sobre-claro: "#14181F"
  ruta-troncal: "#0B6E6E"
  ruta-pretroncal: "#A61E5A"
  ruta-alimentadora: "#7A4A1C"
  ruta-complementaria: "#5B3A8C"
  ruta-sin-tipo: "#4B5F70"
  riesgo-bajo: "#2E7D4F"
  riesgo-medio: "#E3A72F"
  sobre-riesgo-medio: "#2A1E00"
  riesgo-alto: "#B23A26"
  riesgo-critico: "#7F1D12"
  riesgo-sin-datos: "#4B5F70"
  mapa-tierra-oscura: "#1E2C39"
  mapa-agua-oscura: "#061524"
  mapa-tierra-clara: "#EDF1F3"
  mapa-agua-clara: "#BBD7E5"
  blanco-de-pin: "#FFFFFF"
typography:
  headline-lg:
    fontFamily: "Manrope, sans-serif"
    fontSize: "32px"
    fontWeight: 800
    lineHeight: 1.25
    letterSpacing: "-0.5px"
  headline-md:
    fontFamily: "Manrope, sans-serif"
    fontSize: "28px"
    fontWeight: 800
    lineHeight: 1.29
    letterSpacing: "-0.3px"
    fontFeature: "tnum"
  headline-sm:
    fontFamily: "Manrope, sans-serif"
    fontSize: "24px"
    fontWeight: 800
    lineHeight: 1.33
    letterSpacing: "-0.2px"
  title-lg:
    fontFamily: "Manrope, sans-serif"
    fontSize: "22px"
    fontWeight: 800
    lineHeight: 1.27
    letterSpacing: "0"
  title-md:
    fontFamily: "Manrope, sans-serif"
    fontSize: "16px"
    fontWeight: 800
    lineHeight: 1.5
    letterSpacing: "0.15px"
  title-sm:
    fontFamily: "Manrope, sans-serif"
    fontSize: "14px"
    fontWeight: 700
    lineHeight: 1.43
    letterSpacing: "0.1px"
  body-lg:
    fontFamily: "Manrope, sans-serif"
    fontSize: "16px"
    fontWeight: 600
    lineHeight: 1.5
    letterSpacing: "0.5px"
  body-md:
    fontFamily: "Manrope, sans-serif"
    fontSize: "14px"
    fontWeight: 600
    lineHeight: 1.43
    letterSpacing: "0.25px"
  body-sm:
    fontFamily: "Manrope, sans-serif"
    fontSize: "12px"
    fontWeight: 600
    lineHeight: 1.33
    letterSpacing: "0.4px"
  label-lg:
    fontFamily: "Manrope, sans-serif"
    fontSize: "14px"
    fontWeight: 800
    lineHeight: 1.43
    letterSpacing: "0.1px"
  label-md:
    fontFamily: "Manrope, sans-serif"
    fontSize: "12px"
    fontWeight: 700
    lineHeight: 1.33
    letterSpacing: "0.5px"
  label-sm:
    fontFamily: "Manrope, sans-serif"
    fontSize: "11px"
    fontWeight: 700
    lineHeight: 1.45
    letterSpacing: "0.5px"
rounded:
  capsula: "6px"
  insignia: "10px"
  opcion: "12px"
  acceso: "14px"
  caja: "16px"
  tarjeta: "18px"
  pildora: "24px"
  hoja: "26px"
  redondo: "9999px"
spacing:
  xxs: "4px"
  xs: "8px"
  sm: "12px"
  md: "16px"
  pregunta: "18px"
  lg: "20px"
  xl: "24px"
  tarjeta: "12px 14px"
components:
  button-primary:
    backgroundColor: "{colors.acento-oscuro}"
    textColor: "{colors.sobre-acento-oscuro}"
    typography: "{typography.title-md}"
    rounded: "{rounded.tarjeta}"
    height: "56px"
  button-primary-clara:
    backgroundColor: "{colors.acento-claro}"
    textColor: "{colors.sobre-acento-claro}"
    typography: "{typography.title-md}"
    rounded: "{rounded.tarjeta}"
    height: "56px"
  button-neutro:
    backgroundColor: "{colors.campo-oscuro}"
    textColor: "{colors.texto-oscuro}"
    typography: "{typography.title-md}"
    rounded: "{rounded.tarjeta}"
    height: "56px"
  button-text:
    textColor: "{colors.acento-oscuro}"
    typography: "{typography.label-lg}"
    height: "48px"
  button-sigue-ahi-servicio:
    backgroundColor: "{colors.servicio-oscuro}"
    textColor: "{colors.tinta-sobre-claro}"
    typography: "{typography.title-md}"
    rounded: "{rounded.tarjeta}"
    height: "56px"
  button-sigue-ahi-via:
    backgroundColor: "{colors.via-oscura}"
    textColor: "{colors.tinta-sobre-claro}"
    typography: "{typography.title-md}"
    rounded: "{rounded.tarjeta}"
    height: "56px"
  button-sigue-ahi-seguridad:
    backgroundColor: "{colors.seguridad-oscura}"
    textColor: "{colors.tinta-sobre-claro}"
    typography: "{typography.title-md}"
    rounded: "{rounded.tarjeta}"
    height: "56px"
  fab-reportar:
    backgroundColor: "{colors.reportar-oscuro}"
    textColor: "{colors.sobre-reportar}"
    rounded: "{rounded.redondo}"
    size: "64px"
  fab-reportar-clara:
    backgroundColor: "{colors.reportar-claro}"
    textColor: "{colors.sobre-reportar}"
    rounded: "{rounded.redondo}"
    size: "64px"
  campo-de-destino:
    backgroundColor: "{colors.campo-oscuro}"
    textColor: "{colors.texto-oscuro}"
    typography: "{typography.title-lg}"
    rounded: "{rounded.tarjeta}"
    height: "58px"
    padding: "10px 18px"
  input:
    backgroundColor: "{colors.campo-oscuro}"
    textColor: "{colors.texto-oscuro}"
    typography: "{typography.body-lg}"
    rounded: "{rounded.caja}"
  tarjeta:
    backgroundColor: "{colors.tarjeta-oscura}"
    textColor: "{colors.texto-oscuro}"
    rounded: "{rounded.tarjeta}"
    padding: "{spacing.tarjeta}"
  tarjeta-sobre-mapa:
    backgroundColor: "{colors.hoja-oscura}"
    textColor: "{colors.texto-oscuro}"
    rounded: "{rounded.tarjeta}"
    padding: "{spacing.tarjeta}"
  acceso-guardado:
    backgroundColor: "{colors.tarjeta-oscura}"
    textColor: "{colors.texto-oscuro}"
    typography: "{typography.title-sm}"
    rounded: "{rounded.acceso}"
    height: "46px"
    padding: "0 14px 0 12px"
  chip-opcion:
    backgroundColor: "{colors.campo-oscuro}"
    textColor: "{colors.texto-oscuro}"
    typography: "{typography.title-sm}"
    rounded: "{rounded.opcion}"
    height: "48px"
    padding: "8px 14px"
  chip-opcion-elegida:
    backgroundColor: "{colors.acento-suave-oscuro}"
    textColor: "{colors.texto-oscuro}"
    typography: "{typography.title-sm}"
    rounded: "{rounded.opcion}"
    height: "48px"
    padding: "8px 14px"
  pildora-en-vivo:
    backgroundColor: "{colors.hoja-oscura}"
    textColor: "{colors.texto-oscuro}"
    typography: "{typography.label-lg}"
    rounded: "{rounded.pildora}"
    height: "48px"
    padding: "0 16px"
  map-icon-button:
    backgroundColor: "{colors.hoja-oscura}"
    textColor: "{colors.texto-oscuro}"
    rounded: "{rounded.redondo}"
    size: "48px"
  pin-de-reporte:
    backgroundColor: "{colors.blanco-de-pin}"
    rounded: "{rounded.redondo}"
    size: "44px"
  bottom-sheet:
    backgroundColor: "{colors.hoja-oscura}"
    textColor: "{colors.texto-oscuro}"
    rounded: "{rounded.hoja}"
    padding: "0 16px 24px"
  route-capsule-troncal:
    backgroundColor: "{colors.ruta-troncal}"
    textColor: "{colors.hoja-clara}"
    typography: "{typography.label-md}"
    rounded: "{rounded.capsula}"
    padding: "2px 7px"
  route-capsule-pretroncal:
    backgroundColor: "{colors.ruta-pretroncal}"
    textColor: "{colors.hoja-clara}"
    typography: "{typography.label-md}"
    rounded: "{rounded.capsula}"
    padding: "2px 7px"
  route-capsule-alimentadora:
    backgroundColor: "{colors.ruta-alimentadora}"
    textColor: "{colors.hoja-clara}"
    typography: "{typography.label-md}"
    rounded: "{rounded.capsula}"
    padding: "2px 7px"
  route-capsule-complementaria:
    backgroundColor: "{colors.ruta-complementaria}"
    textColor: "{colors.hoja-clara}"
    typography: "{typography.label-md}"
    rounded: "{rounded.capsula}"
    padding: "2px 7px"
  route-capsule-grande:
    typography: "{typography.title-sm}"
    rounded: "{rounded.capsula}"
    padding: "4px 10px"
  risk-badge-bajo:
    backgroundColor: "{colors.riesgo-bajo}"
    textColor: "{colors.hoja-clara}"
    typography: "{typography.label-md}"
    rounded: "{rounded.insignia}"
    padding: "4px 8px"
  risk-badge-medio:
    backgroundColor: "{colors.riesgo-medio}"
    textColor: "{colors.sobre-riesgo-medio}"
    typography: "{typography.label-md}"
    rounded: "{rounded.insignia}"
    padding: "4px 8px"
  risk-badge-alto:
    backgroundColor: "{colors.riesgo-alto}"
    textColor: "{colors.hoja-clara}"
    typography: "{typography.label-md}"
    rounded: "{rounded.insignia}"
    padding: "4px 8px"
  risk-badge-critico:
    backgroundColor: "{colors.riesgo-critico}"
    textColor: "{colors.hoja-clara}"
    typography: "{typography.label-md}"
    rounded: "{rounded.insignia}"
    padding: "4px 8px"
  risk-badge-sin-datos:
    backgroundColor: "{colors.riesgo-sin-datos}"
    textColor: "{colors.hoja-clara}"
    typography: "{typography.label-md}"
    rounded: "{rounded.insignia}"
    padding: "4px 8px"
---

# Design System: Karta

## Overview

**Creative North Star: "Bahía"**

Karta se ve como la bahía de Cartagena de noche: agua profunda casi negra, tierra un escalón más clara, la troncal de Transcaribe como una línea verde agua que cruza la ciudad y, encima, los reportes de la comunidad como burbujas blancas que caen sobre el lugar donde pasa algo. La versión clara es la misma bahía a pleno sol: agua celeste, calles blancas, el acento oscurecido para que se lea en el teléfono a mediodía. Los dos temas son de primera clase: la app sigue el tema del sistema (`ThemeMode.system`), y ningún token existe en uno sin su par en el otro.

El mapa es propio: un estilo vectorial (MapLibre v8 sobre las teselas de OpenFreeMap) con pocas vías, pocas etiquetas y sin íconos de comercios, para que lo importante (la troncal, los reportes, tu ubicación) lo dibuje la app encima. Todo lo que se toca vive abajo, al alcance del pulgar, en una hoja con esquinas grandes; arriba solo flotan el avatar del viajero, la píldora en vivo de reportes cercanos y el botón de ubicar. La letra es una sola, Manrope, en pesos altos (600 en cuerpo, 800 en títulos y botones) para que se lea en movimiento.

El color tiene dos trabajos y ninguno es adornar. El acento verde agua marca lo que es de la interfaz (acción principal, foco, selección, tu ubicación). Los colores de grupo (servicio en azul, vía en ámbar, seguridad en coral) y los de tipo de ruta dicen qué es algo. Las ilustraciones de los nueve tipos de reporte, con contorno de tinta y rellenos planos, hacen que un reporte se reconozca sin leer.

**Key Characteristics:**
- Mapa vectorial propio en dos paletas (noche y sol), nunca un mapa genérico filtrado.
- Todo lo táctil abajo, en la hoja; arriba solo avatar, píldora en vivo y ubicar.
- Superficies tonales sin borde: fondo, hoja, tarjeta y campo, cada una un escalón más clara (u oscura) que la anterior.
- Manrope empaquetada, pesos 600 a 800, cifras tabulares en minutos, metros y conteos.
- Colores de grupo y de ruta como código; nueve ilustraciones propias en tres grupos.
- Esquinas grandes y blandas (18 dp en tarjetas y botones, 26 dp en hojas).
- Movimiento con un rebote leve y corto; todo se queda quieto si el sistema pide reducir movimiento.

## Colors

Noche de bahía con un solo acento verde agua, un ámbar reservado para reportar y tres colores de grupo que funcionan como código; la versión clara repite cada rol con más contraste para el sol.

### Primary
- **Verde agua de bahía** (acento-oscuro / acento-claro): la voz de la interfaz. Relleno del botón principal, foco de campos, borde y fondo de la opción elegida, ícono de búsqueda, anillo del avatar e insignia de nivel, botón de ubicar, punto de «tu ubicación», alfiler, íconos de cajas informativas y la cifra de minutos de cada opción de ruta. En el tema claro baja a un verde profundo para sostener texto blanco (4,95:1).
- **Verde agua suave** (acento-suave-oscuro / acento-suave-claro): el mismo acento traslúcido, para el fondo de la opción elegida, el recuadro del ícono de estación y los avisos de «Gracias».

### Secondary
- **Ámbar de reportar** (reportar-oscuro / reportar-claro) con **tinta sobre ámbar** (sobre-reportar): solo el botón redondo de reportar. Nunca lleva texto blanco.

### Tertiary
- **Verde en vivo** (en-vivo-oscuro / en-vivo-claro): el punto que late en la píldora «N reportes cerca». Dice que la comunidad está activa; no se usa para nada más.

### Códigos de grupo de reporte
- **Servicio** (azul: servicio-oscuro / servicio-claro): el bus no pasa, bus lleno, estación cerrada.
- **Vía** (ámbar: via-oscura / via-clara): trancón, accidente, calle inundada.
- **Seguridad** (coral: seguridad-oscura / seguridad-clara): robo, calle sola u oscura, acoso. Es también el color de error del esquema Material.
- Cada grupo tiene su versión **suave** (≈ 12–16 % de opacidad) para el círculo detrás de su ilustración. El color pleno pinta el aro del pin, la punta, el borde de la cifra de confirmaciones, el punto del encabezado de grupo y el botón «Sigue ahí». Sobre un relleno de grupo el texto lo decide `tintaSobre`: tinta oscura (tinta-sobre-claro) sobre los colores claros, blanco sobre los oscuros.

### Códigos de tipo de ruta (Transcaribe)
- **Troncal, pretroncal, alimentadora y complementaria** (ruta-*): iguales en los dos temas, todos con texto blanco ≥ 6:1. Pintan la cápsula del código, la polilínea del tramo en bus y la parada de subida y bajada. Una ruta sin tipo cae a ruta-sin-tipo.
- **Troncal sobre el mapa** (troncal-oscura de noche; ruta-troncal de día): la línea de la troncal en el inicio, 4,5 dp con un borde de 2 dp en el color del fondo (oscuro) o blanco (claro) para separarla de las calles.

### Riesgo de ruta
- **Bajo, medio, alto, crítico y sin datos** (riesgo-*): iguales en los dos temas, solo en la insignia de riesgo de cada opción de ruta. Medio lleva tinta oscura (sobre-riesgo-medio); el resto, blanco.

### Neutral
- **Fondo** (fondo-oscuro / fondo-claro): el lienzo detrás de pantallas y mapa.
- **Hoja** (hoja-oscura / hoja-clara): hojas inferiores, barra superior, todo lo que flota sobre el mapa (píldora, botones redondos, tarjeta elevada) y diálogos.
- **Tarjeta** (tarjeta-oscura / tarjeta-clara): tarjetas de estación, celdas de la cuadrícula de reporte, accesos guardados y cajas informativas dentro de una hoja.
- **Campo** (campo-oscuro / campo-claro): campos de texto, «¿A dónde vas?», opciones sin elegir, botones redondos dentro de hojas y el botón neutro «Ya no está».
- **Asa** (asa-oscura / asa-clara): asa de la hoja, contorno de botones de contorno, punto apagado de la píldora cuando no hay reportes.
- **Texto / texto suave** (texto-* / texto-suave-*): principal ≥ 16:1; secundario ≥ 6:1 sobre hoja y tarjeta.
- **Divisor** (divisor-*): el texto al 8 %, para separar filas.
- **Mapa** (mapa-tierra-* / mapa-agua-*): la tierra y el agua del estilo vectorial; la tierra es también el color de fondo del mapa mientras cargan las teselas, para que no destelle.

### Named Rules
**The Código No Adorno Rule.** Los colores de grupo, de tipo de ruta y de riesgo solo aparecen para decir qué es algo. Nunca como fondo decorativo, degradado ni acento de marca; la marca es el verde agua.

**The Par Por Tema Rule.** Todo color de interfaz existe en la paleta oscura y en la clara, y cada par de texto cumple ≥ 4,5:1 en ambas (lo verifica `bahia_design_test.dart`, junto con el texto blanco sobre las cuatro rutas y la tinta de `tintaSobre` sobre los tres grupos). Un color nuevo entra con su par y su prueba.

**The Nunca Solo Color Rule.** El grupo va con su ilustración y su nombre; la ruta con su código escrito; el riesgo con ícono y texto («Riesgo alto · 3 reportes»). Un riesgo desconocido se pinta en sin-datos, nunca como bajo.

## Typography

**Display Font:** Manrope (OFL, empaquetada en 400, 500, 600, 700 y 800)
**Body Font:** Manrope

**Character:** Una sola familia geométrica y amable, usada pesada: cuerpo en 600, títulos y botones en 800, con un leve ajuste negativo en los titulares. Se lee de un vistazo en un bus en movimiento y a pleno sol.

### Hierarchy
- **Headline** (800, 32 / 28 / 24 px): headline-lg en el acento para el título de las pantallas de entrada; headline-md con cifras tabulares para los minutos de cada opción de ruta; headline-sm para el título de las hojas («¿Qué está pasando?», el nombre del tipo de reporte, el nombre del viajero).
- **Title** (800, 22 y 16 px; 700, 14 px): title-lg para «Cerca de ti», «¿Sigue ahí?», «Nivel N» y «¿A dónde vas?» (este en 700); title-md para nombres de estación y para el texto de todos los botones rellenos y de contorno; title-sm para preguntas del reporte, nombres de grupo (en texto suave), etiquetas de accesos guardados y opciones.
- **Body** (600, 16 / 14 / 12 px): body-md es el texto secundario por defecto, casi siempre en texto suave; body-lg para filas de lista y la pista de los campos; body-sm para distancias a pie, notas de vigencia y la nota de método.
- **Label** (800 / 700, 14 / 12 / 11 px): label-lg en la píldora en vivo, los botones de texto y el nombre bajo cada ilustración (700); label-md en cápsulas de ruta (800, cifras tabulares) e insignias de riesgo (700); label-sm en la atribución del mapa.

### Named Rules
**The Una Letra Rule.** Toda la interfaz va en Manrope; la jerarquía la dan el peso y el tamaño, no una segunda familia.

**The Cifra Tabular Rule.** Minutos, metros, conteos de reportes y códigos de ruta usan cifras tabulares (`tabularFigures`), para que las opciones y las tarjetas queden alineadas.

**The Letra Del Sistema Manda Rule.** El texto respeta el tamaño de letra del sistema: las celdas de la cuadrícula de reporte crecen con la letra (hasta 1,6×), las opciones bajan de renglón por encima de 1,3× y las cápsulas de una estación pasan a su propia línea.

## Layout

El mapa va a sangre detrás de todo y no rota. Arriba, dentro del área segura y con 16 dp de margen lateral y 12 dp arriba, una sola fila: el avatar del viajero a la izquierda, la píldora «N reportes cerca» centrada y el botón de ubicar a la derecha. Nada más flota arriba.

Abajo, una hoja arrastrable con tres alturas (20 %, 42 % inicial con imán, 86 %) contiene todo lo que se toca: el campo «¿A dónde vas?», la fila horizontal de accesos guardados, «Cerca de ti» y las tarjetas de estación apiladas a 8 dp. El botón redondo de reportar flota 16 dp sobre el borde de la hoja, a la derecha, al alcance del pulgar, y se encoge y se apaga cuando la hoja pasa del 62 %. La atribución del mapa va a la izquierda, 8 dp sobre la hoja, sin invadir la columna del botón.

El ritmo se mueve de 4 en 4 con algunos pasos intermedios: 4 dp entre cápsulas, 8 dp entre tarjetas, opciones y celdas, 12 dp entre ícono y texto y entre el campo de búsqueda y los accesos, 16 dp de margen lateral en hojas de inicio y de reporte (20 dp en el detalle de un reporte), 18 dp entre preguntas o grupos de un formulario, 20 dp antes de un encabezado de sección. Las tarjetas usan 14 × 12 dp de relleno.

Reportar es una hoja modal en dos pasos dentro de la misma hoja (máximo 90 % del alto, sube con el teclado): primero una cuadrícula de tres columnas por grupo; después, los detalles del tipo elegido. El paso cambia con un deslizamiento lateral corto y la hoja ajusta su alto suavemente.

## Elevation & Depth

Dentro de una hoja el sistema es plano y separa por tono: fondo, hoja, tarjeta y campo son escalones de la misma noche (o del mismo día), sin bordes ni sombras. La sombra solo aparece en lo que flota directamente sobre el mapa, siempre negra, suave y corta, nunca de color.

### Shadow Vocabulary
- **Sobre el mapa** (elevación Material 6, sombra negra al 35–40 %): píldora en vivo, botones redondos, tarjeta elevada.
- **Botón de reportar** (elevación 8): el único elemento que flota sobre la hoja.
- **Hoja de inicio** (elevación 12, negro al 45 %): la hoja arrastrable sobre el mapa.
- **Avatar** (`0 4px 14px rgba(0,0,0,0.30)`), **pin de reporte** (`0 4px 10px rgba(0,0,0,0.35)`) y **punto de ubicación** (`0 2px 8px rgba(0,0,0,0.40)`): solo para que se lean sobre cualquier calle.

### Named Rules
**The Tono Antes Que Sombra Rule.** Una tarjeta dentro de una hoja nunca lleva sombra ni borde; se separa por ser un escalón de tono. Solo lo que flota sobre el mapa se eleva.

## Shapes

Esquinas grandes y blandas en todo lo que se toca: 18 dp en tarjetas, celdas de reporte, el campo «¿A dónde vas?» y todos los botones rellenos y de contorno; 26 dp solo arriba en las hojas; 16 dp en campos de texto y cajas informativas; 14 dp en accesos guardados y snackbars; 12 dp en opciones y en el recuadro del ícono de estación. Lo pequeño y codificado es más firme: 10 dp en la insignia de riesgo y 6 dp en la cápsula de ruta y la parada en el mapa, como un letrero.

Lo redondo señala o es de la comunidad: el botón de reportar, los botones sobre el mapa, el avatar, el punto de ubicación, el pin de reporte y el círculo suave detrás de cada ilustración. La píldora en vivo tiene extremos completamente redondos (24 dp sobre 48 dp de alto).

El pin de reporte es la silueta propia del sistema: una burbuja blanca redonda con aro de color y una punta (un cuadrado de 10 dp girado 45°) que marca el lugar exacto.

## Components

### Buttons
Grandes, blandos y a la medida del pulgar.
- **Shape:** esquinas de 18 dp; 56 dp de alto mínimo (64 dp de ancho mínimo). Texto en title-md.
- **Primary:** relleno verde agua con su tinta («Reintentar», «Reportar: el T103 no pasa»). Mientras envía, el texto cambia por un indicador de progreso en la tinta del acento.
- **Neutro:** relleno campo con texto principal, para la alternativa de igual peso («Ya no está»).
- **Sigue ahí:** relleno del color del grupo del reporte con la tinta que elige `tintaSobre` e ícono de pulgar arriba. Es el único botón que toma un color de código, porque responde sobre ese grupo.
- **Outlined:** contorno de 1,5 dp en el color del asa.
- **Text:** verde agua, 48 × 48 dp mínimo, label-lg.
- **Reportar (signature):** botón redondo de 64 dp en ámbar con ícono de megáfono de 30 dp en tinta sobre ámbar, elevación 8.

### Chips
- **Opción de respuesta:** 48 dp de alto y 64 de ancho mínimo, esquinas de 12 dp, relleno campo, title-sm con cifras tabulares. Elegida: fondo verde agua suave y borde verde agua de 2 dp (transición rápida, 180 ms). Hasta tres opciones se reparten una fila; más, bajan de renglón. Para «¿Qué ruta?» las opciones son las rutas de las estaciones cercanas más «Otra», que abre el campo del código.
- **Acceso guardado:** 46 dp de alto, esquinas de 14 dp, relleno tarjeta, ícono de 19 dp en el acento y nombre en title-sm. El de «Guardar un lugar» queda cuadrado, solo con el ícono. Mantener presionado abre la lista para editar.

### Cards / Containers
- **Corner Style:** 18 dp.
- **Background:** tarjeta dentro de una hoja; hoja cuando flota sobre el mapa.
- **Shadow Strategy:** ninguna en flujo; elevación 6 solo sobre el mapa.
- **Border:** ninguno.
- **Internal Padding:** 14 × 12 dp.
- **Tarjeta de estación:** recuadro de 40 dp en verde agua suave con el bus en el acento, «Estación …» en title-md, distancia y minutos a pie en body-sm tabular, cápsulas de ruta en su propia línea (máximo seis y «+N más») y chevrón.
- **Caja informativa:** tarjeta de 16 dp con ícono en el acento y texto en body-sm o body-md suave («Otros viajeros cerca verán tu reporte…», quién lo reportó y cuántos lo confirmaron). El aviso de agradecimiento usa el verde agua suave.

### Inputs / Fields
- **Style:** relleno campo, sin borde, esquinas de 16 dp; pista en body-lg suave.
- **Focus:** borde verde agua de 2 dp.
- **Error:** el color de seguridad, con su mensaje debajo.
- **Campo de destino (signature):** «¿A dónde vas?» es un botón con forma de campo: 58 dp de alto, esquinas de 18 dp, lupa de 26 dp en el acento y el texto en title-lg 700. Es lo primero de la hoja de inicio.

### Navigation
Pila de pantallas con barra superior plana en el color de la hoja (elevación 2 al desplazar) y título en title-lg. Sobre el mapa no hay barra: volver y ubicar son botones redondos de 48 dp en el color de la hoja. Los avisos usan un snackbar flotante en superficie inversa, esquinas de 14 dp, con la acción en verde agua.

### Pin de reporte (signature)
Burbuja blanca de 44 dp con aro de 3 dp en el color del grupo, la ilustración del tipo adentro (14 % de relleno) y la punta del mismo color debajo, que marca el lugar. Si la comunidad lo confirmó, una insignia arriba a la derecha (20 dp de alto, color de hoja, borde de grupo de 1,5 dp) muestra el número en 11 px 800. Al aparecer **cae** en su lugar: baja 18 dp mientras crece del 60 % al 100 % y aparece, con un rebote de salida. Fuera del recorrido que se está viendo queda al 45 % de opacidad. Tocarlo abre su detalle; el lector de pantalla dice el tipo, el lugar y cuántos lo confirmaron.

### Ilustraciones de reporte (signature)
Nueve dibujos SVG de 64 × 64 en tres grupos: servicio (el bus no pasa, bus lleno, estación cerrada), vía (trancón, accidente, calle inundada) y seguridad (robo, calle sola u oscura, acoso). Contorno en tinta azul noche de ≈ 2,2–2,4 dp con puntas redondas y rellenos planos tomados de la misma paleta (blanco, verde agua, ámbar, azul, coral). En la interfaz van sobre un círculo del color suave de su grupo, al 78 % del círculo; en el pin van sin círculo, sobre la burbuja blanca. En la cuadrícula de reporte **brotan** escalonadas (45 ms entre una y otra).

### Hoja de reporte
Paso 1, «¿Qué está pasando?»: título en headline-sm, debajo dónde caerá el reporte («Aquí: Estación Bazurto» o «En el centro del mapa») y un botón redondo de cerrar. Por cada grupo, un punto de 10 dp en su color y su nombre en title-sm suave, y una cuadrícula de tres columnas de celdas (tarjeta, 18 dp) con la ilustración de 64 dp y el nombre en label-lg 700. Paso 2: volver, la ilustración de 60 dp, el nombre del tipo y el lugar; cada pregunta en title-sm («opcional» en body-sm suave) con sus opciones; la caja de vigencia; y el botón principal que dice la frase completa del reporte, por ejemplo «Reportar: el T103 no pasa».

### Detalle de reporte
Ilustración de 68 dp, nombre en headline-sm, lugar y hace cuánto en body-md suave y el resumen de las respuestas en title-sm. Debajo, quién lo reportó y cuántos lo confirmaron, y la pregunta de la comunidad, «¿Sigue ahí?», con dos botones del mismo tamaño: «Sigue ahí» en el color del grupo y «Ya no está» neutro. Si el reporte es tuyo o ya votaste, la pregunta se cambia por un aviso. Al final, cuánto le queda visible.

### Píldora en vivo y avatar
- **Píldora «N reportes cerca»:** color de hoja, 48 dp de alto, elevación 6; un punto de 10 dp en verde en vivo que late cada 2,2 s (en el color del asa y quieto si no hay reportes) y el conteo en label-lg tabular. Al tocarla, el mapa encuadra esos reportes.
- **Avatar:** círculo de 48 dp en el color de hoja con anillo verde agua de 2 dp e iniciales en 800; abajo a la derecha, la insignia de nivel (22 dp, verde agua con su tinta, borde de hoja de 2 dp). Abre la hoja de perfil, con nivel, reputación y una barra de avance de 8 dp que se llena una vez.

### Mapa
- **Estilo «Bahía»:** MapLibre v8 sobre OpenFreeMap (esquema OpenMapTiles), generado por `tool/estilo_mapa.py`: tierra, agua, parques, edificios desde z15, tres jerarquías de vía (en el tema claro, blancas con borde de 1 dp) y solo tres tipos de etiqueta (nombres de vías principales, de agua en itálica y de barrios), con halo del color de la tierra.
- **Recorrido:** caminata en línea punteada de 5 dp en el color del texto; bus en línea de 6 dp del color de su ruta con halo de 2,5 dp. Se dibuja de origen a destino una vez.
- **Punto de ubicación:** 18 dp en el acento con borde blanco de 3 dp y una onda que sale cada 2,2 s.
- **Atribución:** «© OpenFreeMap · © colaboradores de OpenStreetMap» en label-sm suave, sobre la superficie al 85 %, siempre visible.

### Movimiento
Tres tiempos (rápido 180 ms, normal 320 ms, entrada 450 ms) y dos curvas: **rebote** (`cubic-bezier(0.3, 1.4, 0.5, 1)`) para lo que aparece y **suave** (`cubic-bezier(0.2, 0.8, 0.2, 1)`) para lo que cambia de lugar o de tamaño. Toda animación consulta `disableAnimations` del sistema: con movimiento reducido, los pines y las ilustraciones aparecen ya en su lugar, el punto en vivo y la onda de ubicación se quedan quietos, el recorrido aparece completo y los cambios de paso son instantáneos.

## Do's and Don'ts

### Do:
- **Do** leer cada color con `Bahia.de(context)` y definirlo en las dos paletas, con su prueba de contraste ≥ 4,5:1.
- **Do** usar el color del grupo solo para lo que pertenece a ese grupo: aro y punta del pin, círculo suave de la ilustración, punto del encabezado y el botón «Sigue ahí».
- **Do** poner texto sobre un relleno de grupo con `Bahia.tintaSobre`, y texto blanco sobre las cápsulas de ruta.
- **Do** acompañar cada código de color con su ilustración, su código escrito o su ícono y texto.
- **Do** poner todo lo táctil en la hoja inferior y dejar sobre el mapa solo avatar, píldora en vivo, ubicar y reportar.
- **Do** mantener 48 dp o más en todo lo que se toca (56 dp en botones rellenos, 64 dp en reportar).
- **Do** usar cifras tabulares en minutos, metros, conteos y códigos de ruta.
- **Do** respetar «reducir movimiento» en toda animación nueva, con `Movimiento.reducido(context)`.
- **Do** dejar visible la atribución de OpenFreeMap y OpenStreetMap en todo mapa.

### Don't:
- **Don't** usar los colores de grupo, de ruta o de riesgo como decoración, degradado o acento de marca.
- **Don't** usar el ámbar de reportar en otra acción, ni poner texto blanco sobre él.
- **Don't** presentar un riesgo sin datos como bajo o seguro.
- **Don't** poner sombra ni borde a una tarjeta que vive dentro de una hoja.
- **Don't** reemplazar el mapa propio por teselas genéricas o por un mapa claro invertido con un filtro de color.
- **Don't** añadir una segunda familia tipográfica ni bajar el cuerpo de 600.
- **Don't** dibujar un tipo de reporte con un ícono genérico cuando tiene ilustración propia.
