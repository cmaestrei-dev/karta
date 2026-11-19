import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api_client.dart';
import '../../../core/design/bahia.dart';
import '../data/corona_repository.dart';
import '../domain/corona_models.dart';

/// En Perfil › Privacidad: participar en las coronas y cómo mostrarse si se reina (política 1.2, sección 8).
class AjustesDeCoronas extends StatefulWidget {
  const AjustesDeCoronas({super.key});

  @override
  State<AjustesDeCoronas> createState() => _AjustesDeCoronasState();
}

class _AjustesDeCoronasState extends State<AjustesDeCoronas> {
  AjustesDeCorona? _ajustes;

  CoronaRepository get _repo => context.read<CoronaRepository>();

  @override
  void initState() {
    super.initState();
    _repo.ajustes().then((a) {
      if (mounted) setState(() => _ajustes = a);
    }).catchError((Object _) {});
  }

  Future<void> _guardar({bool? participa, bool? visible, String? apodo}) async {
    try {
      final nuevos = await _repo.ajustar(participa: participa, visible: visible, apodo: apodo);
      if (mounted) setState(() => _ajustes = nuevos);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      rethrow;
    }
  }

  Future<void> _participar(bool si) async {
    if (!si) {
      final seguro = await showDialog<bool>(
        context: context,
        builder: (dialogo) => AlertDialog(
          title: const Text('¿Dejar las coronas?'),
          content: const Text('Se borran tus aportes en las estaciones y pierdes las coronas que tengas. Puedes volver '
              'a participar cuando quieras, pero empiezas de cero.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogo).pop(false), child: const Text('Seguir participando')),
            FilledButton(onPressed: () => Navigator.of(dialogo).pop(true), child: const Text('Dejarlas')),
          ],
        ),
      );
      if (seguro != true) return;
    }
    await _guardar(participa: si).catchError((Object _) {});
  }

  Future<void> _cambiarApodo() async {
    final campo = TextEditingController(text: _ajustes?.apodo ?? '');
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogo) => StatefulBuilder(
        builder: (dialogo, cambiar) => AlertDialog(
          title: const Text('Tu apodo de karteño'),
          content: TextField(
            controller: campo,
            autofocus: true,
            maxLength: 30,
            decoration: InputDecoration(
              helperText: 'Distinto de tu nombre. Es lo que ven si reinas.',
              helperMaxLines: 2,
              errorText: error,
              errorMaxLines: 3,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogo).pop(), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                try {
                  await _repo.ajustar(apodo: campo.text, visible: campo.text.trim().isNotEmpty);
                  final nuevos = await _repo.ajustes();
                  if (mounted) setState(() => _ajustes = nuevos);
                  if (dialogo.mounted) Navigator.of(dialogo).pop();
                } on ApiException catch (e) {
                  cambiar(() => error = e.message);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    campo.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final a = _ajustes;
    if (a == null) return const SizedBox.shrink();
    final participa = a.participa == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Participar en las coronas de las estaciones'),
          subtitle: const Text('Tus aportes confirmados en una estación cuentan para su corona. Se guardan la '
              'estación y el día por 31 días.'),
          value: participa,
          onChanged: _participar,
        ),
        if (participa) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar mi apodo de karteño si reino'),
            subtitle: Text(a.apodo == null ? 'Si no, te ven como «un karteño».' : 'Te ven como «${a.apodo}».'),
            value: a.visible,
            onChanged: (si) => si && a.apodo == null ? _cambiarApodo() : _guardar(visible: si).catchError((Object _) {}),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Apodo de karteño'),
            subtitle: Text(a.apodo ?? 'Sin apodo', style: TextStyle(color: b.textoSuave)),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _cambiarApodo,
          ),
        ],
      ],
    );
  }
}
