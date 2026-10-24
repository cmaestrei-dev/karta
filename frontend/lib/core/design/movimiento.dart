import 'package:flutter/material.dart';

/// Curvas y tiempos del movimiento «Bahía»: entradas con un pequeño rebote, nada dura más de medio segundo.
abstract final class Movimiento {
  static const rapido = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 320);
  static const entrada = Duration(milliseconds: 450);
  static const rebote = Cubic(0.3, 1.4, 0.5, 1);
  static const suave = Cubic(0.2, 0.8, 0.2, 1);

  static bool reducido(BuildContext context) => MediaQuery.disableAnimationsOf(context);
}

/// El hijo «brota»: crece desde el 40 % con un rebote leve, después de [retraso].
/// Sirve para escalonar las ilustraciones de una cuadrícula. Respeta «reducir movimiento».
class Brote extends StatefulWidget {
  final Widget child;
  final Duration retraso;

  const Brote({super.key, required this.child, this.retraso = Duration.zero});

  @override
  State<Brote> createState() => _BroteState();
}

class _BroteState extends State<Brote> with SingleTickerProviderStateMixin {
  late final _control = AnimationController(vsync: this, duration: Movimiento.entrada);
  late final _escala = Tween<double>(begin: 0.4, end: 1).animate(CurvedAnimation(parent: _control, curve: Movimiento.rebote));
  late final _opacidad = CurvedAnimation(parent: _control, curve: const Interval(0, 0.5));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_control.isAnimating || _control.isCompleted) return;
    if (Movimiento.reducido(context)) {
      _control.value = 1;
    } else {
      Future.delayed(widget.retraso, () {
        if (mounted) _control.forward();
      });
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacidad,
        child: ScaleTransition(scale: _escala, child: widget.child),
      );
}
