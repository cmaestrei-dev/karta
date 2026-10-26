import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karta/core/design/tema.dart';
import 'package:karta/core/widgets/plaque.dart';

/// Los `Semantics(button: true, excludeSemantics: true, …)` que no traen su propio `onTap`: el
/// `excludeSemantics` borra la acción del InkWell de adentro y TalkBack anuncia un botón que no hace nada.
List<String> botonesSinAccion() {
  final hallazgos = <String>[];
  for (final archivo in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!archivo.path.endsWith('.dart')) continue;
    final codigo = archivo.readAsStringSync();
    for (final m in RegExp(r'Semantics\(').allMatches(codigo)) {
      final resto = codigo.substring(m.end, (m.end + 700).clamp(0, codigo.length));
      final hijo = resto.indexOf('child:');
      final argumentos = hijo < 0 ? resto : resto.substring(0, hijo);
      if (!argumentos.contains('excludeSemantics: true') || !RegExp(r'button: (true|\w+ != null)').hasMatch(argumentos)) {
        continue;
      }
      if (!argumentos.contains('onTap:')) {
        final linea = '\n'.allMatches(codigo.substring(0, m.start)).length + 1;
        hallazgos.add('${archivo.path}:$linea');
      }
    }
  }
  return hallazgos;
}

void main() {
  test('todo botón que reemplaza la semántica de su contenido lleva su propia acción de tocar', () {
    expect(botonesSinAccion(), isEmpty);
  });

  testWidgets('TalkBack puede tocar y mantener presionada una placa', (tester) async {
    final semantica = tester.ensureSemantics();
    var tocada = 0, presionada = 0;
    await tester.pumpWidget(MaterialApp(
      theme: TemaBahia.oscuro,
      home: Scaffold(
        body: Center(
          child: MiniPlaque(icon: Icons.home_outlined, label: 'Casa', onTap: () => tocada++, onLongPress: () => presionada++),
        ),
      ),
    ));
    final nodo = tester.getSemantics(find.bySemanticsLabel('Casa'));
    expect(nodo.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(nodo.getSemanticsData().hasAction(SemanticsAction.longPress), isTrue);
    tester.semantics.tap(find.semantics.byLabel('Casa'));
    tester.semantics.longPress(find.semantics.byLabel('Casa'));
    expect((tocada, presionada), (1, 1));
    semantica.dispose();
  });
}
