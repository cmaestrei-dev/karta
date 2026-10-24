import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/bahia.dart';
import '../../../auth/domain/models/usuario.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../places/presentation/cubit/saved_places_cubit.dart';
import '../../../places/presentation/screens/saved_places_screen.dart';

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
            child: Text(
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

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (hoja) => BlocProvider.value(
      value: auth,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) => state is AuthAuthenticated
                    ? _Reputacion(usuario: state.usuario)
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
                leading: const Icon(Icons.logout),
                title: const Text('Cerrar sesión'),
                onTap: () async {
                  Navigator.of(hoja).pop();
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (dialogo) => AlertDialog(
                      title: const Text('¿Cerrar sesión?'),
                      content: const Text('Tendrás que volver a ingresar para reportar y ver tus lugares.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(dialogo).pop(false), child: const Text('Cancelar')),
                        FilledButton(onPressed: () => Navigator.of(dialogo).pop(true), child: const Text('Cerrar sesión')),
                      ],
                    ),
                  );
                  if (confirmar == true && context.mounted) {
                    context.read<SavedPlacesCubit>().clear();
                    auth.add(const LogoutRequested());
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
                    Text(usuario.nombre, style: texto.headlineSmall),
                    Text('Los demás te ven como ${usuario.alias}',
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
