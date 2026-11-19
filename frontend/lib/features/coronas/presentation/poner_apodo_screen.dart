import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api_client.dart';
import '../../../core/design/bahia.dart';
import '../../trip/domain/trip_models.dart';
import '../data/corona_repository.dart';
import 'icono_de_corona.dart';

/// Quien reina le pone el apodo del día a la estación (docs/plan-juego.md). Texto libre: el servidor lo revisa y,
/// si no pasa, dice por qué.
class PonerApodoScreen extends StatefulWidget {
  final Stop estacion;

  const PonerApodoScreen({super.key, required this.estacion});

  static const largoMaximo = 30;
  static const sugerencias = ['Aquí sí pasa el bus', 'La parada madrugadora', 'El mejor raspao', 'Sombrita y brisa'];

  @override
  State<PonerApodoScreen> createState() => _PonerApodoScreenState();
}

class _PonerApodoScreenState extends State<PonerApodoScreen> {
  final _campo = TextEditingController();
  String? _error;
  bool _enviando = false;

  String _escrito = '';

  @override
  void initState() {
    super.initState();
    // Solo si cambia lo escrito: al tocar «Poner apodo» el campo pierde el foco y avisa, sin que cambie el texto.
    _campo.addListener(() {
      if (_campo.text == _escrito) return;
      _escrito = _campo.text;
      setState(() => _error = null);
    });
  }

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  Future<void> _poner() async {
    setState(() => _enviando = true);
    try {
      await context.read<CoronaRepository>().ponerApodo(widget.estacion.id, _campo.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final apodo = _campo.text.trim();
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: b.reportar, shape: BoxShape.circle),
              child: IconoDeCorona(tamano: 52, color: b.sobreReportar),
            ),
          ),
          const SizedBox(height: 16),
          Text('Ahora reinas en ${widget.estacion.nombre}',
              textAlign: TextAlign.center, style: texto.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Ponle el nombre que quieras por 24 horas. Se ve debajo del nombre oficial, nunca en su lugar.',
              textAlign: TextAlign.center, style: texto.bodyMedium?.copyWith(color: b.textoSuave)),
          const SizedBox(height: 20),
          TextField(
            controller: _campo,
            maxLength: PonerApodoScreen.largoMaximo,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'El apodo del día', errorText: _error, errorMaxLines: 3),
            onSubmitted: (_) => apodo.isEmpty || _enviando ? null : _poner(),
          ),
          const SizedBox(height: 4),
          Text('O escoge uno:', style: texto.labelMedium?.copyWith(color: b.textoSuave)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in PonerApodoScreen.sugerencias)
              ChoiceChip(
                label: Text(s),
                selected: apodo == s,
                onSelected: (_) => _campo.text = s,
              ),
          ]),
          if (apodo.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(color: b.tarjeta, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Así se verá', style: texto.labelMedium?.copyWith(color: b.textoSuave)),
                  const SizedBox(height: 6),
                  Text('Estación ${widget.estacion.nombre}', style: texto.titleMedium),
                  const SizedBox(height: 4),
                  Row(children: [
                    IconoDeCorona(tamano: 16, color: b.reportar),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Hoy le dicen «$apodo»', style: texto.bodyMedium)),
                  ]),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Sin groserías, teléfonos, enlaces, publicidad ni política. Si otros viajeros lo reportan, se oculta y '
            'pierdes la corona por 30 días. Te ven como «un karteño»: tu apodo de karteño se activa en Perfil › '
            'Privacidad.',
            style: texto.bodySmall?.copyWith(color: b.textoSuave, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: apodo.isEmpty || _enviando ? null : _poner,
            child: Text(_enviando ? 'Poniéndolo…' : 'Poner apodo'),
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Ahora no')),
        ],
      ),
    );
  }
}
