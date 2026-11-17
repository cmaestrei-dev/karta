import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/bahia.dart';
import '../data/politica_repository.dart';

/// La política de tratamiento de datos completa, para leer en la app (Perfil › Privacidad y el aviso de privacidad).
class PoliticaScreen extends StatelessWidget {
  const PoliticaScreen({super.key});

  static Future<void> abrir(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PoliticaScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Política de datos')),
      body: FutureBuilder<Politica>(
        future: context.read<PoliticaRepository>().politica(),
        builder: (context, politica) => switch (politica) {
          AsyncSnapshot(:final data?) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: TextoDePolitica(markdown: data.texto),
            ),
          AsyncSnapshot(hasError: true) => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No pudimos cargar la política. Revisa tu conexión y vuelve a intentarlo.',
                    textAlign: TextAlign.center),
              ),
            ),
          _ => const Center(child: CircularProgressIndicator(semanticsLabel: 'Cargando la política')),
        },
      ),
    );
  }
}

/// El Markdown de la política (títulos, párrafos, listas, negrillas y enlaces) con los estilos de Karta. El texto
/// se puede seleccionar, para copiar el correo de contacto.
class TextoDePolitica extends StatelessWidget {
  final String markdown;

  const TextoDePolitica({super.key, required this.markdown});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final bloques = <Widget>[];
    for (final linea in markdown.split('\n').map((l) => l.trimRight())) {
      if (linea.isEmpty) continue;
      final titulo = RegExp(r'^(#{1,3}) (.*)$').firstMatch(linea);
      final vineta = RegExp(r'^\s*- (.*)$').firstMatch(linea);
      if (titulo != null) {
        final nivel = titulo.group(1)!.length;
        final estilo = [texto.headlineSmall, texto.titleLarge, texto.titleMedium][nivel - 1];
        bloques.add(Padding(
          padding: EdgeInsets.only(top: nivel == 1 ? 0 : 24 - 6.0 * nivel, bottom: 8),
          child: Semantics(header: true, child: Text(titulo.group(2)!, style: estilo)),
        ));
      } else if (vineta != null) {
        bloques.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 9, right: 10),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(color: b.textoSuave, shape: BoxShape.circle),
                ),
              ),
              Expanded(child: _Parrafo(vineta.group(1)!)),
            ],
          ),
        ));
      } else {
        bloques.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: _Parrafo(linea)));
      }
    }
    return SelectionArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: bloques),
    );
  }
}

/// Una línea con **negrillas** y [enlaces](https://…), que se muestran por su texto.
class _Parrafo extends StatelessWidget {
  final String linea;

  const _Parrafo(this.linea);

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodyLarge;
    final partes = <InlineSpan>[];
    final marcas = RegExp(r'\*\*(.+?)\*\*|\[([^\]]+)\]\((https?://[^)\s]+)\)');
    var desde = 0;
    for (final m in marcas.allMatches(linea)) {
      partes.add(TextSpan(text: linea.substring(desde, m.start)));
      partes.add(m.group(1) != null
          ? TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700))
          : TextSpan(text: m.group(2), style: const TextStyle(decoration: TextDecoration.underline)));
      desde = m.end;
    }
    partes.add(TextSpan(text: linea.substring(desde)));
    return Text.rich(TextSpan(style: estilo, children: partes));
  }
}
