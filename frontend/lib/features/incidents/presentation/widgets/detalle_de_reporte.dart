import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/bahia.dart';
import '../../../../core/design/ilustracion.dart';
import '../../../../core/format.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/repositories/incident_repository.dart';
import '../../domain/models/incident_models.dart';
import '../bloc/incident_bloc.dart';
import '../cubit/report_cubits.dart';

/// Al tocar un reporte: qué es, dónde, quién lo reportó y la pregunta de la comunidad, «¿Sigue ahí?».
Future<void> mostrarDetalleDeReporte(BuildContext context, Incident incidente) {
  final repositorio = context.read<IncidentRepository>();
  final mapa = context.read<IncidentBloc>();
  final auth = context.read<AuthBloc>();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: auth),
        BlocProvider(
          create: (_) => IncidentDetailCubit(repository: repositorio, onRetirado: (id) => mapa.add(IncidentRetired(id)))
            ..cargar(incidente.id),
        ),
      ],
      child: _Detalle(inicial: incidente, catalogo: repositorio.catalogo()),
    ),
  );
}

class _Detalle extends StatelessWidget {
  final Incident inicial;
  final Future<CatalogoDeReportes> catalogo;

  const _Detalle({required this.inicial, required this.catalogo});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;

    return BlocConsumer<IncidentDetailCubit, IncidentDetailState>(
      listenWhen: (_, actual) => actual.sesionExpirada,
      listener: (context, _) {
        Navigator.of(context).pop();
        context.read<AuthBloc>().add(const LogoutRequested(message: 'Tu sesión expiró. Inicia sesión para validar reportes.'));
      },
      builder: (context, state) {
        final detalle = state.detalle;
        final incidente = detalle?.incidente ?? inicial;
        final tipo = incidente.ilustracion;
        final (colorGrupo, _) = b.delGrupo(incidente.grupo);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (tipo != null) Ilustracion(tipo, tamano: 68),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tipo?.nombre ?? 'Reporte', style: texto.headlineSmall),
                          Text(
                            [
                              if (incidente.lugar != null) incidente.lugar!,
                              if (incidente.creadoEn != null) haceCuanto(incidente.creadoEn!),
                            ].join(' · '),
                            style: texto.bodyMedium?.copyWith(color: b.textoSuave),
                          ),
                          FutureBuilder<CatalogoDeReportes>(
                            future: catalogo,
                            builder: (context, snap) {
                              final resumen = snap.data?.resumen(incidente) ?? '';
                              if (resumen.isEmpty) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(resumen, style: texto.titleSmall),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: b.tarjeta, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Icon(Icons.groups_outlined, color: b.acento),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_comunidad(detalle, incidente), style: texto.bodyMedium)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ..._validacion(context, state, colorGrupo),
                if (state.mensaje != null && !state.sesionExpirada)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(state.mensaje!, style: texto.bodyMedium?.copyWith(color: b.seguridad)),
                  ),
                if (incidente.expiraEn != null && state.estado != EstadoDelDetalle.retirado)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      incidente.votosSi > 0
                          ? 'Sigue visible ${dentroDe(incidente.expiraEn!)} más; cada confirmación lo renueva.'
                          : 'Si nadie lo confirma, desaparece en ${dentroDe(incidente.expiraEn!)}.',
                      textAlign: TextAlign.center,
                      style: texto.bodySmall?.copyWith(color: b.textoSuave),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _comunidad(IncidentDetail? detalle, Incident incidente) {
    final quien = detalle == null
        ? 'Lo reportó un viajero'
        : (detalle.esMio ? 'Lo reportaste tú' : 'Lo reportó ${detalle.aliasAutor}');
    final confirmaciones = switch (incidente.votosSi) {
      0 => 'nadie lo ha confirmado todavía',
      1 => 'lo confirmó 1 viajero',
      final n => 'lo confirmaron $n viajeros',
    };
    return '$quien · $confirmaciones';
  }

  List<Widget> _validacion(BuildContext context, IncidentDetailState state, Color colorGrupo) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final detalle = state.detalle;

    if (state.estado == EstadoDelDetalle.retirado) {
      return [_Aviso(icono: Icons.check_circle_outline, texto: 'Gracias. Con tu voto, este reporte sale del mapa.')];
    }
    if (detalle == null) {
      return [const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))];
    }
    if (detalle.esMio) {
      return [const _Aviso(icono: Icons.person_outline, texto: 'Es tu reporte: otros viajeros que pasen por aquí lo confirmarán.')];
    }
    if (detalle.miVoto != null) {
      return [
        _Aviso(
          icono: Icons.check_circle_outline,
          texto: detalle.miVoto! ? 'Confirmaste que sigue ahí. Gracias.' : 'Dijiste que ya no está. Gracias.',
        ),
      ];
    }

    final votando = state.estado == EstadoDelDetalle.votando;
    final cubit = context.read<IncidentDetailCubit>();
    return [
      Text('¿Sigue ahí?', style: texto.titleLarge),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: colorGrupo, foregroundColor: Bahia.tintaSobre(colorGrupo)),
              onPressed: votando ? null : () => cubit.votar(sigue: true),
              icon: const Icon(Icons.thumb_up_alt_outlined),
              label: const Text('Sigue ahí'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: b.campo, foregroundColor: b.texto),
              onPressed: votando ? null : () => cubit.votar(sigue: false),
              child: const Text('Ya no está'),
            ),
          ),
        ],
      ),
    ];
  }
}

class _Aviso extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Aviso({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: b.acentoSuave, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icono, color: b.acento),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
