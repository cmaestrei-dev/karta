import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/apariencia.dart';
import '../../../../core/design/bahia.dart';
import '../../../auth/domain/models/usuario.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/screens/register_screen.dart';
import '../../../places/presentation/cubit/saved_places_cubit.dart';
import '../../../places/presentation/screens/saved_places_screen.dart';
import '../../../viaje/data/preferencia_de_compartir.dart';

/// Avatar del viajero con sus iniciales, el marco de su nivel y el nivel en una insignia.
class AvatarDeViajero extends StatelessWidget {
  final Usuario usuario;
  final double tamano;

  const AvatarDeViajero({super.key, required this.usuario, this.tamano = 48});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    return SizedBox.square(
      dimension: tamano + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: CustomPaint(
                foregroundPainter: PintorDeMarco(marco: usuario.marco, acento: b.acento),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: b.hoja, shape: BoxShape.circle),
                  child: usuario.sinCuenta
                      ? Icon(Icons.person_outline, size: tamano * 0.5, color: b.texto)
                      : Text(
                          usuario.iniciales,
                          style: TextStyle(fontSize: tamano * 0.34, fontWeight: FontWeight.w800, color: b.texto),
                        ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22),
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: b.acento,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: b.hoja, width: 2),
              ),
              child: Text('${usuario.nivel}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: b.sobreAcento, height: 1)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Los marcos del avatar, uno por nivel y con imágenes de Cartagena: se ganan con reputación, no se compran.
/// Son trazos simples, sin animación, para que no pesen en un teléfono económico.
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
        // Bloques de piedra coralina, como los de la muralla.
        pincel.color = arena;
        const bloques = 12, hueco = 0.1;
        for (var i = 0; i < bloques; i++) {
          canvas.drawArc(aro, -pi / 2 + i * 2 * pi / bloques + hueco / 2, 2 * pi / bloques - hueco, false, pincel);
        }
      case 'Bahía':
        pincel.shader = const SweepGradient(colors: mar).createShader(aro);
        canvas.drawOval(aro, pincel);
      case 'Castillo':
        // Doble muro dorado con cuatro baluartes, como el San Felipe.
        pincel.color = oro;
        canvas.drawOval(aro, pincel);
        canvas.drawOval(
            aro.deflate(grosor),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = oro.withValues(alpha: 0.7));
        final baluarte = Paint()..color = oro;
        for (var i = 0; i < 4; i++) {
          final angulo = -pi / 2 + i * pi / 2;
          canvas
            ..save()
            ..translate(centro.dx + cos(angulo) * aro.width / 2, centro.dy + sin(angulo) * aro.height / 2)
            ..rotate(angulo + pi / 4)
            ..drawRect(Rect.fromCenter(center: Offset.zero, width: grosor * 1.7, height: grosor * 1.7), baluarte)
            ..restore();
        }
      case 'La Popa':
        // El atardecer visto desde La Popa, con un halo.
        canvas.drawOval(
            aro,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = grosor * 1.6
              ..color = const Color(0x59FF5E7E)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, grosor));
        pincel.shader = const SweepGradient(colors: atardecer).createShader(aro);
        canvas.drawOval(aro, pincel);
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

/// Cuenta del viajero: alias, nivel y reputación (al día), lugares guardados y cerrar sesión.
void showProfileSheet(BuildContext context) {
  final auth = context.read<AuthBloc>()..add(ProfileRefreshRequested());
  final apariencia = context.read<AparienciaCubit>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (hoja) => MultiBlocProvider(
      providers: [BlocProvider.value(value: auth), BlocProvider.value(value: apariencia)],
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Los builders usan `_`: `context` es el del inicio, que sigue vivo al cerrar la hoja.
              BlocBuilder<AuthBloc, AuthState>(
                builder: (_, state) => state is AuthAuthenticated
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Reputacion(usuario: state.usuario),
                          _TuImpacto(impacto: state.usuario.impacto),
                          _Insignias(usuario: state.usuario),
                          if (state.usuario.sinCuenta) _CrearCuenta(hoja: hoja, raiz: context),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              const _Apariencia(),
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) => state is AuthAuthenticated
                    ? const Padding(padding: EdgeInsets.only(top: 20), child: _Privacidad())
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.bookmarks_outlined),
                title: const Text('Lugares guardados'),
                onTap: () {
                  Navigator.of(hoja).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SavedPlacesScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Acerca de Karta'),
                onTap: () => _acercaDeKarta(hoja),
              ),
              BlocBuilder<AuthBloc, AuthState>(
                builder: (_, state) => state is AuthAuthenticated && !state.usuario.sinCuenta
                    ? _CerrarSesion(hoja: hoja, raiz: context, auth: auth)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Licencias y código fuente. El servidor es AGPL: quien lo usa a través de la app debe poder llegar a su código.
void _acercaDeKarta(BuildContext context) => showAboutDialog(
      context: context,
      applicationName: 'Karta',
      applicationLegalese: '© 2026 Camilo Andres Maestre Iglesias',
      children: const [
        SizedBox(height: 16),
        Text('El tiempo real de Transcaribe, hecho por sus pasajeros. Sin anuncios.'),
        SizedBox(height: 12),
        Text('La app es código abierto bajo la licencia Apache 2.0, el servidor bajo la GNU AGPL 3.0 y la '
            'documentación bajo CC BY 4.0.'),
        SizedBox(height: 12),
        SelectableText('Código fuente: github.com/cmaestrei-dev/karta'),
        SizedBox(height: 12),
        Text('Datos de rutas, estaciones, lugares y mapa © colaboradores de OpenStreetMap (ODbL); horarios del '
            'Portal de Datos Abiertos de Cartagena (Transcaribe S.A., CC BY 4.0).'),
      ],
    );

/// Cerrar la sesión con correo: se sigue sin cuenta en el teléfono. [raiz] es el contexto del inicio, que sigue
/// vivo cuando la hoja ya se cerró.
class _CerrarSesion extends StatelessWidget {
  final BuildContext hoja;
  final BuildContext raiz;
  final AuthBloc auth;

  const _CerrarSesion({required this.hoja, required this.raiz, required this.auth});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.logout),
      title: const Text('Cerrar sesión'),
      onTap: () async {
        Navigator.of(hoja).pop();
        final confirmar = await showDialog<bool>(
          context: raiz,
          builder: (dialogo) => AlertDialog(
            title: const Text('¿Cerrar sesión?'),
            content: const Text('Seguirás usando Karta sin cuenta en este teléfono. Tu reputación y tus '
                'lugares se quedan en tu cuenta para cuando vuelvas a entrar.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogo).pop(false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.of(dialogo).pop(true), child: const Text('Cerrar sesión')),
            ],
          ),
        );
        if (confirmar == true && raiz.mounted) {
          raiz.read<SavedPlacesCubit>().clear();
          auth.add(const LogoutRequested());
        }
      },
    );
  }
}

/// Sin cuenta: lo que gana al registrarse, sin presionar (todo funciona igual sin cuenta).
class _CrearCuenta extends StatelessWidget {
  final BuildContext hoja;
  final BuildContext raiz;

  const _CrearCuenta({required this.hoja, required this.raiz});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    void abrir(Widget pantalla) {
      Navigator.of(hoja).pop();
      Navigator.of(raiz).push(MaterialPageRoute(builder: (_) => pantalla));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: b.acentoSuave,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Crea tu cuenta', style: texto.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Tus reportes salen al instante, sin esperar a que alguien los confirme, y tu reputación no se pierde '
              'si cambias de teléfono.',
              style: texto.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(onPressed: () => abrir(const RegisterScreen()), child: const Text('Crear cuenta')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(onPressed: () => abrir(const LoginScreen()), child: const Text('Ya tengo cuenta')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Reputacion extends StatelessWidget {
  final Usuario usuario;

  const _Reputacion({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final falta = usuario.faltaParaSubir;
    final desde = usuario.nivel == 1 ? 100 : umbralesDeNivel[usuario.nivel - 2];
    final hasta = falta == null ? usuario.reputacion : usuario.reputacion + falta;
    final avance = falta == null ? 1.0 : ((usuario.reputacion - desde) / (hasta - desde)).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AvatarDeViajero(usuario: usuario, tamano: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(usuario.nombre ?? 'Sin cuenta', style: texto.headlineSmall),
                    Text(
                        usuario.sinCuenta
                            ? 'Tu reputación vive en este teléfono.'
                            : 'Los demás te ven como ${usuario.alias}',
                        style: texto.bodyMedium?.copyWith(color: b.textoSuave)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: b.tarjeta, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('Nivel ${usuario.nivel}', style: texto.titleLarge),
                    if (usuario.marco != null) ...[
                      const SizedBox(width: 8),
                      _MarcoGanado(marco: usuario.marco!),
                    ],
                    const Spacer(),
                    Text('${usuario.reputacion} de reputación',
                        style: texto.bodyMedium?.copyWith(color: b.textoSuave, fontFeatures: tabularFigures)),
                  ],
                ),
                const SizedBox(height: 10),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: avance),
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, valor, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: valor,
                      minHeight: 8,
                      backgroundColor: b.campo,
                      semanticsLabel: 'Avance al siguiente nivel',
                      semanticsValue: '${(avance * 100).round()} %',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _queFalta(usuario),
                  style: texto.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Ganas 2 cuando alguien confirma tu reporte y 1 cuando la comunidad coincide con tu voto. '
                  'Si desmienten uno tuyo, pierdes 5. Desde el nivel 3 confiamos más en ti: tus reportes pesan más '
                  'y tu «ya no está» retira un reporte por sí solo.',
                  style: texto.bodySmall?.copyWith(color: b.textoSuave),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// El nombre del marco con una muestra en miniatura, junto al nivel.
class _MarcoGanado extends StatelessWidget {
  final String marco;

  const _MarcoGanado({required this.marco});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    return Semantics(
      label: 'Marco $marco',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 3, 9, 3),
        decoration: BoxDecoration(color: b.campo, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
                dimension: 16, child: CustomPaint(painter: PintorDeMarco(marco: marco, acento: b.acento))),
            const SizedBox(width: 5),
            Text(marco, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// «Te faltan 40 para el nivel 4 y el marco Castillo».
String _queFalta(Usuario usuario) {
  // Sin partir «La Popa» entre dos líneas.
  String entero(String? nombre) => (nombre ?? '').replaceAll(' ', '\u00A0');
  final falta = usuario.faltaParaSubir;
  if (falta == null) return 'Llegaste al nivel más alto y al marco ${entero(usuario.marco)}.';
  final siguiente = entero(marcosPorNivel[usuario.nivel + 1]);
  final marco = siguiente.isEmpty
      ? ''
      : usuario.marco == null
          ? ' y tu primer marco: $siguiente'
          : ' y el marco $siguiente';
  return 'Te faltan $falta para el nivel ${usuario.nivel + 1}$marco.';
}

/// «Tu impacto»: lo que el viajero le ha aportado a la comunidad, en números que se entienden.
class _TuImpacto extends StatelessWidget {
  final Impacto impacto;

  const _TuImpacto({required this.impacto});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    // En dos columnas: con cuatro, «confirmaciones» se parte a mitad de palabra en un teléfono.
    Widget dato(int valor, String que) => Expanded(
          child: Semantics(
            label: '$valor $que',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$valor', style: texto.titleLarge?.copyWith(fontFeatures: tabularFigures)),
                  Text(que, style: texto.bodySmall?.copyWith(color: b.textoSuave)),
                ],
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
        decoration: BoxDecoration(color: b.tarjeta, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 10),
              child: Text('Tu impacto', style: texto.titleMedium),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dato(impacto.vistas, 'personas vieron tus reportes'),
                dato(impacto.confirmaciones, 'confirmaciones de tus reportes'),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dato(impacto.gracias, 'gracias recibidas'),
                FutureBuilder<int>(
                  future: PreferenciaDeCompartir().viajesCompartidos(),
                  builder: (context, viajes) => dato(viajes.data ?? 0, 'buses compartidos'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Cómo se ve cada insignia: el color de la medalla y su ícono, siempre en [tintaDeMedalla].
const medallas = {
  'primer_aviso': (Color(0xFFFF9A3C), Icons.campaign_outlined),
  'ojo_de_halcon': (Color(0xFF1F8FC9), Icons.visibility_outlined),
  'gracias_a_ti': (Color(0xFFFF5E7E), Icons.volunteer_activism_outlined),
  'faro_de_la_bahia': (Color(0xFFE0B84F), Icons.flare),
  'viajero_solidario': (Color(0xFF2EC4B6), Icons.directions_bus_outlined),
};
const tintaDeMedalla = Color(0xFF14181F);

/// Compartir la posición del bus es anónimo: su insignia se cuenta en el teléfono, no en el servidor.
const _viajeroSolidario = Insignia(
    clave: 'viajero_solidario', nombre: 'Viajero solidario', descripcion: 'Compartiste la posición de 5 buses');
const _busesParaSerSolidario = 5;

/// Las insignias ganadas y la que está más cerca, con cuánto falta.
class _Insignias extends StatelessWidget {
  final Usuario usuario;

  const _Insignias({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    return FutureBuilder<int>(
      future: PreferenciaDeCompartir().viajesCompartidos(),
      builder: (context, viajes) {
        final buses = viajes.data ?? 0;
        final solidario = buses >= _busesParaSerSolidario;
        final ganadas = [...usuario.insignias, if (solidario) _viajeroSolidario];
        final proximas = [
          if (usuario.siguienteInsignia != null) usuario.siguienteInsignia!,
          if (!solidario)
            AvanceDeInsignia(
                insignia: _viajeroSolidario, llevas: buses, meta: _busesParaSerSolidario, unidad: 'buses compartidos'),
        ];
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: b.tarjeta, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Tus insignias', style: texto.titleMedium),
                const SizedBox(height: 4),
                if (ganadas.isEmpty)
                  Text('Se ganan cuando otros viajeros confirman, agradecen o usan lo que aportas.',
                      style: texto.bodySmall?.copyWith(color: b.textoSuave))
                else ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 12,
                    children: [for (final insignia in ganadas) _InsigniaGanada(insignia: insignia)],
                  ),
                ],
                if (ganadas.isNotEmpty && proximas.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Por ganar', style: texto.labelMedium?.copyWith(color: b.textoSuave)),
                ],
                for (final avance in proximas) ...[
                  const SizedBox(height: 10),
                  _ProximaInsignia(avance: avance),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Medalla extends StatelessWidget {
  final String clave;
  final bool ganada;
  final double tamano;

  const _Medalla({required this.clave, required this.ganada, this.tamano = 52});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final (fondo, icono) = medallas[clave] ?? (b.acento, Icons.star_outline);
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: ganada ? fondo : b.campo,
        shape: BoxShape.circle,
        border: Border.all(color: ganada ? Colors.white.withValues(alpha: 0.45) : b.divisor, width: 2),
      ),
      child: Icon(icono, size: tamano * 0.48, color: ganada ? tintaDeMedalla : b.textoSuave),
    );
  }
}

class _InsigniaGanada extends StatelessWidget {
  final Insignia insignia;

  const _InsigniaGanada({required this.insignia});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Tooltip(
      message: insignia.descripcion,
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label: 'Insignia ${insignia.nombre}: ${insignia.descripcion}',
        excludeSemantics: true,
        child: SizedBox(
          width: 76,
          child: Column(
            children: [
              _Medalla(clave: insignia.clave, ganada: true),
              const SizedBox(height: 6),
              Text(insignia.nombre,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: texto.labelMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProximaInsignia extends StatelessWidget {
  final AvanceDeInsignia avance;

  const _ProximaInsignia({required this.avance});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    return Semantics(
      label: 'Próxima insignia, ${avance.insignia.nombre}: llevas ${avance.llevas} de ${avance.meta} '
          '${avance.unidad}',
      excludeSemantics: true,
      child: Row(
        children: [
          _Medalla(clave: avance.insignia.clave, ganada: false, tamano: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(child: Text(avance.insignia.nombre, style: texto.titleSmall)),
                    Text('${avance.llevas} de ${avance.meta}',
                        style: texto.bodySmall?.copyWith(color: b.textoSuave, fontFeatures: tabularFigures)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: avance.fraccion, minHeight: 6, backgroundColor: b.campo),
                ),
                const SizedBox(height: 4),
                Text(avance.unidad, style: texto.bodySmall?.copyWith(color: b.textoSuave)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Claro para el sol, oscuro para la noche, o lo que diga el teléfono.
class _Apariencia extends StatelessWidget {
  const _Apariencia();

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text('Apariencia', style: texto.titleMedium)),
          const SizedBox(height: 10),
          BlocBuilder<AparienciaCubit, ThemeMode>(
            builder: (context, modo) => SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              // Solo texto: con íconos, «Automático» no cabe en un tercio de un teléfono y se parte a mitad de palabra.
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Automático', maxLines: 1, softWrap: false)),
                ButtonSegment(value: ThemeMode.light, label: Text('Claro', maxLines: 1, softWrap: false)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro', maxLines: 1, softWrap: false)),
              ],
              selected: {modo},
              onSelectionChanged: (elegido) => context.read<AparienciaCubit>().elegir(elegido.first),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compartir dónde va el bus viene activado; aquí se apaga (y se vuelve a prender). Apagarlo pide confirmación.
class _Privacidad extends StatefulWidget {
  const _Privacidad();

  @override
  State<_Privacidad> createState() => _PrivacidadState();
}

class _PrivacidadState extends State<_Privacidad> {
  final _preferencia = PreferenciaDeCompartir();
  bool? _compartir;

  @override
  void initState() {
    super.initState();
    _preferencia.compartir().then((si) {
      if (mounted) setState(() => _compartir = si);
    });
  }

  Future<void> _cambiar(bool si) async {
    if (!si) {
      final seguro = await showDialog<bool>(
        context: context,
        builder: (dialogo) => AlertDialog(
          title: const Text('¿Dejar de compartir?'),
          content: const Text('Quienes esperan el bus tendrán menos datos para saber cuándo llega. '
              'Puedes volver a activarlo aquí cuando quieras.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogo).pop(false), child: const Text('Seguir compartiendo')),
            FilledButton(onPressed: () => Navigator.of(dialogo).pop(true), child: const Text('Dejar de compartir')),
          ],
        ),
      );
      if (seguro != true) return;
    } else {
      await _preferencia.marcarAvisoVisto(); // lo activa aquí, leyendo lo que se comparte
    }
    await _preferencia.guardar(si);
    if (mounted) setState(() => _compartir = si);
  }

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text('Privacidad', style: texto.titleMedium)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _compartir ?? true,
            onChanged: _compartir == null ? null : _cambiar,
            title: const Text('Compartir dónde va el bus'),
            subtitle: Text(
              'En tus viajes, sin tu nombre y solo el tramo en bus. Se borra 5 minutos después.',
              style: texto.bodySmall?.copyWith(color: b.textoSuave),
            ),
          ),
        ],
      ),
    );
  }
}
