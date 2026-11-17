import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../../core/design/bahia.dart';
import '../../../../core/design/ilustracion.dart';
import '../../domain/models/incident_models.dart';
import 'detalle_de_reporte.dart';

const _tamanoDelPin = 44.0;

/// Burbuja blanca con la ilustración del tipo, un aro del color de su grupo y la punta sobre el lugar.
/// Si la comunidad ya lo confirmó, muestra cuántas veces.
class PinDeReporte extends StatelessWidget {
  final Incident incidente;
  final double tamano;

  const PinDeReporte({super.key, required this.incidente, this.tamano = _tamanoDelPin});

  @override
  Widget build(BuildContext context) {
    final bahia = Bahia.de(context);
    final (color, _) = bahia.delGrupo(incidente.grupo);
    final tipo = incidente.ilustracion;
    return SizedBox(
      width: tamano + 8,
      height: tamano + 10,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 4 + tamano / 2 - 5,
            top: tamano - 5,
            child: Transform.rotate(
              angle: 0.785,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
          Positioned(
            left: 4,
            top: 0,
            child: Container(
              width: tamano,
              height: tamano,
              padding: EdgeInsets.all(tamano * 0.14),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
                boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: tipo != null
                  ? Ilustracion(tipo, tamano: tamano, conFondo: false)
                  : Icon(Icons.campaign_outlined, color: color, size: tamano * 0.55),
            ),
          ),
          if (incidente.votosSi > 0)
            Positioned(
              right: 0,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bahia.hoja,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Text('${incidente.votosSi}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: bahia.texto, height: 1)),
              ),
            ),
        ],
      ),
    );
  }
}

/// El pin cae en su lugar al aparecer (salvo que el sistema pida reducir el movimiento).
class _Caida extends StatelessWidget {
  final Widget child;

  const _Caida({required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, t, hijo) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -18 * (1 - t)),
          child: Transform.scale(scale: 0.6 + 0.4 * t, alignment: Alignment.bottomCenter, child: hijo),
        ),
      ),
      child: child,
    );
  }
}

/// Marcador del mapa para un reporte: la punta del pin marca el lugar y al tocarlo se abre su detalle.
/// [atenuado] lo deja en segundo plano (no cuenta en el riesgo de la ruta que se está viendo); uno por confirmar
/// también se ve más suave.
Marker marcadorDeReporte(BuildContext context, Incident incidente,
    {bool atenuado = false, Alignment alineacion = Alignment.topCenter}) {
  final nombre = incidente.ilustracion?.nombre ?? 'Reporte';
  final lugar = incidente.lugar;
  // El backend nombra los puntos sin lugar exacto «Cerca de …»: se lee «cerca de …», no «en Cerca de …».
  final donde = lugar == null
      ? ''
      : lugar.startsWith('Cerca de ')
          ? ' cerca de ${lugar.substring(9)}'
          : ' en $lugar';
  final confirmado = incidente.porConfirmar
      ? ', por confirmar'
      : incidente.votosSi == 1
          ? ', lo confirmó 1 viajero'
          : incidente.votosSi > 1
              ? ', lo confirmaron ${incidente.votosSi} viajeros'
              : '';
  return Marker(
    key: ValueKey(incidente.id),
    point: incidente.punto,
    width: _tamanoDelPin + 8,
    height: _tamanoDelPin + 10,
    alignment: alineacion,
    child: Semantics(
      button: true,
      label: '$nombre$donde$confirmado',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => mostrarDetalleDeReporte(context, incidente),
        child: Opacity(
          opacity: atenuado ? 0.45 : (incidente.porConfirmar ? 0.7 : 1),
          child: _Caida(child: PinDeReporte(incidente: incidente)),
        ),
      ),
    ),
  );
}
