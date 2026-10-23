import 'package:flutter/material.dart';

import '../theme/karta_theme.dart';

/// Código de una ruta de Transcaribe ("T103") en el color de su tipo, como el letrero del bus.
class RouteCapsule extends StatelessWidget {
  final String codigo;
  final String? tipo;
  final bool grande;

  const RouteCapsule({super.key, required this.codigo, this.tipo, this.grande = false});

  static Color colorDe(String? tipo) => switch (tipo) {
        'troncal' => KartaColors.troncal,
        'pretroncal' => KartaColors.pretroncal,
        'alimentadora' => KartaColors.alimentadora,
        'complementaria' => KartaColors.complementaria,
        _ => KartaColors.tintaSuave,
      };

  @override
  Widget build(BuildContext context) {
    final estilo = (grande ? Theme.of(context).textTheme.titleSmall : Theme.of(context).textTheme.labelMedium)
        ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.3, fontFeatures: tabularFigures);
    return Semantics(
      label: 'Ruta $codigo${tipo != null ? ', $tipo' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: grande ? 10 : 7, vertical: grande ? 4 : 2),
        decoration: BoxDecoration(color: colorDe(tipo), borderRadius: BorderRadius.circular(6)),
        child: Text(codigo, style: estilo),
      ),
    );
  }
}
