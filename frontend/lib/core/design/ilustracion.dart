import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'bahia.dart';

/// Tipos de reporte con ilustración propia. La clave es la misma que usa el catálogo del backend.
enum TipoIlustrado {
  busNoPasa('bus_no_pasa', 'El bus no pasa', 'servicio'),
  busLleno('bus_lleno', 'El bus no paró', 'servicio'),
  busVarado('bus_varado', 'Bus varado', 'servicio'),
  estacionCerrada('estacion_cerrada', 'Estación cerrada', 'servicio'),
  trancon('trancon', 'Trancón', 'via'),
  accidente('accidente', 'Accidente', 'via'),
  calleInundada('calle_inundada', 'Calle inundada', 'via'),
  robo('robo', 'Robo', 'seguridad'),
  calleSola('calle_sola', 'Calle sola u oscura', 'seguridad'),
  acoso('acoso', 'Acoso', 'seguridad');

  final String clave;
  final String nombre;
  final String grupo;

  const TipoIlustrado(this.clave, this.nombre, this.grupo);

  String get recurso => 'assets/ilustraciones/$clave.svg';

  static TipoIlustrado? deClave(String clave) {
    for (final tipo in values) {
      if (tipo.clave == clave) return tipo;
    }
    return null;
  }
}

/// La ilustración de un tipo de reporte sobre un círculo suave del color de su grupo.
class Ilustracion extends StatelessWidget {
  final TipoIlustrado tipo;
  final double tamano;
  final bool conFondo;

  const Ilustracion(this.tipo, {super.key, this.tamano = 64, this.conFondo = true});

  @override
  Widget build(BuildContext context) {
    final dibujo = SvgPicture.asset(
      tipo.recurso,
      width: conFondo ? tamano * 0.78 : tamano,
      height: conFondo ? tamano * 0.78 : tamano,
      excludeFromSemantics: true,
    );
    if (!conFondo) return Semantics(label: tipo.nombre, child: dibujo);
    final (_, suave) = Bahia.de(context).delGrupo(tipo.grupo);
    return Semantics(
      label: tipo.nombre,
      child: Container(
        width: tamano,
        height: tamano,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: suave, shape: BoxShape.circle),
        child: dibujo,
      ),
    );
  }
}
