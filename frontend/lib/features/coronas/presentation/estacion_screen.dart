import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api_client.dart';
import '../../../core/design/bahia.dart';
import '../../../core/format.dart';
import '../../../core/widgets/route_capsule.dart';
import '../../places/domain/place_models.dart';
import '../../trip/domain/trip_models.dart';
import '../../trip/presentation/screens/plan_route_screen.dart';
import '../data/corona_repository.dart';
import '../domain/corona_models.dart';
import 'icono_de_corona.dart';
import 'poner_apodo_screen.dart';

const _meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre',
  'noviembre', 'diciembre'];

String _fecha(DateTime d) => '${d.day} de ${_meses[d.month - 1]}';

/// Una estación: sus rutas, cómo llegar y su corona (docs/plan-juego.md). El nombre oficial manda; el apodo del día
/// va debajo y nunca lo reemplaza.
class EstacionScreen extends StatefulWidget {
  final Stop estacion;

  const EstacionScreen({super.key, required this.estacion});

  static Future<void> open(BuildContext context, Stop estacion) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EstacionScreen(estacion: estacion)));

  @override
  State<EstacionScreen> createState() => _EstacionScreenState();
}

class _EstacionScreenState extends State<EstacionScreen> {
  CoronaDeEstacion? _corona;
  String? _error;

  CoronaRepository get _repo => context.read<CoronaRepository>();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final corona = await _repo.corona(widget.estacion.id);
      if (mounted) {
        setState(() {
          _corona = corona;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _participar() async {
    final si = await mostrarInvitacionACoronas(context);
    if (si == null) return;
    try {
      await _repo.ajustar(participa: si);
      await _cargar();
    } on ApiException catch (e) {
      _avisar(e.message);
    }
  }

  Future<void> _ponerApodo() async {
    final puesto = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => PonerApodoScreen(estacion: widget.estacion),
    ));
    if (puesto == true) await _cargar();
  }

  Future<void> _reportarApodo() async {
    final seguro = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('¿Reportar este apodo?'),
        content: const Text('Si tiene groserías, publicidad, política o algo que no va en una app para todo público, '
            'se oculta con los reportes de otros viajeros.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogo).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dialogo).pop(true), child: const Text('Reportar')),
        ],
      ),
    );
    if (seguro != true) return;
    try {
      final oculto = await _repo.reportarApodo(widget.estacion.id);
      _avisar(oculto ? 'Gracias: el apodo quedó oculto.' : 'Gracias: otros viajeros también lo revisarán.');
      await _cargar();
    } on ApiException catch (e) {
      _avisar(e.message);
    }
  }

  void _avisar(String texto) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final estacion = widget.estacion;
    final corona = _corona;
    final tu = corona?.tu;
    return Scaffold(
      appBar: AppBar(),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Text('Estación ${estacion.nombre}', style: texto.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('${metros(estacion.caminataM)} · ${minutos(estacion.caminataMin)} a pie',
                style: texto.bodyMedium?.copyWith(color: b.textoSuave, fontFeatures: tabularFigures)),
            if (corona?.apodo != null) ...[
              const SizedBox(height: 14),
              _ApodoDelDia(
                texto: corona!.apodo!,
                hasta: corona.apodoHasta,
                onReportar: tu != null && !corona.eresRey && !tu.reportasteElApodo ? _reportarApodo : null,
              ),
            ],
            const SizedBox(height: 14),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final ruta in estacion.rutas) RouteCapsule(codigo: ruta, tipo: tipoDeRuta(ruta)),
            ]),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => PlanRouteScreen.open(
                context,
                destino: TripPoint(nombre: 'Estación ${estacion.nombre}', punto: estacion.punto),
              ),
              icon: const Icon(Icons.directions),
              label: const Text('Cómo llegar'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: texto.bodySmall?.copyWith(color: b.textoSuave))
            else if (corona == null)
              const LinearProgressIndicator()
            else
              _TarjetaDeCorona(
                estacion: estacion.nombre,
                corona: corona,
                onParticipar: _participar,
                onPonerApodo: _ponerApodo,
              ),
          ],
        ),
      ),
    );
  }
}

/// «Hoy le dicen…»: el apodo que puso quien reina, debajo del nombre oficial.
class _ApodoDelDia extends StatelessWidget {
  final String texto;
  final DateTime? hasta;
  final VoidCallback? onReportar;

  const _ApodoDelDia({required this.texto, this.hasta, this.onReportar});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: b.viaSuave,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: b.reportar.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          IconoDeCorona(color: b.reportar),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              label: 'Hoy le dicen: $texto. Es el apodo del día que puso quien reina.',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // El dorado va en la corona: como texto, sobre el tema claro no se lee.
                  Text('Hoy le dicen', style: t.labelMedium?.copyWith(color: b.textoSuave, fontWeight: FontWeight.w700)),
                  Text('«$texto»', style: t.titleSmall),
                  if (hasta != null)
                    Text('Apodo del día · hasta ${cuandoSale(hasta!.toLocal()).toLowerCase()}',
                        style: t.bodySmall?.copyWith(color: b.textoSuave)),
                ],
              ),
            ),
          ),
          if (onReportar != null)
            TextButton(onPressed: onReportar, child: const Text('Reportar')),
        ],
      ),
    );
  }
}

class _TarjetaDeCorona extends StatelessWidget {
  final String estacion;
  final CoronaDeEstacion corona;
  final VoidCallback onParticipar;
  final VoidCallback onPonerApodo;

  const _TarjetaDeCorona(
      {required this.estacion, required this.corona, required this.onParticipar, required this.onPonerApodo});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final tu = corona.tu;
    final quien = corona.eresRey ? 'La tienes tú' : corona.rey == null ? 'Nadie reina todavía' : 'La tiene ${corona.rey}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: b.tarjeta, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: b.viaSuave, shape: BoxShape.circle),
                  child: IconoDeCorona(tamano: 24, color: corona.rey == null ? b.textoSuave : b.reportar),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('La corona de $estacion', style: texto.labelMedium?.copyWith(color: b.textoSuave)),
                      Text(quien, style: texto.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      if (corona.desde != null)
                        Text('Reina desde el ${_fecha(corona.desde!)}',
                            style: texto.bodySmall?.copyWith(color: b.textoSuave)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (tu != null) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: b.divisor),
            const SizedBox(height: 12),
            if (tu.participas != true)
              _Invitacion(onParticipar: onParticipar, yaDijoQueNo: tu.participas == false)
            else if (corona.eresRey)
              tu.puedesPonerApodo
                  ? FilledButton.icon(
                      onPressed: onPonerApodo,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Ponle el apodo del día'),
                    )
                  : Text(
                      tu.otroApodoDesde == null
                          ? 'Ya pusiste el apodo de esta semana.'
                          : 'Ya pusiste el apodo de esta semana. Puedes poner otro desde el ${_fecha(tu.otroApodoDesde!)}.',
                      style: texto.bodySmall?.copyWith(color: b.textoSuave),
                    )
            else
              _TuAvance(tu: tu),
          ],
          const SizedBox(height: 12),
          Text(
            'Cuentan tus reportes en la estación que otros confirman y tus votos acertados, uno por día. Estar aquí no '
            'suma. La corona se calcula cada madrugada con los últimos 30 días.',
            style: texto.bodySmall?.copyWith(color: b.textoSuave, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _TuAvance extends StatelessWidget {
  final TuCorona tu;

  const _TuAvance({required this.tu});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final faltan = tu.faltan ?? 0;
    final meta = tu.llevas + faltan;
    return Semantics(
      label: 'Llevas ${tu.llevas} ${tu.llevas == 1 ? 'día' : 'días'} de aportes este mes. '
          '${faltan == 0 ? 'Mañana la corona puede ser tuya' : 'Te faltan $faltan'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Llevas ${tu.llevas} ${tu.llevas == 1 ? 'día' : 'días'} de aportes',
                    style: texto.titleSmall),
              ),
              Text(faltan == 0 ? 'mañana puede ser tuya' : 'te faltan $faltan',
                  style: texto.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: meta == 0 ? 0 : tu.llevas / meta,
              minHeight: 8,
              color: b.reportar,
              backgroundColor: b.campo,
            ),
          ),
        ],
      ),
    );
  }
}

class _Invitacion extends StatelessWidget {
  final VoidCallback onParticipar;
  final bool yaDijoQueNo;

  const _Invitacion({required this.onParticipar, required this.yaDijoQueNo});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('¿Quieres competir por la corona?', style: texto.titleSmall),
        const SizedBox(height: 4),
        Text(
          yaDijoQueNo
              ? 'Dijiste que no participas. Puedes cambiarlo cuando quieras.'
              : 'Quien más días aporta en una estación le pone un apodo por un día.',
          style: texto.bodySmall?.copyWith(color: b.textoSuave),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: onParticipar, child: const Text('Ver cómo funciona')),
      ],
    );
  }
}

/// La pregunta para participar: es la autorización para esta finalidad (política 1.2, sección 5), así que dice
/// qué se guarda, por cuánto y cómo se deja. Devuelve la respuesta, o null si la cerró sin responder.
Future<bool?> mostrarInvitacionACoronas(BuildContext context) => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (hoja) {
        final b = Bahia.de(hoja);
        final texto = Theme.of(hoja).textTheme;
        Widget punto(IconData icono, String linea) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icono, size: 22, color: b.acento),
                const SizedBox(width: 12),
                Expanded(child: Text(linea, style: texto.bodyMedium?.copyWith(height: 1.4))),
              ]),
            );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: IconoDeCorona(tamano: 48, color: b.reportar)),
              const SizedBox(height: 8),
              Text('Rey o reina de la estación', textAlign: TextAlign.center, style: texto.titleLarge),
              const SizedBox(height: 16),
              punto(Icons.verified_outlined,
                  'Cuando otro viajero confirma un reporte tuyo en una estación, o la comunidad le da la razón a tu '
                  'voto, sumas un día. Quien más días suma en 30 días tiene la corona y le pone un apodo a la estación '
                  'por 24 horas.'),
              punto(Icons.event_outlined,
                  'Guardamos tu cuenta, la estación y el día, sin la hora ni el punto, por 31 días.'),
              punto(Icons.visibility_off_outlined,
                  'Si reinas, los demás te ven como «un karteño». Tu apodo de karteño se muestra solo si lo activas, '
                  'y nunca tu nombre.'),
              punto(Icons.toggle_off_outlined,
                  'Lo dejas cuando quieras en Perfil › Privacidad, y se borran tus aportes.'),
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => Navigator.of(hoja).pop(true),
                child: const Text('Participar'),
              ),
              TextButton(onPressed: () => Navigator.of(hoja).pop(false), child: const Text('No, gracias')),
            ],
          ),
        );
      },
    );
