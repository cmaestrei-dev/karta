# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

- **Primario:** viajero diario de Cartagena (trabajadores y estudiantes) que se mueve en Transcaribe y a pie. Necesita decidir rápido cómo ir y saber si el recorrido está complicado por tráfico o inseguridad.
- **Secundario:** turistas que no conocen la ciudad. Se atienden con nombres de sitios y estaciones reconocibles, pero no mandan en las decisiones de diseño.

## Product Purpose

Karta reduce la incertidumbre de moverse por Cartagena. Muestra los incidentes de tráfico y seguridad que reporta la comunidad, sugiere cómo llegar (a pie o caminata + una ruta de Transcaribe) y evalúa el riesgo de cada recorrido. Éxito: el viajero elige su ruta en segundos y con confianza, y reportar un incidente le toma tres toques.

## Positioning

Une las rutas reales de Transcaribe con los reportes de la comunidad para ordenar las opciones por tiempo **y** por riesgo. No es un mapa genérico ni un servicio de transporte privado.

## Operating Context

- Se usa en la calle, a pleno sol, muchas veces con una sola mano.
- Se consulta de pie dentro del bus en movimiento: lectura de un vistazo y controles grandes.
- Conexión móvil limitada o intermitente: la app debe tolerar cortes, mostrar estados claros y permitir reintentar.
- Es el proyecto de aula de Ingeniería de Servicios de Internet (Universidad de Cartagena, 2026-2) y se presenta a la docente.

## Capabilities and Constraints

- Funciones: registro e inicio de sesión; reportar incidente (Tráfico o Seguridad, intensidad 1–5, ubicación GPS); mapa de incidentes vigentes (expiran a las 3 h o 12 h); buscador de lugares y elegir un punto en el mapa; rutas sugeridas (a pie o con una ruta de Transcaribe, sin transbordos) con nivel de riesgo; estaciones cercanas; lugares guardados (máximo 10); escaneo de riesgo de una ruta.
- Solo cubre el área urbana de Cartagena de Indias.
- No integra servicios privados (Didi, Uber, InDriver) ni recomienda cambiarse a ellos.
- Los tiempos son estimaciones con velocidades promedio. No hay llegadas de buses en tiempo real, ni tarifas confirmadas, ni transbordos.
- Idioma: español de Colombia.
- App en Flutter (BLoC) con mapa de OpenStreetMap (flutter_map), que exige atribución visible. Backend FastAPI + MongoDB.

## Brand Commitments

- Nombre del producto: **Karta**.

## Evidence on Hand

- Datos reales de OpenStreetMap (ODbL) en `backend/data/`: 24 rutas de Transcaribe, 17 estaciones de la troncal y 453 lugares de Cartagena.
- Mockups de Figma y de servilleta de la primera entrega: inicio con "¿A dónde vas?", planificar ruta con opciones y vista de navegación. Sirven como inventario de pantallas, no como estilo obligatorio.
- No existen y no deben inventarse: horarios o llegadas en tiempo real, tarifas, testimonios, métricas de uso ni cifras de usuarios.

## Product Principles

1. **Decidir en segundos:** primero la respuesta (cómo ir, cuánto tarda, qué tan seguro) y después el detalle.
2. **Honestidad de los datos:** las estimaciones se presentan como estimaciones y la fuente se ve; nunca se simula tiempo real.
3. **La comunidad informa:** reportar debe ser más fácil que ignorar el incidente.
4. **Legible en la calle:** alto contraste, objetivos táctiles grandes, uso con una mano.
5. **Funciona con mala señal:** cada carga tiene estado, cada error tiene salida.

## Accessibility & Inclusion

- Contraste alto, pensado para luz solar directa.
- Objetivos táctiles de al menos 48 dp, alcanzables con el pulgar.
- El nivel de riesgo nunca se comunica solo con color: siempre va con ícono y texto.
- El texto respeta el tamaño de fuente del sistema.
