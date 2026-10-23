import 'package:flutter/material.dart';

import '../theme/karta_theme.dart';

/// Apariencia de cada nivel de riesgo que devuelve la API (BAJO, MEDIO, ALTO, CRÍTICO).
/// El nivel nunca se comunica solo con color: siempre va con ícono y texto.
class RiskStyle {
  final Color color;
  final Color onColor;
  final IconData icon;
  final String etiqueta;

  const RiskStyle(this.color, this.onColor, this.icon, this.etiqueta);

  factory RiskStyle.forLevel(String nivel) => switch (nivel.toUpperCase()) {
        'CRÍTICO' || 'CRITICO' =>
          const RiskStyle(KartaColors.ladrilloProfundo, Colors.white, Icons.dangerous_outlined, 'Riesgo crítico'),
        'ALTO' => const RiskStyle(KartaColors.ladrillo, Colors.white, Icons.warning_amber_rounded, 'Riesgo alto'),
        'MEDIO' => const RiskStyle(KartaColors.ocre, KartaColors.tintaSobreOcre, Icons.error_outline, 'Riesgo medio'),
        'BAJO' => const RiskStyle(KartaColors.balcon, Colors.white, Icons.verified_user_outlined, 'Riesgo bajo'),
        // Un nivel desconocido nunca debe presentarse como "seguro".
        _ => const RiskStyle(KartaColors.tintaSuave, Colors.white, Icons.help_outline, 'Riesgo sin datos'),
      };
}

class RiskBadge extends StatelessWidget {
  final String nivel;
  final int? totalIncidentes;

  const RiskBadge({super.key, required this.nivel, this.totalIncidentes});

  @override
  Widget build(BuildContext context) {
    final estilo = RiskStyle.forLevel(nivel);
    final texto = Theme.of(context).textTheme.labelMedium?.copyWith(color: estilo.onColor, fontWeight: FontWeight.w700);
    final detalle = switch (totalIncidentes) {
      null => '',
      0 => '',
      1 => ' · 1 reporte',
      final n => ' · $n reportes',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: estilo.color, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estilo.icon, size: 16, color: estilo.onColor),
          const SizedBox(width: 4),
          Flexible(child: Text('${estilo.etiqueta}$detalle', style: texto, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
