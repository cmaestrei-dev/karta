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

/// Avatar del viajero con sus iniciales y su nivel en una insignia.
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
        children: [
          Container(
            width: tamano,
            height: tamano,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: b.hoja,
              shape: BoxShape.circle,
              border: Border.all(color: b.acento, width: 2),
            ),
            child: usuario.sinCuenta
                ? Icon(Icons.person_outline, size: tamano * 0.5, color: b.texto)
                : Text(
                    usuario.iniciales,
                    style: TextStyle(fontSize: tamano * 0.34, fontWeight: FontWeight.w800, color: b.texto),
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
      applicationLegalese: '© 2026 Camilo Maestre',
      children: const [
        SizedBox(height: 16),
        Text('El tiempo real de Transcaribe, hecho por sus pasajeros. Sin anuncios.'),
        SizedBox(height: 12),
        Text('La app es código abierto bajo la licencia Apache 2.0 y el servidor bajo la GNU AGPL 3.0.'),
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
                  falta == null ? 'Llegaste al nivel más alto.' : 'Te faltan $falta para el nivel ${usuario.nivel + 1}.',
                  style: texto.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Ganas 2 cuando alguien confirma tu reporte y 1 por validar los de otros. '
                  'Si la comunidad desmiente uno tuyo, pierdes 5.',
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
