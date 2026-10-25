import 'package:flutter/material.dart';

import '../../../../core/widgets/plaque.dart';

/// Estructura común de las pantallas de inicio de sesión y registro: la marca en su placa. Se abren desde el
/// perfil, así que llevan el botón de volver.
class AuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const AuthLayout({super.key, required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (Navigator.of(context).canPop())
                    const Align(alignment: Alignment.centerLeft, child: BackButton()),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Plaque(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text(title, style: texto.headlineLarge?.copyWith(color: scheme.primary)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(subtitle, style: texto.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 32),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón principal que se reemplaza por un indicador mientras la petición está en curso.
class AuthSubmitButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const AuthSubmitButton({super.key, required this.label, required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? Semantics(
              label: 'Cargando',
              child: const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : Text(label),
    );
  }
}

class AuthErrorText extends StatelessWidget {
  final String message;

  const AuthErrorText(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 20, color: scheme.error),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: TextStyle(color: scheme.error))),
          ],
        ),
      ),
    );
  }
}

InputDecoration authInputDecoration(String label, IconData icon) {
  return InputDecoration(labelText: label, prefixIcon: Icon(icon));
}

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Ingresa un correo válido.';
  return null;
}
