# Licencias de Karta

Karta es código abierto. Copyright © 2026 Camilo Andres Maestre Iglesias ([cmaestrei-dev](https://github.com/cmaestrei-dev)), titular del código, de la documentación y de la idea.

| Parte | Licencia | Archivo |
|---|---|---|
| Servidor (`backend/`) | **GNU AGPL 3.0 o posterior** (`AGPL-3.0-or-later`) | [backend/LICENSE](backend/LICENSE) |
| App (`frontend/`) | **Apache 2.0** (`Apache-2.0`) | [frontend/LICENSE](frontend/LICENSE) y [frontend/NOTICE](frontend/NOTICE) |
| Documentación (`docs/`, `README.md`, `DESIGN.md`, `PRODUCT.md`, diagramas) | **Creative Commons Atribución 4.0** (`CC-BY-4.0`) | [docs/LICENSE](docs/LICENSE) |
| Datos de terceros (`backend/data/`) | Los de su fuente; ver abajo | — |

**Por qué dos licencias** (detalles en [docs/plan-codigo-abierto.md](docs/plan-codigo-abierto.md)):
- **Servidor en AGPL:** quien monte un servidor de Karta modificado y lo ofrezca a otros tiene que publicar sus cambios. Así nadie puede cerrar una copia mejorada del servicio.
- **App en Apache 2.0:** es permisiva y compatible con las tiendas de aplicaciones. Las licencias de la familia GPL chocan con los términos de la App Store de Apple.
- **Documentación en CC BY 4.0:** cualquiera puede reutilizar los planes, diagramas y textos citando a Karta y a su autor.
  - Para atribuir, usa esta forma: «Karta, de Camilo Andres Maestre Iglesias, CC BY 4.0, https://github.com/cmaestrei-dev/karta».
  - Las capturas con mapas incluyen datos de OpenStreetMap, que siguen bajo la ODbL.

**Datos de terceros**, que no son de Karta y conservan su licencia:
- **Rutas, estaciones, lugares y cruces:** © colaboradores de OpenStreetMap, bajo la [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/). Las bases derivadas se comparten con la misma licencia.
- **Horarios:** «Rutas_Transcaribe 2025», Transcaribe S.A., Portal de Datos Abiertos de Cartagena, bajo [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- **Mapa de fondo:** teselas de OpenFreeMap con datos de OpenStreetMap; la atribución se muestra en el mapa.
- **Letra Manrope:** [SIL Open Font License 1.1](frontend/assets/fonts/OFL-Manrope.txt).

**Contribuir:** quien quiera aportar acepta primero el [acuerdo de contribución](docs/acuerdo-de-contribucion.md). Ver [CONTRIBUTING.md](CONTRIBUTING.md).
