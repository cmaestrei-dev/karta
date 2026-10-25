import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/design/bahia.dart';
import '../../../../core/design/movimiento.dart';
import '../../../auth/domain/models/usuario.dart';

/// El archivo de cada marco en `assets/marcos/` (los dibuja `tool/dibujar_marcos.py`).
const _archivos = {'Muralla': 'muralla', 'Bahía': 'bahia', 'Castillo': 'castillo', 'La Popa': 'la_popa'};

/// El lienzo del marco mide 1,6 veces el avatar (viewBox de 192 con el avatar de 120 en el centro).
const _lienzo = 1.6;

/// Desde este tamaño se usa la versión con todos los detalles; por debajo, la «chica», legible a 48 px.
const tamanoDeVitrina = 80.0;

/// Avatar del viajero con sus iniciales, el marco de su nivel y el nivel en una insignia.
/// Con [animar] (solo en la vitrina del perfil), el marco brilla dos veces y se queda quieto; tocarlo lo repite.
class AvatarDeViajero extends StatelessWidget {
  final Usuario usuario;
  final double tamano;
  final bool animar;

  const AvatarDeViajero({super.key, required this.usuario, this.tamano = 48, this.animar = false});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final insignia = (tamano * 0.4).clamp(22.0, 30.0);
    return MarcoDeAvatar(
      marco: usuario.marco,
      tamano: tamano,
      animar: animar,
      insignia: Container(
        constraints: BoxConstraints(minWidth: insignia),
        height: insignia,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: b.acento,
          borderRadius: BorderRadius.circular(insignia / 2),
          border: Border.all(color: b.hoja, width: 2),
        ),
        child: Text('${usuario.nivel}',
            style: TextStyle(fontSize: insignia * 0.5, fontWeight: FontWeight.w800, color: b.sobreAcento, height: 1)),
      ),
      child: usuario.sinCuenta
          ? Icon(Icons.person_outline, size: tamano * 0.5, color: b.texto)
          : Text(
              usuario.iniciales,
              style: TextStyle(fontSize: tamano * 0.34, fontWeight: FontWeight.w800, color: b.texto),
            ),
    );
  }
}

/// Un círculo de [tamano] con [child] adentro y el marco alrededor: el aura detrás, el aro y sus adornos delante.
/// El arte se sale del círculo sin ocupar más espacio en la pantalla (la caja mide `tamano + 6`).
/// [bloqueado]: el marco aún no ganado, en gris, para la colección del perfil.
class MarcoDeAvatar extends StatelessWidget {
  final String? marco;
  final double tamano;
  final Widget child;
  final Widget? insignia;
  final bool animar;
  final bool bloqueado;

  const MarcoDeAvatar({
    super.key,
    required this.marco,
    required this.tamano,
    required this.child,
    this.insignia,
    this.animar = false,
    this.bloqueado = false,
  });

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final archivo = _archivos[marco];
    final detalle = tamano >= tamanoDeVitrina ? 'vitrina' : 'chico';

    Widget capa(String cual) {
      final arte = OverflowBox(
        maxWidth: tamano * _lienzo,
        maxHeight: tamano * _lienzo,
        child: SvgPicture.asset('assets/marcos/${archivo}_${cual}_$detalle.svg',
            width: tamano * _lienzo, height: tamano * _lienzo, excludeFromSemantics: true),
      );
      return Positioned.fill(
        child: IgnorePointer(child: bloqueado ? Opacity(opacity: 0.45, child: ColorFiltered(colorFilter: _gris, child: arte)) : arte),
      );
    }

    return SizedBox.square(
      dimension: tamano + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Muralla no tiene capa de fondo; las demás, el aura o el sol detrás del avatar.
          if (archivo != null && archivo != 'muralla' && !(archivo == 'bahia' && detalle == 'chico')) capa('fondo'),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: CustomPaint(
                // Sin marco (nivel 1), un aro del color de acento.
                foregroundPainter: archivo == null ? PintorDeMarco(marco: null, acento: b.acento) : null,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: b.hoja, shape: BoxShape.circle),
                  child: child,
                ),
              ),
            ),
          ),
          if (archivo != null) capa('frente'),
          if (archivo != null && animar && !bloqueado)
            Positioned.fill(child: _Brillo(marco: archivo, tamano: tamano)),
          if (insignia != null) Positioned(right: 0, bottom: 0, child: insignia!),
        ],
      ),
    );
  }
}

const _gris = ColorFilter.matrix([
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// El brillo de la vitrina: un reflejo que recorre el aro y destellos que titilan. Dos vueltas de 2,4 s y quieto
/// (menos de 5 s, como pide WCAG 2.2.2); tocar el avatar lo repite. Nada si el teléfono pide menos movimiento.
class _Brillo extends StatefulWidget {
  final String marco;
  final double tamano;

  const _Brillo({required this.marco, required this.tamano});

  @override
  State<_Brillo> createState() => _BrilloState();
}

class _BrilloState extends State<_Brillo> with SingleTickerProviderStateMixin {
  late final _vuelta = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // repeat() no se acorta con «quitar animaciones»: se revisa a mano.
    if (Movimiento.reducido(context)) {
      _vuelta.stop();
    } else if (!_vuelta.isAnimating && _vuelta.value == 0) {
      _vuelta.repeat(count: 2);
    }
  }

  void _otraVez() {
    if (Movimiento.reducido(context) || _vuelta.isAnimating) return;
    _vuelta
      ..value = 0
      ..repeat(count: 2);
  }

  @override
  void dispose() {
    _vuelta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _otraVez,
        child: RepaintBoundary(
          child: OverflowBox(
            maxWidth: widget.tamano * _lienzo,
            maxHeight: widget.tamano * _lienzo,
            child: SizedBox.square(
              dimension: widget.tamano * _lienzo,
              child: CustomPaint(painter: PintorDeBrillo(widget.marco, _vuelta)),
            ),
          ),
        ),
      );
}

/// Dónde brilla cada marco, en las coordenadas del SVG (192 de lado, centro en el avatar, aro de r = 55 a 65):
/// el tramo del aro que recorre el reflejo (horas de reloj, sin pasar por debajo de los adornos) y los destellos.
const _brillos = {
  'bahia': (desde: 20.0, hasta: 236.0, destellos: [(82.0, 50.0, 9.0), (78.0, 72.0, 4.5)]),
  'castillo': (desde: 38.0, hasta: 322.0, destellos: [(63.5, 0.0, 6.0)]),
  'la_popa': (desde: 46.0, hasta: 290.0, destellos: [(80.0, 240.0, 7.5), (84.0, 284.0, 5.5), (79.0, 74.0, 6.0)]),
};

class PintorDeBrillo extends CustomPainter {
  final String marco;
  final Animation<double> vuelta;

  PintorDeBrillo(this.marco, this.vuelta) : super(repaint: vuelta);

  static Offset _polar(double r, double grados) {
    final a = grados * pi / 180;
    return Offset(r * sin(a), -r * cos(a));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final config = _brillos[marco];
    final t = vuelta.value;
    if (config == null || t == 0) return;
    final k = size.width / 192;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(k);
    // El reflejo: un arco de luz que avanza por el aro en la primera mitad de la vuelta.
    if (t < 0.6) {
      final avance = Curves.easeInOut.transform(t / 0.6);
      final centro = config.desde + (config.hasta - config.desde) * avance;
      const largo = 34.0;
      final inicio = (centro - largo / 2 - 90) * pi / 180;
      final luz = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: inicio,
          endAngle: inicio + largo * pi / 180,
          colors: const [Color(0x00FFFFFF), Color(0x99FFFFFF), Color(0x00FFFFFF)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 60));
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: 60), inicio, largo * pi / 180, false, luz);
    }
    // Los destellos crecen y se apagan, uno tras otro.
    for (final (i, (r, hora, tam)) in config.destellos.indexed) {
      final fase = ((t - 0.35 - i * 0.12) / 0.4).clamp(0.0, 1.0);
      if (fase == 0 || fase == 1) continue;
      final s = sin(fase * pi);
      final c = _polar(r, hora);
      final brillo = Paint()..color = Color.fromRGBO(255, 255, 255, 0.9 * s);
      canvas.drawPath(_estrella(c, tam * (0.8 + 0.7 * s)), brillo);
    }
    canvas.restore();
  }

  static Path _estrella(Offset c, double r) {
    final k = r * 0.22;
    return Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
      ..close();
  }

  @override
  bool shouldRepaint(PintorDeBrillo antes) => antes.marco != marco || antes.vuelta != vuelta;
}

/// El aro sencillo: el de acento en el nivel 1 y la muestra de color de cada marco junto al nivel en el perfil.
class PintorDeMarco extends CustomPainter {
  final String? marco;
  final Color acento;

  const PintorDeMarco({required this.marco, required this.acento});

  static const arena = Color(0xFFC9A46A);
  static const oro = Color(0xFFE0B84F);
  static const mar = [Color(0xFF1F8FC9), Color(0xFF2EC4B6), Color(0xFF1F8FC9)];
  static const atardecer = [Color(0xFFFF9A3C), Color(0xFFFF5E7E), Color(0xFF8E5CF7), Color(0xFFFF9A3C)];

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = size.shortestSide / 2;
    final grosor = (size.shortestSide * 0.075).clamp(2.5, 6.0);
    final aro = Rect.fromCircle(center: centro, radius: radio - grosor / 2);
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor;
    switch (marco) {
      case 'Muralla':
        canvas.drawOval(aro, pincel..color = arena);
      case 'Bahía':
        canvas.drawOval(aro, pincel..shader = const SweepGradient(colors: mar).createShader(aro));
      case 'Castillo':
        canvas.drawOval(aro, pincel..color = oro);
      case 'La Popa':
        canvas.drawOval(aro, pincel..shader = const SweepGradient(colors: atardecer).createShader(aro));
      default:
        pincel
          ..color = acento
          ..strokeWidth = 2;
        canvas.drawOval(Rect.fromCircle(center: centro, radius: radio - 1), pincel);
    }
  }

  @override
  bool shouldRepaint(PintorDeMarco antes) => antes.marco != marco || antes.acento != acento;
}
