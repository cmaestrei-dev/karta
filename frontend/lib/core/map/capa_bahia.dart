import 'package:flutter/material.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;

import '../design/apariencia.dart';

/// Fondo de la tierra mientras cargan las teselas, igual al del estilo para que no destelle.
const fondoDelMapaOscuro = Color(0xFF1E2C39);
const fondoDelMapaClaro = Color(0xFFEDF1F3);

Color fondoDelMapa(Brightness brillo) => brillo == Brightness.dark ? fondoDelMapaOscuro : fondoDelMapaClaro;

/// Los estilos «Bahía» (assets/mapa, generados por tool/estilo_mapa.py) se leen una sola vez por tema.
abstract final class EstilosDelMapa {
  static final _cache = <Brightness, Future<vt.Style>>{};

  static Future<vt.Style> de(Brightness brillo) => _cache.putIfAbsent(
        brillo,
        () => vt.StyleReader(
          uri: 'asset://assets/mapa/${brillo == Brightness.dark ? 'bahia_oscuro' : 'bahia_claro'}.json',
        ).read(),
      );
}

/// Mapa base vectorial con el estilo propio de Karta (OpenFreeMap). Va como primera capa de un FlutterMap.
class CapaBahia extends StatefulWidget {
  const CapaBahia({super.key});

  @override
  State<CapaBahia> createState() => _CapaBahiaState();
}

class _CapaBahiaState extends State<CapaBahia> {
  Brightness? _brillo;
  vt.Style? _estilo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brillo = Theme.of(context).brightness;
    if (brillo == _brillo) return;
    _brillo = brillo;
    EstilosDelMapa.de(brillo).then((estilo) {
      if (mounted && _brillo == brillo) setState(() => _estilo = estilo);
    }).catchError((_) {
      // Sin estilo el mapa queda con su fondo; el resto de la pantalla sigue funcionando.
    });
  }

  @override
  Widget build(BuildContext context) {
    final estilo = _estilo;
    if (estilo == null) return const SizedBox.shrink();
    final ligero = ModoLigero.de(context);
    return vt.VectorTileLayer(
      key: ValueKey((_brillo, ligero)),
      theme: estilo.theme,
      tileProviders: estilo.providers,
      rasterSources: estilo.rasterSources,
      sprites: estilo.sprites,
      // Modo ligero (D13): los nombres van dentro de cada tesela y no se redibujan en cada cuadro (el mapa no rota,
      // así que no se nota), con menos hilos decodificando y sin fundidos.
      labelMode: ligero ? vt.LabelMode.tile : vt.LabelMode.screen,
      concurrency: ligero ? 2 : 3,
      tileFadeDuration: ligero ? Duration.zero : const Duration(milliseconds: 150),
      labelFadeDuration: ligero ? Duration.zero : const Duration(milliseconds: 150),
    );
  }
}

/// Atribución obligatoria de los datos del mapa. Quien la usa decide dónde va, siempre visible.
class AtribucionDelMapa extends StatelessWidget {
  const AtribucionDelMapa({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surface.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text('© OpenFreeMap · © colaboradores de OpenStreetMap',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
      ),
    );
  }
}
