import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/karta_theme.dart';
import '../../domain/models/incident_models.dart';

/// Baldosa del incidente: el glifo dice qué pasa; el color y la cifra de la esquina, qué tan fuerte (1–5).
class IncidentTile extends StatelessWidget {
  final Incident incidente;
  final double tamano;

  const IncidentTile({super.key, required this.incidente, this.tamano = 32});

  @override
  Widget build(BuildContext context) {
    final categoria = IncidentCategoryStyle.of(incidente.categoria);
    final intensidad = IntensityStyle.of(incidente.intensidad);
    final cifra = tamano * 0.5;
    return SizedBox(
      width: tamano + cifra * 0.45,
      height: tamano + cifra * 0.45,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: tamano,
              height: tamano,
              decoration: BoxDecoration(
                color: intensidad.color,
                borderRadius: BorderRadius.circular(tamano * 0.22),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Icon(categoria.icono, size: tamano * 0.56, color: intensidad.onColor),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: cifra,
              height: cifra,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: intensidad.color, width: 1.5),
              ),
              child: Text(
                '${incidente.intensidad}',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: cifra * 0.68,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: KartaColors.tinta,
                  fontFeatures: tabularFigures,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [alineacion] permite correr la baldosa cuando cae encima de otro marcador que también importa.
Marker incidentMarker(BuildContext context, Incident incidente,
    {bool atenuado = false, Alignment alineacion = Alignment.center}) {
  final estilo = IncidentCategoryStyle.of(incidente.categoria);
  return Marker(
    point: LatLng(incidente.latitud, incidente.longitud),
    width: 48,
    height: 48,
    alignment: alineacion,
    child: Semantics(
      button: true,
      label: '${estilo.nombre}, intensidad ${incidente.intensidad} de 5, ${etiquetasIntensidad[incidente.intensidad]}',
      child: GestureDetector(
        onTap: () => showIncidentDetail(context, incidente),
        child: Center(child: Opacity(opacity: atenuado ? 0.45 : 1, child: IncidentTile(incidente: incidente))),
      ),
    ),
  );
}

void showIncidentDetail(BuildContext context, Incident incidente) {
  final estilo = IncidentCategoryStyle.of(incidente.categoria);
  final texto = Theme.of(context).textTheme;
  final scheme = Theme.of(context).colorScheme;
  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IncidentTile(incidente: incidente, tamano: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(estilo.nombre, style: texto.headlineSmall),
                      Text(
                        'Intensidad ${incidente.intensidad} de 5 · ${etiquetasIntensidad[incidente.intensidad]}',
                        style: texto.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (incidente.creadoEn != null)
              _Linea(icono: Icons.schedule, texto: 'Reportado ${haceCuanto(incidente.creadoEn!)}'),
            if (incidente.expiraEn != null)
              _Linea(icono: Icons.timer_outlined, texto: 'Deja de mostrarse en ${dentroDe(incidente.expiraEn!)}'),
            const _Linea(
              icono: Icons.groups_outlined,
              texto: 'Lo reportó un viajero de la comunidad; Karta todavía no lo ha verificado.',
            ),
          ],
        ),
      ),
    ),
  );
}

class _Linea extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Linea({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
