import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../../core/design/bahia.dart';
import '../../../../core/format.dart';
import '../../../../core/map/capa_bahia.dart';
import '../../../../core/widgets/karta_map.dart';
import '../../../../core/widgets/route_capsule.dart';
import '../../../mapeo/presentation/paraderos_de_ruta.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip_models.dart';

/// La página de una ruta de Transcaribe: su recorrido en el mapa, si opera ahora, su horario de la semana
/// y sus estaciones en el orden en que las recorre.
class RoutePageScreen extends StatefulWidget {
  final String codigo;

  const RoutePageScreen({super.key, required this.codigo});

  static Future<void> open(BuildContext context, String codigo) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoutePageScreen(codigo: codigo)));

  @override
  State<RoutePageScreen> createState() => _RoutePageScreenState();
}

class _RoutePageScreenState extends State<RoutePageScreen> {
  late Future<PaginaDeRuta> _pagina = context.read<TripRepository>().ruta(widget.codigo);

  void _reintentar() => setState(() => _pagina = context.read<TripRepository>().ruta(widget.codigo));

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    return Scaffold(
      backgroundColor: b.hoja,
      body: FutureBuilder<PaginaDeRuta>(
        future: _pagina,
        builder: (context, snap) {
          if (snap.hasError) return _Fallo(codigo: widget.codigo, mensaje: '${snap.error}', onReintentar: _reintentar);
          final pagina = snap.data;
          if (pagina == null) {
            return const Center(child: CircularProgressIndicator(semanticsLabel: 'Cargando la ruta'));
          }
          final alto = MediaQuery.sizeOf(context).height;
          return CustomScrollView(
            slivers: [
              // El mapa se pliega al bajar; queda fija una barra con «Volver» para que nada pase bajo la hora.
              SliverAppBar(
                pinned: true,
                expandedHeight: alto * 0.38,
                backgroundColor: b.hoja,
                surfaceTintColor: Colors.transparent,
                automaticallyImplyLeading: false,
                leadingWidth: 64,
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                  child: MapIconButton(icon: Icons.arrow_back, tooltip: 'Volver', onPressed: () => Navigator.of(context).pop()),
                ),
                flexibleSpace: FlexibleSpaceBar(background: _Mapa(pagina: pagina)),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 32 + MediaQuery.paddingOf(context).bottom),
                sliver: SliverList.list(children: [
                  _Cabecera(pagina: pagina),
                  const SizedBox(height: 24),
                  if (pagina.tieneHorario) _Horario(pagina: pagina) else const _SinHorario(),
                  const SizedBox(height: 24),
                  _Estaciones(pagina: pagina),
                  const SizedBox(height: 28),
                  ParaderosDeLaRuta(ruta: pagina.codigo, tipoRuta: pagina.tipo, recorrido: pagina.puntos),
                  const SizedBox(height: 24),
                  Text(
                    'Recorrido y estaciones: © colaboradores de OpenStreetMap (ODbL). Horarios: «Rutas_Transcaribe '
                    '2025», Portal de Datos Abiertos de Cartagena (CC-BY 4.0).',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: b.textoSuave),
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Mapa extends StatelessWidget {
  final PaginaDeRuta pagina;

  const _Mapa({required this.pagina});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final color = RouteCapsule.colorDe(pagina.tipo);
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            backgroundColor: fondoDelMapa(Theme.of(context).brightness),
            initialCameraFit: pagina.puntos.length > 1
                ? CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(pagina.puntos),
                    padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
                    minZoom: 11,
                  )
                : null,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            const CapaBahia(),
            PolylineLayer(polylines: [
              Polyline(points: pagina.puntos, strokeWidth: 6, color: color, borderStrokeWidth: 2.5, borderColor: b.bordeDeRuta),
            ]),
            MarkerLayer(markers: [
              for (final e in pagina.estaciones)
                Marker(
                  point: e.punto,
                  width: 18,
                  height: 18,
                  child: Semantics(
                    label: 'Estación ${e.nombre}',
                    child: Container(
                      decoration: BoxDecoration(
                        color: b.hoja,
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 4),
                      ),
                    ),
                  ),
                ),
            ]),
          ],
        ),
        const Positioned(right: 8, bottom: 8, child: AtribucionDelMapa()),
      ],
    );
  }
}

class _Cabecera extends StatelessWidget {
  final PaginaDeRuta pagina;

  const _Cabecera({required this.pagina});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            RouteCapsule(codigo: pagina.codigo, tipo: pagina.tipo, grande: true),
            const SizedBox(width: 10),
            Text(_tipoLegible(pagina.tipo), style: texto.titleSmall?.copyWith(color: b.textoSuave)),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(header: true, child: Text(recorridoDeRuta(pagina.nombre, pagina.codigo), style: texto.headlineSmall)),
        const SizedBox(height: 12),
        _EstadoDeHoy(pagina: pagina),
      ],
    );
  }

  static String _tipoLegible(String tipo) => switch (tipo) {
        'troncal' => 'Troncal',
        'pretroncal' => 'Pretroncal',
        'alimentadora' => 'Alimentadora',
        'complementaria' => 'Complementaria',
        _ => tipo,
      };
}

/// «Opera ahora · último despacho 9:00 p. m.», «Hoy abre a las 5:30 a. m.», «Hoy no opera».
class _EstadoDeHoy extends StatelessWidget {
  final PaginaDeRuta pagina;

  const _EstadoDeHoy({required this.pagina});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final hoy = pagina.horario[pagina.hoy];
    final (color, mensaje) = switch (pagina.operaAhora) {
      null => (b.asa, 'Transcaribe no publica el horario de esta ruta'),
      true => (b.enVivo, hoy != null ? 'Opera ahora · último despacho ${horaLegible(hoy.ultima)}' : 'Opera ahora'),
      false when hoy == null => (b.seguridad, 'Hoy no opera'),
      false => _antesDeAbrir(hoy!)
          ? (b.via, 'Hoy abre a las ${horaLegible(hoy.primera)}')
          : (b.seguridad, 'Ya no opera hoy · cerró a las ${horaLegible(hoy.ultima)}'),
    };
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(mensaje, style: texto.titleSmall)),
        ],
      ),
    );
  }

  static bool _antesDeAbrir(FranjaDeServicio franja) {
    final ahora = TimeOfDay.now();
    final partes = franja.primera.split(':');
    return ahora.hour * 60 + ahora.minute < int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }
}

class _Horario extends StatelessWidget {
  final PaginaDeRuta pagina;

  const _Horario({required this.pagina});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text('Horario', style: texto.titleLarge)),
        const SizedBox(height: 4),
        Text('Primer y último despacho desde la cabecera', style: texto.bodySmall?.copyWith(color: b.textoSuave)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: b.tarjeta, borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              for (final (k, dia) in diasDeServicio.indexed) ...[
                if (k > 0) Divider(height: 1, color: b.divisor, indent: 16, endIndent: 16),
                _FilaDeHorario(dia: dia, franja: pagina.horario[dia], esHoy: dia == pagina.hoy),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilaDeHorario extends StatelessWidget {
  final String dia;
  final FranjaDeServicio? franja;
  final bool esHoy;

  const _FilaDeHorario({required this.dia, required this.franja, required this.esHoy});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final valor = franja == null ? 'No opera' : '${horaLegible(franja!.primera)} – ${horaLegible(franja!.ultima)}';
    return Semantics(
      label: '${nombreDeDia[dia]}${esHoy ? ', hoy' : ''}: $valor',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              // En un teléfono angosto «Domingos y festivos» y «Hoy» no caben junto al horario: «Hoy» baja de línea.
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(nombreDeDia[dia]!, style: esHoy ? texto.titleSmall : texto.bodyMedium),
                  if (esHoy)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: b.acentoSuave, borderRadius: BorderRadius.circular(8)),
                      child: Text('Hoy', style: texto.labelMedium?.copyWith(color: b.acento)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              valor,
              style: (esHoy ? texto.titleSmall : texto.bodyMedium)?.copyWith(
                fontFeatures: tabularFigures,
                color: franja == null ? b.textoSuave : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SinHorario extends StatelessWidget {
  const _SinHorario();

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: b.tarjeta, borderRadius: BorderRadius.circular(18)),
      child: Text(
        'Transcaribe no publica el horario de esta ruta en sus datos abiertos. Karta la sugiere a cualquier hora.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: b.textoSuave),
      ),
    );
  }
}

/// Las estaciones en el orden del recorrido, sobre un riel del color de la ruta.
class _Estaciones extends StatelessWidget {
  final PaginaDeRuta pagina;

  const _Estaciones({required this.pagina});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final color = RouteCapsule.colorDe(pagina.tipo);
    if (pagina.estaciones.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text('Dónde se toma', style: texto.titleLarge)),
          const SizedBox(height: 6),
          Text(
            'Esta ruta va por vías compartidas y se toma en los paraderos de su recorrido. Al planificar un viaje, '
            'Karta te dice en qué cruce subir.',
            style: texto.bodyMedium?.copyWith(color: b.textoSuave),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            pagina.estaciones.length == 1 ? '1 estación' : '${pagina.estaciones.length} estaciones',
            style: texto.titleLarge,
          ),
        ),
        const SizedBox(height: 10),
        for (final (k, e) in pagina.estaciones.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Expanded(child: Container(width: 4, color: k == 0 ? Colors.transparent : color)),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: b.hoja,
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 4),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: 4,
                          color: k == pagina.estaciones.length - 1 ? Colors.transparent : color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text('Estación ${e.nombre}', style: texto.bodyLarge),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Fallo extends StatelessWidget {
  final String codigo;
  final String mensaje;
  final VoidCallback onReintentar;

  const _Fallo({required this.codigo, required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MapIconButton(icon: Icons.arrow_back, tooltip: 'Volver', onPressed: () => Navigator.of(context).pop()),
            const SizedBox(height: 24),
            Text('No pudimos abrir la ruta $codigo', style: texto.titleLarge),
            const SizedBox(height: 8),
            Text(mensaje, style: texto.bodyLarge?.copyWith(color: Bahia.de(context).textoSuave)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

/// El recorrido de una ruta sin repetir su tipo ni su código, que ya dice la cápsula:
/// «Pretroncal X105 - Ciudadela 2000 - Crisanto Luque - Bocagrande» → «Ciudadela 2000 · Crisanto Luque · Bocagrande».
String recorridoDeRuta(String nombre, String codigo) {
  final partes = nombre.split(RegExp(r'\s+-\s+')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  final numero = codigo.replaceAll(RegExp(r'[^0-9]'), '');
  if (partes.length > 1 && (partes.first.contains(codigo) || (numero.isNotEmpty && partes.first.contains(numero)))) {
    partes.removeAt(0);
  }
  return partes.join(' · ');
}
