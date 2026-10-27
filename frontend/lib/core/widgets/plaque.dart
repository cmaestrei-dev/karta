import 'package:flutter/material.dart';

import '../design/bahia.dart';

/// Tarjeta «Bahía»: la superficie de todo lugar con nombre (estaciones, resultados, lugares guardados).
/// Sobre el mapa va [elevated] para despegarse del fondo.
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
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.elevated = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final radio = BorderRadius.circular(18);

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: Material(
        color: elevated ? b.hoja : b.tarjeta,
        borderRadius: radio,
        elevation: elevated ? 6 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: radio,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Acceso rápido en forma de ficha (Casa, Trabajo, Guardar): 46 dp de alto, ícono en el acento.
/// Sin [label] queda cuadrada, solo con el ícono y su [tooltip].
class MiniPlaque extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String? detalle;
  final String? tooltip;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const MiniPlaque({
    super.key,
    required this.icon,
    this.label,
    this.detalle,
    this.tooltip,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final radio = BorderRadius.circular(14);
    final contenido = label == null
        ? SizedBox.square(dimension: 46, child: Icon(icon, size: 22, color: b.texto))
        : Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 19, color: b.acento),
                const SizedBox(width: 8),
                Text(label!, style: texto.titleSmall),
                if (detalle != null) ...[
                  const SizedBox(width: 6),
                  Text(detalle!, style: texto.bodyMedium?.copyWith(color: b.textoSuave, fontFeatures: tabularFigures)),
                ],
              ],
            ),
          );
    final ficha = Semantics(
      button: true,
      label: label == null ? tooltip : [label, detalle].whereType<String>().join(', '),
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Material(
        color: b.tarjeta,
        borderRadius: radio,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: radio,
          child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 46), child: Center(widthFactor: 1, child: contenido)),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: ficha) : ficha;
  }
}
