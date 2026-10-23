import 'package:flutter/material.dart';

import '../theme/karta_theme.dart';

/// Placa de azulejo: superficie de baldosa con doble filete de tinta, como las placas
/// con el nombre de las calles del Centro. Es el contenedor de todo lugar con nombre.
class Plaque extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final bool elevated;
  final String? semanticLabel;

  const Plaque({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.elevated = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tinta = scheme.primary;
    final radio = BorderRadius.circular(6);

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: Material(
        color: KartaTheme.azulejo(scheme),
        borderRadius: radio,
        elevation: elevated ? 4 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: radio,
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: tinta, width: 2), borderRadius: radio),
            padding: const EdgeInsets.all(2),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: tinta, width: 1),
                borderRadius: BorderRadius.circular(3),
              ),
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Placa pequeña para accesos rápidos (lugares guardados, acciones del mapa). Mide 48 dp de alto.
class MiniPlaque extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const MiniPlaque({super.key, required this.icon, required this.label, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Plaque(
        onTap: onTap,
        onLongPress: onLongPress,
        elevated: true,
        semanticLabel: label,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
