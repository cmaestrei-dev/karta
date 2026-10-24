import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/api_errors.dart';
import '../../data/repositories/incident_repository.dart';
import '../../domain/models/incident_models.dart';

// ---------------------------------------------------------------- reportar en dos pasos

enum PasoDeReporte { cargando, eligiendo, detallando, enviando, enviado, error }

class ReportState extends Equatable {
  final PasoDeReporte paso;
  final CatalogoDeReportes? catalogo;
  final TipoDeReporte? tipo;
  final Map<String, String> respuestas;
  final Incident? creado;
  final String? mensaje;
  final bool sesionExpirada;

  const ReportState({
    this.paso = PasoDeReporte.cargando,
    this.catalogo,
    this.tipo,
    this.respuestas = const {},
    this.creado,
    this.mensaje,
    this.sesionExpirada = false,
  });

  /// Están respondidas todas las preguntas obligatorias del tipo elegido.
  bool get completo =>
      tipo != null &&
      tipo!.campos.where((c) => c.obligatorio).every((c) => (respuestas[c.clave] ?? '').isNotEmpty);

  ReportState copyWith({
    PasoDeReporte? paso,
    CatalogoDeReportes? catalogo,
    TipoDeReporte? tipo,
    bool quitarTipo = false,
    Map<String, String>? respuestas,
    Incident? creado,
    String? mensaje,
    bool sesionExpirada = false,
  }) =>
      ReportState(
        paso: paso ?? this.paso,
        catalogo: catalogo ?? this.catalogo,
        tipo: quitarTipo ? null : (tipo ?? this.tipo),
        respuestas: respuestas ?? this.respuestas,
        creado: creado ?? this.creado,
        mensaje: mensaje,
        sesionExpirada: sesionExpirada,
      );

  @override
  List<Object?> get props => [paso, catalogo, tipo, respuestas, creado, mensaje, sesionExpirada];
}

/// Paso 1: elegir qué pasa (un tipo ilustrado). Paso 2: responder sus preguntas concretas y enviar.
class ReportCubit extends Cubit<ReportState> {
  final IncidentRepository repository;
  final LatLng punto;

  ReportCubit({required this.repository, required this.punto}) : super(const ReportState());

  Future<void> cargar() async {
    emit(state.copyWith(paso: PasoDeReporte.cargando));
    try {
      emit(state.copyWith(paso: PasoDeReporte.eligiendo, catalogo: await repository.catalogo()));
    } catch (e) {
      emit(state.copyWith(paso: PasoDeReporte.error, mensaje: e.toString()));
    }
  }

  void elegir(TipoDeReporte tipo) =>
      emit(state.copyWith(paso: PasoDeReporte.detallando, tipo: tipo, respuestas: const {}));

  /// Tocar la opción ya elegida la quita (las preguntas opcionales se pueden dejar en blanco).
  void responder(String campo, String valor) {
    final respuestas = Map<String, String>.of(state.respuestas);
    if (respuestas[campo] == valor) {
      respuestas.remove(campo);
    } else {
      respuestas[campo] = valor;
    }
    emit(state.copyWith(respuestas: respuestas));
  }

  /// Respuesta escrita (una ruta que no está entre las cercanas): vacía la quita.
  void escribir(String campo, String valor) {
    final respuestas = Map<String, String>.of(state.respuestas);
    final limpio = valor.trim().toUpperCase();
    if (limpio.isEmpty) {
      respuestas.remove(campo);
    } else {
      respuestas[campo] = limpio;
    }
    emit(state.copyWith(respuestas: respuestas));
  }

  void volver() => emit(state.copyWith(paso: PasoDeReporte.eligiendo, quitarTipo: true, respuestas: const {}));

  Future<void> enviar() async {
    final tipo = state.tipo;
    if (tipo == null || !state.completo || state.paso == PasoDeReporte.enviando) return;
    emit(state.copyWith(paso: PasoDeReporte.enviando));
    try {
      final creado = await repository.report(tipo: tipo.clave, detalles: state.respuestas, punto: punto);
      emit(state.copyWith(paso: PasoDeReporte.enviado, creado: creado));
    } on SessionExpiredException catch (e) {
      emit(state.copyWith(paso: PasoDeReporte.detallando, mensaje: e.toString(), sesionExpirada: true));
    } catch (e) {
      emit(state.copyWith(paso: PasoDeReporte.detallando, mensaje: e.toString()));
    }
  }
}

// ---------------------------------------------------------------- detalle y «¿Sigue ahí?»

enum EstadoDelDetalle { cargando, listo, votando, retirado, error }

class IncidentDetailState extends Equatable {
  final EstadoDelDetalle estado;
  final IncidentDetail? detalle;
  final String? mensaje;
  final bool sesionExpirada;

  const IncidentDetailState({
    this.estado = EstadoDelDetalle.cargando,
    this.detalle,
    this.mensaje,
    this.sesionExpirada = false,
  });

  @override
  List<Object?> get props => [estado, detalle, mensaje, sesionExpirada];
}

class IncidentDetailCubit extends Cubit<IncidentDetailState> {
  final IncidentRepository repository;

  /// Avisa al mapa que el reporte salió (la comunidad lo desmintió) para quitarlo enseguida.
  final void Function(String id)? onRetirado;

  IncidentDetailCubit({required this.repository, this.onRetirado}) : super(const IncidentDetailState());

  Future<void> cargar(String id) async {
    emit(const IncidentDetailState());
    try {
      emit(IncidentDetailState(estado: EstadoDelDetalle.listo, detalle: await repository.detail(id)));
    } catch (e) {
      emit(IncidentDetailState(estado: EstadoDelDetalle.error, mensaje: e.toString()));
    }
  }

  Future<void> votar({required bool sigue}) async {
    final detalle = state.detalle;
    if (detalle == null || !detalle.puedeVotar || state.estado == EstadoDelDetalle.votando) return;
    emit(IncidentDetailState(estado: EstadoDelDetalle.votando, detalle: detalle));
    try {
      final (actualizado, retirado) = await repository.vote(detalle.incidente.id, sigue: sigue);
      final nuevo = detalle.conVoto(actualizado, sigue);
      if (retirado) onRetirado?.call(actualizado.id);
      emit(IncidentDetailState(estado: retirado ? EstadoDelDetalle.retirado : EstadoDelDetalle.listo, detalle: nuevo));
    } on SessionExpiredException catch (e) {
      emit(IncidentDetailState(estado: EstadoDelDetalle.listo, detalle: detalle, mensaje: e.toString(), sesionExpirada: true));
    } catch (e) {
      emit(IncidentDetailState(estado: EstadoDelDetalle.listo, detalle: detalle, mensaje: e.toString()));
    }
  }
}
