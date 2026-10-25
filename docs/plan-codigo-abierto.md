# Plan: Karta como código abierto

**Estado:** decidido el 24 de octubre de 2026 (licencias aplicadas en el repositorio).

## 1. Decisiones

| Tema | Decisión |
|---|---|
| Repositorio | **Público** ([cmaestrei-dev/karta](https://github.com/cmaestrei-dev/karta)) |
| Servidor (`backend/`) | **GNU AGPL 3.0 o posterior** |
| App (`frontend/`) | **Apache 2.0** |
| Documentación | **CC BY 4.0** |
| Titular | **Camilo Andres Maestre Iglesias**, dueño del código, de la documentación y de la idea. José Herrera Gómez colabora en el proyecto del curso. |
| Contribuciones | Con el [acuerdo de contribución](acuerdo-de-contribucion.md) |

**Por qué mantenerlo público:**
- sirve como portafolio y para el curso;
- la privacidad se puede comprobar: cualquiera puede ver que no se guardan ubicaciones;
- la ventaja de Karta no es el código, sino la comunidad y los datos que genera.

## 2. Por qué estas licencias

- **AGPL en el servidor.** Si alguien monta un servidor de Karta modificado y lo ofrece a otros, tiene que publicar su código. Así nadie puede tomar Karta, mejorarlo y cerrarlo como servicio propio.
  - **Obligación para Karta (sección 13 de la AGPL):** los usuarios que interactúan con el servidor deben poder obtener su código. Por eso el enlace al código aparece en la documentación de la API y en «Acerca de Karta» dentro de la app.
- **Apache 2.0 en la app.** Es permisiva, incluye una licencia de patentes y es compatible con las tiendas.
  - Las licencias GPL, incluida la AGPL, [chocan con los términos de la App Store de Apple](https://www.engadget.com/2011-01-09-the-gpl-the-app-store-and-you.html): VLC fue retirada de la App Store por eso.
- **Compatibilidad de las dependencias** (revisada el 24 de octubre):
  - las del servidor (FastAPI, Pydantic, PyMongo, Shapely, pyproj, PyJWT, pwdlib, Uvicorn) son MIT, BSD o Apache, compatibles con la AGPL;
  - las de la app (Flutter, flutter_bloc, flutter_map, geolocator, etc.) son MIT, BSD o Apache, compatibles con Apache 2.0.

## 3. Titularidad y contribuciones

- **Hoy todo el código es de Camilo:** los 58 commits del repositorio son suyos.
- **Las obras de otras personas son de ellas aunque estén en el repositorio.** Para que Karta pueda cambiar de licencia en el futuro (por ejemplo, a una versión privada), cada colaborador acepta el [acuerdo de contribución](acuerdo-de-contribucion.md): conserva la autoría, pero le da al titular permiso amplio para relicenciar.
- **José:** si aportó textos, diagramas o diseños a las entregas, conviene que firme el acuerdo cubriendo esos aportes anteriores, para que no quede ninguna duda.
- **Universidad:** antes de explotar Karta comercialmente, hay que revisar el estatuto de propiedad intelectual de la Universidad de Cartagena para las obras hechas en cursos, y hablarlo con la docente.
- **Ley colombiana:** la cesión de derechos patrimoniales de autor debe constar por escrito (Ley 23 de 1982, modificada por la Ley 1450 de 2011). Los derechos morales (ser reconocido como autor) no se ceden.

## 4. Qué nunca va al repositorio

| Secreto | Estado |
|---|---|
| `backend/.env` (claves de producción) | Ignorado por git; `backend/.env.example` documenta las variables |
| Llave de firma de la app (`*.jks`, `*.keystore`, `key.properties`) | Ignorada por git. **Si se pierde, no se puede volver a actualizar la app en Google Play**: se guarda en dos lugares seguros fuera del repositorio |
| Claves de `docker-compose.yml` (secreto JWT, clave de MongoDB, cuenta demo) | **Solo sirven para desarrollo y ya son públicas.** Producción usa otras, por variables de entorno del servidor |
| Llaves de servicios externos (TomTom, tiendas) | Variables de entorno, nunca en el código |

Los valores contra el abuso (límites de peticiones, pesos de la reputación) están a la vista en el código. Esconderlos no los haría más seguros. Si hiciera falta, se ajustan por variables de entorno sin cambiar el código.

## 5. Datos y recursos de terceros

| Recurso | Licencia | Qué exige |
|---|---|---|
| Rutas, estaciones, lugares y cruces (OpenStreetMap) | ODbL 1.0 | Atribución y compartir con la misma licencia la base derivada (`backend/data/*.json`) |
| Horarios (Datos Abiertos de Cartagena) | CC BY 4.0 | Atribución (está en `backend/data/horarios.json`) |
| Mapa de fondo (OpenFreeMap) | Datos de OpenStreetMap | La atribución visible en el mapa |
| Letra Manrope | SIL OFL 1.1 | Incluir la licencia con la app (aparece en «Acerca de Karta» › licencias) |

## 6. Publicar en las tiendas

El código abierto no impide publicar. No se necesita ninguna certificación. Lo que sí hace falta:

**Google Play**
- **Cuenta de desarrollador:** pago único de USD 25.
- **Prueba cerrada antes de publicar:** con una cuenta personal creada después del 13 de noviembre de 2023, [12 personas durante 14 días seguidos](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en). Encaja con el piloto de la fase 4. Una cuenta de organización (con número D-U-N-S) no tiene ese requisito.
- **Política de privacidad** en una URL pública y el formulario de **seguridad de los datos**.
- **Declaración del servicio en primer plano de ubicación**, que usa el viaje activo, con un video corto que muestre para qué sirve.

**App Store (más adelante)**
- Programa de desarrolladores: USD 99 al año.
- La app va en Apache 2.0, así que no hay problema de licencia.

## 7. ¿Pasar a privado algún día?

- **Se puede**, pero lo que ya se publicó queda en las copias que otros hayan hecho bajo la licencia que tenían.
- **Si algún día hay una parte cerrada**, por ejemplo el tablero de analítica para entidades del [plan de sostenibilidad](plan-sostenibilidad.md), vive en un repositorio privado aparte, y el servidor y la app siguen abiertos (modelo *open core*).

## 8. Pendientes

1. **José:** firma del acuerdo de contribución por sus aportes anteriores.
2. **Universidad:** revisar el estatuto de propiedad intelectual.
3. **Política de tratamiento de datos** publicada antes del piloto (fase 4).

## Fuentes

- [App testing requirements for new personal developer accounts — Play Console Help](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [The GPL, the App Store, and you — Engadget](https://www.engadget.com/2011-01-09-the-gpl-the-app-store-and-you.html)
- [The GPL and the iOS App Store — Michel Fortin](https://michelf.ca/blog/2011/gpl-ios-app-store/)
