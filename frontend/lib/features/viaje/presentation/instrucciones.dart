import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../trip/domain/trip_models.dart';
import '../domain/seguidor_de_viaje.dart';

/// Lo que dice la franja de arriba del viaje activo: qué hacer ahora, en grande, y qué viene después.
typedef Instruccion = ({IconData icono, String titulo, String detalle, String? luego});

/// Minutos a pie para [metros] en línea recta (con el rodeo y la velocidad del planificador).
int minutosAPie(double metros) => (metros * 1.3 / 75).ceil().clamp(1, 999);

Instruccion instruccionDe(SeguidorDeViaje seguidor, String destino) {
  final estado = seguidor.estado;
  final actual = seguidor.tramoActual;
  final siguiente = seguidor.tramoSiguiente;
  final falta = estado.faltaDelTramoM;
  return switch (estado.fase) {
    Fase.caminandoALaParada => (
        icono: Icons.directions_walk,
        titulo: 'Camina a ${actual.hasta}',
        detalle: '${metros(falta)} · ${minutos(minutosAPie(falta))} a pie',
        luego: siguiente != null ? 'sube al ${siguiente.ruta}' : null,
      ),
    Fase.esperando => (
        icono: Icons.directions_bus,
        titulo: 'Sube al ${actual.ruta}',
        detalle: 'en ${actual.desde}',
        luego: _bajarse(actual),
      ),
    Fase.aBordo => (
        icono: Icons.south,
        titulo: _tituloABordo(estado),
        detalle: '${actual.hasta} · te avisamos una antes',
        luego: _despuesDeBajarse(seguidor, destino),
      ),
    Fase.transbordo => (
        icono: Icons.sync_alt,
        titulo: 'Cambia al ${siguiente?.ruta ?? 'siguiente bus'}',
        detalle: falta < 30 ? 'aquí mismo, en ${actual.hasta}' : 'camina ${metros(falta)} hasta ${actual.hasta}',
        luego: siguiente != null ? _bajarse(siguiente) : null,
      ),
    Fase.caminandoAlDestino => (
        icono: Icons.directions_walk,
        titulo: 'Camina a $destino',
        detalle: '${metros(falta)} · ${minutos(minutosAPie(falta))} a pie',
        luego: null,
      ),
    Fase.llegaste => (icono: Icons.check_circle_outline, titulo: 'Llegaste', detalle: destino, luego: null),
  };
}

String _tituloABordo(EstadoDelViaje estado) {
  final falta = estado.faltaDelTramoM;
  final paradas = estado.paradasQueFaltan;
  if (falta <= SeguidorDeViaje.bajateAquiM) return 'Bájate aquí';
  if (paradas == null) return falta <= SeguidorDeViaje.avisoSinParadasM ? 'Bájate en la próxima' : 'Bájate en ${metros(falta)}';
  return paradas <= 1 ? 'Bájate en la próxima' : 'Bájate en $paradas paradas';
}

/// «bájate en Estación La Bodeguita · 4 paradas».
String _bajarse(Leg bus) {
  final paradas = bus.bajaEnEstacion ? bus.paradas.length - 1 : 0;
  return 'bájate en ${bus.hasta}${paradas > 1 ? ' · $paradas paradas' : ''}';
}

String? _despuesDeBajarse(SeguidorDeViaje seguidor, String destino) {
  final tramos = seguidor.opcion.tramos;
  final k = seguidor.estado.tramo;
  final otroBus = tramos.skip(k + 1).where((t) => !t.esCaminata).firstOrNull;
  if (otroBus != null) return 'cambia al ${otroBus.ruta} en ${otroBus.desde}';
  final caminata = k + 1 < tramos.length ? tramos[k + 1] : null;
  return caminata != null ? 'camina ${minutos(caminata.duracionMin)} hasta $destino' : null;
}

/// Las estaciones del tramo en bus para la barra de avance: cuántas hay y cuántas ya pasó.
({int total, int pasadas})? avanceEnParadas(SeguidorDeViaje seguidor) {
  final estado = seguidor.estado;
  final paradas = seguidor.tramoActual.paradas;
  if (estado.fase != Fase.aBordo || estado.paradasQueFaltan == null || paradas.length < 2) return null;
  final total = paradas.length - 1; // la de subida no cuenta como tramo por recorrer
  return (total: total, pasadas: (total - estado.paradasQueFaltan!).clamp(0, total));
}
