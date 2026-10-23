import 'package:flutter/material.dart';

/// Apariencia de la tarjeta de riesgo según el nivel que devuelve la API
/// (BAJO, MEDIO, ALTO, CRÍTICO).
class RiskStyle {
  final Color color;
  final IconData icon;

  const RiskStyle(this.color, this.icon);

  factory RiskStyle.forLevel(String nivel) => switch (nivel.toUpperCase()) {
        'CRÍTICO' || 'CRITICO' => const RiskStyle(Colors.red, Icons.dangerous_outlined),
        'ALTO' => const RiskStyle(Colors.redAccent, Icons.warning_amber_rounded),
        'MEDIO' => const RiskStyle(Colors.orangeAccent, Icons.privacy_tip_outlined),
        'BAJO' => const RiskStyle(Colors.green, Icons.verified_user_outlined),
        // Un nivel desconocido nunca debe presentarse como "seguro".
        _ => const RiskStyle(Colors.grey, Icons.help_outline),
      };
}
