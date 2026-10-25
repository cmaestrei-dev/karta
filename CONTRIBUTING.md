# Cómo contribuir a Karta

Gracias por querer ayudar. Karta es el tiempo real de Transcaribe hecho por sus pasajeros: cada aporte tiene que cuidar a esas personas.

## Antes de tu primer aporte

- **Acepta el [acuerdo de contribución](docs/acuerdo-de-contribucion.md)** escribiendo en tu primer pull request «Acepto el Acuerdo de Contribución de Karta, versión 1.0» con tu nombre completo. Sigues siendo autor, pero le das al titular permiso para cambiar la licencia en el futuro.
  - Versión 1.0, SHA-256 `a8d0f76b7941c37476d728823f6c6d090b4b1403a74f162ddac53932e3dd437c`.
- **Si usaste inteligencia artificial** para escribir parte de tu aporte, dilo en el pull request (cláusula 7 del acuerdo).
- **Lee el [plan de reconstrucción](docs/plan-reconstruccion.md)**, que dice en qué fase va el proyecto y por qué se decidió cada cosa.

## Reglas que no se negocian

- **Privacidad (Ley 1581):**
  - nunca guardes ni registres en logs la ubicación de una persona ni su historial;
  - lo que se comparte de los viajes es anónimo y vence solo.
- **Sin anuncios y sin transporte privado** (apps de taxi o de viajes en carro particular). Karta es para el transporte público.
- **Ningún secreto en el repositorio:** contraseñas, tokens, llaves de firma (`*.jks`, `key.properties`) y archivos `.env` van fuera. `backend/.env.example` documenta las variables.

## Cómo se trabaja

- **Una rama y un PR por cambio**, con commits convencionales en inglés: `feat(trip): ...`, `fix(incidents): ...`.
- **Pruebas en verde antes del PR:**
  - backend: `KARTA_EXIGIR_MONGO=1 .venv/bin/python -m pytest -q`, con MongoDB arriba (`docker compose up -d mongo`);
  - app: `flutter analyze` y `flutter test`.
- **Una prueba por cada regla nueva** del dominio (votos, vigencias, transbordos, estimaciones).
- **Textos de la app en español de Colombia**, claros y cortos. El diseño sigue [DESIGN.md](DESIGN.md).

## Licencias

Tu aporte al servidor (`backend/`) queda bajo la AGPL 3.0 o posterior. Tu aporte a la app (`frontend/`) queda bajo la Apache 2.0. Ver [LICENSE.md](LICENSE.md).
