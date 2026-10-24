import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/design/bahia.dart';
import '../../../../core/design/ilustracion.dart';
import '../../../../core/design/movimiento.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../places/data/places_repository.dart';
import '../../data/repositories/incident_repository.dart';
import '../../domain/models/incident_models.dart';
import '../cubit/report_cubits.dart';

/// Reportar en dos pasos: qué está pasando (un tipo ilustrado) y sus detalles concretos.
/// El reporte queda en [punto]; [esMiUbicacion] dice si es donde está el viajero o el centro del mapa.
/// [rutasCercanas] son las rutas de las estaciones cercanas, para responder «¿Qué ruta?» con un toque.
/// Devuelve el reporte creado, o null si el viajero cerró la hoja.
Future<Incident?> mostrarHojaDeReporte(
  BuildContext context, {
  required LatLng punto,
  required bool esMiUbicacion,
  List<String> rutasCercanas = const [],
}) {
  final repositorio = context.read<IncidentRepository>();
  final auth = context.read<AuthBloc>();
  final lugar = context
      .read<PlacesRepository>()
      .reverse(punto)
      .then<String?>((p) => p.nombre)
      .catchError((Object _) => null);

  return showModalBottomSheet<Incident>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: auth),
        BlocProvider(create: (_) => ReportCubit(repository: repositorio, punto: punto)..cargar()),
      ],
      child: _HojaDeReporte(lugar: lugar, esMiUbicacion: esMiUbicacion, rutasCercanas: rutasCercanas),
    ),
  );
}

class _HojaDeReporte extends StatelessWidget {
  final Future<String?> lugar;
  final bool esMiUbicacion;
  final List<String> rutasCercanas;

  const _HojaDeReporte({required this.lugar, required this.esMiUbicacion, required this.rutasCercanas});

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.sizeOf(context).height;
    final teclado = MediaQuery.viewInsetsOf(context).bottom;

    return BlocConsumer<ReportCubit, ReportState>(
      listenWhen: (antes, actual) =>
          actual.sesionExpirada || (actual.paso == PasoDeReporte.enviado && antes.paso != PasoDeReporte.enviado),
      listener: (context, state) {
        if (state.sesionExpirada) {
          Navigator.of(context).pop();
          context.read<AuthBloc>().add(const LogoutRequested(message: 'Tu sesión expiró. Inicia sesión para reportar.'));
        } else {
          Navigator.of(context).pop(state.creado);
        }
      },
      builder: (context, state) {
        final paso = switch (state.paso) {
          PasoDeReporte.cargando => const _Cargando(),
          PasoDeReporte.error => _Fallo(mensaje: state.mensaje),
          PasoDeReporte.eligiendo => _Eligiendo(
              key: const ValueKey('eligiendo'),
              catalogo: state.catalogo!,
              encabezado: _DondeEs(lugar: lugar, esMiUbicacion: esMiUbicacion, enLinea: true),
            ),
          _ => _Detallando(
              key: ValueKey('detallando-${state.tipo?.clave}'),
              state: state,
              rutasCercanas: rutasCercanas,
              donde: _DondeEs(lugar: lugar, esMiUbicacion: esMiUbicacion, enLinea: false),
            ),
        };
        return Padding(
          padding: EdgeInsets.only(bottom: teclado),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: alto * 0.9),
            child: AnimatedSize(
              duration: Movimiento.reducido(context) ? Duration.zero : Movimiento.normal,
              curve: Movimiento.suave,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: Movimiento.reducido(context) ? Duration.zero : Movimiento.normal,
                switchInCurve: Movimiento.suave,
                transitionBuilder: (hijo, animacion) {
                  final entra = hijo.key == const ValueKey('eligiendo') ? -1.0 : 1.0;
                  return FadeTransition(
                    opacity: animacion,
                    child: SlideTransition(
                      position: Tween(begin: Offset(0.12 * entra, 0), end: Offset.zero).animate(animacion),
                      child: hijo,
                    ),
                  );
                },
                layoutBuilder: (actual, anteriores) =>
                    Stack(alignment: Alignment.topCenter, children: [...anteriores, ?actual]),
                child: paso,
              ),
            ),
          ),
        );
      },
    );
  }
}

const _sinNombre = 'Punto seleccionado en el mapa';

/// «Aquí: Estación Bazurto». Si no hay GPS, deja claro que el reporte va en el centro del mapa.
class _DondeEs extends StatelessWidget {
  final Future<String?> lugar;
  final bool esMiUbicacion;
  final bool enLinea;

  const _DondeEs({required this.lugar, required this.esMiUbicacion, required this.enLinea});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final estilo = Theme.of(context).textTheme.bodyMedium?.copyWith(color: b.textoSuave);
    return FutureBuilder<String?>(
      future: lugar,
      builder: (context, snap) {
        // Sin un lugar conocido cerca, el backend responde «Punto seleccionado en el mapa»: no aporta nada aquí.
        final nombre = snap.data == _sinNombre ? null : snap.data;
        final prefijo = esMiUbicacion ? 'Aquí' : 'En el centro del mapa';
        final texto = switch (snap.connectionState) {
          ConnectionState.done when nombre != null => '$prefijo: $nombre',
          ConnectionState.done => esMiUbicacion ? 'Aquí, donde estás ahora' : prefijo,
          _ => esMiUbicacion ? 'Buscando dónde estás…' : prefijo,
        };
        if (!enLinea) return Text(texto, style: estilo, maxLines: 2, overflow: TextOverflow.ellipsis);
        return Row(
          children: [
            Icon(Icons.place_outlined, size: 18, color: b.acento),
            const SizedBox(width: 4),
            Flexible(child: Text(texto, style: estilo, maxLines: 2, overflow: TextOverflow.ellipsis)),
          ],
        );
      },
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final VoidCallback onPressed;

  const _BotonRedondo({required this.icono, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(backgroundColor: b.campo, foregroundColor: b.texto, fixedSize: const Size(48, 48)),
      icon: Icon(icono, size: 22),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator(semanticsLabel: 'Cargando los tipos de reporte')),
      );
}

class _Fallo extends StatelessWidget {
  final String? mensaje;

  const _Fallo({this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('No pudimos abrir los reportes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(mensaje ?? 'Revisa tu conexión e inténtalo de nuevo.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => context.read<ReportCubit>().cargar(), child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- paso 1: ¿qué está pasando?

class _Eligiendo extends StatelessWidget {
  final CatalogoDeReportes catalogo;
  final Widget encabezado;

  const _Eligiendo({super.key, required this.catalogo, required this.encabezado});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    var indice = 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text('¿Qué está pasando?', style: texto.headlineSmall)),
                    const SizedBox(height: 4),
                    encabezado,
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _BotonRedondo(icono: Icons.close, tooltip: 'Cerrar', onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          for (final grupo in catalogo.grupos) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: b.delGrupo(grupo.clave).$1, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Semantics(
                  header: true,
                  child: Text(grupo.nombre, style: texto.titleSmall?.copyWith(color: b.textoSuave)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                // Alto fijo (ilustración y dos renglones de nombre) que crece solo con la letra: en horizontal
                // las celdas no se agigantan y con letra grande el nombre nunca queda cortado.
                mainAxisExtent: 92 + 34 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
              ),
              children: [
                for (final tipo in grupo.tipos)
                  _CeldaDeTipo(tipo: tipo, retraso: Duration(milliseconds: 45 * indice++)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CeldaDeTipo extends StatelessWidget {
  final TipoDeReporte tipo;
  final Duration retraso;

  const _CeldaDeTipo({required this.tipo, required this.retraso});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final ilustracion = tipo.ilustracion;
    final radio = BorderRadius.circular(18);
    return Semantics(
      button: true,
      label: tipo.nombre,
      excludeSemantics: true,
      child: Material(
        color: b.tarjeta,
        borderRadius: radio,
        child: InkWell(
          borderRadius: radio,
          onTap: () => context.read<ReportCubit>().elegir(tipo),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Brote(
                  retraso: retraso,
                  child: ilustracion != null
                      ? Ilustracion(ilustracion, tamano: 64)
                      : CircleAvatar(
                          radius: 32,
                          backgroundColor: b.delGrupo(tipo.grupo).$2,
                          child: Icon(Icons.campaign_outlined, color: b.delGrupo(tipo.grupo).$1),
                        ),
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: Text(
                    tipo.nombre,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- paso 2: los detalles

class _Detallando extends StatefulWidget {
  final ReportState state;
  final List<String> rutasCercanas;
  final Widget donde;

  const _Detallando({super.key, required this.state, required this.rutasCercanas, required this.donde});

  @override
  State<_Detallando> createState() => _DetallandoState();
}

class _DetallandoState extends State<_Detallando> {
  /// Campos de ruta en los que el viajero eligió «Otra» y escribe el código.
  final _escribiendo = <String>{};

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final state = widget.state;
    final tipo = state.tipo!;
    final cubit = context.read<ReportCubit>();
    final enviando = state.paso == PasoDeReporte.enviando;
    final ilustracion = tipo.ilustracion;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _BotonRedondo(icono: Icons.arrow_back, tooltip: 'Volver a los tipos de reporte', onPressed: cubit.volver),
              const SizedBox(width: 12),
              if (ilustracion != null) Brote(child: Ilustracion(ilustracion, tamano: 60)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(tipo.nombre, style: texto.headlineSmall)),
                    widget.donde,
                  ],
                ),
              ),
            ],
          ),
          for (final campo in tipo.campos) ...[
            const SizedBox(height: 18),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: campo.pregunta),
                if (!campo.obligatorio)
                  TextSpan(text: '  opcional', style: texto.bodySmall?.copyWith(color: b.textoSuave)),
              ]),
              style: texto.titleSmall,
            ),
            const SizedBox(height: 8),
            if (campo.esRuta) _preguntaDeRuta(campo, state) else _preguntaDeOpciones(campo, state),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: b.tarjeta, borderRadius: BorderRadius.circular(16)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.schedule, size: 20, color: b.acento),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Otros viajeros cerca verán tu reporte y podrán confirmarlo. '
                    'Si nadie lo confirma, desaparece en ${tipo.vigenciaEnPalabras}.',
                    style: texto.bodySmall?.copyWith(color: b.textoSuave),
                  ),
                ),
              ],
            ),
          ),
          if (state.mensaje != null) ...[
            const SizedBox(height: 12),
            Text(state.mensaje!, style: texto.bodyMedium?.copyWith(color: b.seguridad)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: state.completo && !enviando ? cubit.enviar : null,
            child: enviando
                ? SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3, color: b.sobreAcento))
                : Text('Reportar: ${tipo.fraseDeEnvio(state.respuestas)}', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _preguntaDeOpciones(CampoDeReporte campo, ReportState state) {
    final cubit = context.read<ReportCubit>();
    final elegida = state.respuestas[campo.clave];
    final opciones = [
      for (final o in campo.opciones)
        _Opcion(etiqueta: o.etiqueta, elegida: elegida == o.valor, onTap: () => cubit.responder(campo.clave, o.valor)),
    ];
    // Hasta tres respuestas caben en una fila pareja; más, bajan de renglón.
    if (opciones.length <= 3 && MediaQuery.textScalerOf(context).scale(1) <= 1.3) {
      return Row(
        children: [
          for (var i = 0; i < opciones.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: opciones[i]),
          ],
        ],
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: opciones);
  }

  Widget _preguntaDeRuta(CampoDeReporte campo, ReportState state) {
    final cubit = context.read<ReportCubit>();
    final elegida = state.respuestas[campo.clave];
    final cercanas = widget.rutasCercanas.take(8).toList();
    final escribiendo = _escribiendo.contains(campo.clave) || cercanas.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cercanas.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ruta in cercanas)
                _Opcion(
                  etiqueta: ruta,
                  elegida: !escribiendo && elegida == ruta,
                  onTap: () {
                    setState(() => _escribiendo.remove(campo.clave));
                    cubit.responder(campo.clave, ruta);
                  },
                ),
              _Opcion(
                etiqueta: 'Otra',
                elegida: escribiendo,
                onTap: () {
                  setState(() => _escribiendo.add(campo.clave));
                  cubit.escribir(campo.clave, '');
                },
              ),
            ],
          ),
        if (escribiendo) ...[
          if (cercanas.isNotEmpty) const SizedBox(height: 10),
          _CodigoDeRuta(onCambio: (codigo) => cubit.escribir(campo.clave, patronDeRuta.hasMatch(codigo) ? codigo : '')),
        ],
      ],
    );
  }
}

class _CodigoDeRuta extends StatefulWidget {
  final ValueChanged<String> onCambio;

  const _CodigoDeRuta({required this.onCambio});

  @override
  State<_CodigoDeRuta> createState() => _CodigoDeRutaState();
}

class _CodigoDeRutaState extends State<_CodigoDeRuta> {
  final _control = TextEditingController();

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final codigo = _control.text.trim().toUpperCase();
    final invalido = codigo.length >= 4 && !patronDeRuta.hasMatch(codigo);
    return TextField(
      controller: _control,
      autofocus: true,
      textCapitalization: TextCapitalization.characters,
      maxLength: 5,
      decoration: InputDecoration(
        labelText: 'Código de la ruta',
        hintText: 'Ej. T103, X104, A110',
        counterText: '',
        errorText: invalido ? 'Escribe el código del letrero del bus, como T103.' : null,
      ),
      onChanged: (valor) {
        setState(() {});
        widget.onCambio(valor.trim().toUpperCase());
      },
    );
  }
}

/// Una respuesta como ficha: la elegida lleva el borde y el fondo del acento.
class _Opcion extends StatelessWidget {
  final String etiqueta;
  final bool elegida;
  final VoidCallback onTap;

  const _Opcion({required this.etiqueta, required this.elegida, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final radio = BorderRadius.circular(12);
    return Semantics(
      button: true,
      selected: elegida,
      label: etiqueta,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radio,
          onTap: onTap,
          child: AnimatedContainer(
            duration: Movimiento.rapido,
            constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: elegida ? b.acentoSuave : b.campo,
              borderRadius: radio,
              border: Border.all(color: elegida ? b.acento : Colors.transparent, width: 2),
            ),
            // Mide lo que su texto en una fila de fichas; dentro de un Expanded ocupa su parte y centra el texto.
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                etiqueta,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontFeatures: tabularFigures),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
