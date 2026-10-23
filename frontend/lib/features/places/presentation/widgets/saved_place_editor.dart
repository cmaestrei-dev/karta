import 'package:flutter/material.dart';

import '../../domain/place_models.dart';

/// Resultado del editor: nombre e ícono elegidos.
typedef SavedPlaceDraft = ({String nombre, SavedPlaceIcon icono});

/// Hoja para nombrar un lugar guardado y elegir su ícono (crear o editar).
Future<SavedPlaceDraft?> showSavedPlaceEditor(
  BuildContext context, {
  required String titulo,
  required String nombreInicial,
  SavedPlaceIcon iconoInicial = SavedPlaceIcon.favorito,
  String accion = 'Guardar',
}) {
  return showModalBottomSheet<SavedPlaceDraft>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SavedPlaceEditor(titulo: titulo, nombreInicial: nombreInicial, iconoInicial: iconoInicial, accion: accion),
  );
}

class _SavedPlaceEditor extends StatefulWidget {
  final String titulo;
  final String nombreInicial;
  final SavedPlaceIcon iconoInicial;
  final String accion;

  const _SavedPlaceEditor({required this.titulo, required this.nombreInicial, required this.iconoInicial, required this.accion});

  @override
  State<_SavedPlaceEditor> createState() => _SavedPlaceEditorState();
}

class _SavedPlaceEditorState extends State<_SavedPlaceEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.nombreInicial);
  late SavedPlaceIcon _icono = widget.iconoInicial;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop<SavedPlaceDraft>((nombre: _nombre.text.trim(), icono: _icono));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.titulo, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombre,
                maxLength: 40,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Casa, Trabajo, Universidad…'),
                validator: (valor) => (valor ?? '').trim().isEmpty ? 'Ponle un nombre.' : null,
                onFieldSubmitted: (_) => _guardar(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final icono in SavedPlaceIcon.values)
                    ChoiceChip(
                      avatar: Icon(icono.icono, size: 18),
                      label: Text(icono.etiqueta),
                      selected: _icono == icono,
                      onSelected: (_) => setState(() => _icono = icono),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _guardar, child: Text(widget.accion)),
            ],
          ),
        ),
      ),
    );
  }
}
