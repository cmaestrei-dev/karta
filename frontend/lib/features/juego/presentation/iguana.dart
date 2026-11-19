import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/design/bahia.dart';
import '../../../core/design/movimiento.dart';
import '../../viaje/domain/seguidor_de_viaje.dart';
import '../data/progreso_local.dart';
import '../domain/progreso.dart';

enum AnimoDeIguana { tranquila, feliz, dormida }

/// Cómo está la iguana según el viaje: duerme si el bus tarda, se alegra cuando viene, a bordo y al llegar.
AnimoDeIguana animoDelViaje(Fase fase, {int? minutosParaElBus, bool celebrando = false}) {
  if (celebrando) return AnimoDeIguana.feliz;
  return switch (fase) {
    Fase.aBordo || Fase.llegaste => AnimoDeIguana.feliz,
    Fase.esperando when minutosParaElBus != null && minutosParaElBus <= 3 => AnimoDeIguana.feliz,
    Fase.esperando when minutosParaElBus != null && minutosParaElBus >= 12 => AnimoDeIguana.dormida,
    _ => AnimoDeIguana.tranquila,
  };
}

/// La iguana del Centenario con lo que lleva puesto. Al aparecer y cuando cambia de ánimo se mece unas veces y se
/// queda quieta: en un viaje largo, moverse sin parar gasta batería y distrae. Con «reducir movimiento», nunca.
class Iguana extends StatefulWidget {
  final AnimoDeIguana animo;
  final Accesorio? accesorio;
  final double tamano;

  /// Lo que lee TalkBack; null, la iguana es solo adorno.
  final String? semantica;

  /// Sin mecerse: en una lista de varias, una sola que se mueva basta.
  final bool quieta;

  const Iguana(
      {super.key, this.animo = AnimoDeIguana.tranquila, this.accesorio, this.tamano = 64, this.semantica, this.quieta = false});

  @override
  State<Iguana> createState() => _IguanaState();
}

class _IguanaState extends State<Iguana> with SingleTickerProviderStateMixin {
  static const _vaivenes = 3;
  late final _vaiven = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mecerse();
  }

  @override
  void didUpdateWidget(Iguana antes) {
    super.didUpdateWidget(antes);
    if (antes.animo != widget.animo) _mecerse();
  }

  Future<void> _mecerse() async {
    if (widget.quieta || Movimiento.reducido(context) || _vaiven.isAnimating) return;
    try {
      for (var k = 0; k < _vaivenes && mounted; k++) {
        await _vaiven.forward(from: 0);
        await _vaiven.reverse();
      }
    } on TickerCanceled {
      // Se fue de la pantalla mientras se mecía.
    }
  }

  @override
  void dispose() {
    _vaiven.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alto = widget.tamano * 100 / 120;
    final dibujo = SizedBox(
      width: widget.tamano,
      height: alto,
      child: Stack(
        children: [
          SvgPicture.asset('assets/iguana/iguana_${widget.animo.name}.svg',
              width: widget.tamano, height: alto, excludeFromSemantics: true),
          if (widget.accesorio != null)
            SvgPicture.asset(widget.accesorio!.recurso, width: widget.tamano, height: alto, excludeFromSemantics: true),
        ],
      ),
    );
    final meciendose = AnimatedBuilder(
      animation: _vaiven,
      builder: (context, hijo) => Transform.translate(
        // Dormida respira más despacio y menos.
        offset: Offset(0, -_vaiven.value * widget.tamano * (widget.animo == AnimoDeIguana.dormida ? 0.015 : 0.035)),
        child: hijo,
      ),
      child: dibujo,
    );
    return widget.semantica == null
        ? ExcludeSemantics(child: meciendose)
        : Semantics(label: widget.semantica, image: true, child: meciendose);
  }
}

/// El vestidor: ponerle a la iguana lo que se ha ganado y decidir si acompaña el viaje.
Future<void> abrirVestidor(BuildContext context, ProgresoLocal progreso) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _Vestidor(progreso: progreso),
    );

class _Vestidor extends StatefulWidget {
  final ProgresoLocal progreso;

  const _Vestidor({required this.progreso});

  @override
  State<_Vestidor> createState() => _VestidorState();
}

class _VestidorState extends State<_Vestidor> {
  ProgresoDeJuego? _actual;

  @override
  void initState() {
    super.initState();
    widget.progreso.leer().then((p) {
      if (mounted) setState(() => _actual = p);
    });
  }

  Future<void> _cambiar(ProgresoDeJuego Function(ProgresoDeJuego) cambio) async {
    final nuevo = await widget.progreso.cambiar((p) {
      final r = cambio(p);
      return (progreso: r, resultado: r);
    });
    if (mounted) setState(() => _actual = nuevo);
  }

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final p = _actual;
    if (p == null) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    final llenas = p.tarjeta.llenas;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Iguana(animo: AnimoDeIguana.feliz, accesorio: p.puesto, tamano: 132,
              semantica: p.puesto == null ? 'Tu iguana' : 'Tu iguana, con ${p.puesto!.nombre.toLowerCase()}')),
          const SizedBox(height: 8),
          Text('Tu iguana del Centenario', textAlign: TextAlign.center, style: texto.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Cada tarjeta de sellos que llenas le gana algo para ponerse. Llevas $llenas '
            '${llenas == 1 ? 'tarjeta llena' : 'tarjetas llenas'}.',
            textAlign: TextAlign.center,
            style: texto.bodySmall?.copyWith(color: b.textoSuave, height: 1.4),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _Prenda(
                nombre: 'Sin nada',
                elegida: p.puesto == null,
                onTap: () => _cambiar((x) => x.copyWith(accesorio: () => null)),
              ),
              for (final a in accesorios)
                _Prenda(
                  nombre: a.nombre,
                  accesorio: a,
                  elegida: p.puesto?.clave == a.clave,
                  falta: a.ganado(llenas) ? null : 'Llena ${a.tarjetas} ${a.tarjetas == 1 ? 'tarjeta' : 'tarjetas'}',
                  onTap: a.ganado(llenas) ? () => _cambiar((x) => x.copyWith(accesorio: () => a.clave)) : null,
                ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Que me acompañe en el viaje'),
            subtitle: const Text('Aparece en una esquina del mapa y se alegra cuando viene tu bus.'),
            value: p.iguanaEnElViaje,
            onChanged: (si) => _cambiar((x) => x.copyWith(iguanaEnElViaje: si)),
          ),
        ],
      ),
    );
  }
}

class _Prenda extends StatelessWidget {
  final String nombre;
  final Accesorio? accesorio;
  final bool elegida;
  final String? falta;
  final VoidCallback? onTap;

  const _Prenda({required this.nombre, this.accesorio, required this.elegida, this.falta, this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final radio = BorderRadius.circular(16);
    return Semantics(
      button: onTap != null,
      selected: elegida,
      label: falta == null ? nombre : '$nombre: $falta',
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox(
        width: 100,
        child: Material(
          color: elegida ? b.acentoSuave : b.tarjeta,
          shape: RoundedRectangleBorder(
              borderRadius: radio, side: BorderSide(color: elegida ? b.acento : Colors.transparent, width: 2)),
          child: InkWell(
            borderRadius: radio,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: Opacity(
                      opacity: falta == null ? 1 : 0.35,
                      child: Iguana(accesorio: accesorio, tamano: 58, quieta: true),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(nombre,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: texto.labelMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
                  if (falta != null) ...[
                    const SizedBox(height: 2),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.lock_outline, size: 12, color: b.textoSuave),
                      const SizedBox(width: 3),
                      Flexible(
                          child: Text(falta!,
                              textAlign: TextAlign.center, style: texto.labelSmall?.copyWith(color: b.textoSuave))),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
