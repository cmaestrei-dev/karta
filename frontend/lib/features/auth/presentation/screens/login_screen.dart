import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../widgets/auth_layout.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // Oculta errores ajenos (p. ej. del registro) al volver a esta pantalla.
  bool _mostrarError = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _mostrarError = true);
    context.read<AuthBloc>().add(LoginRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Karta',
      subtitle: 'Muévete por Cartagena con la información de tu comunidad.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: authInputDecoration('Correo', Icons.mail_outline),
                validator: validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: authInputDecoration('Contraseña', Icons.lock_outline),
                validator: (value) => (value ?? '').isEmpty ? 'Ingresa tu contraseña.' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_mostrarError && state is AuthUnauthenticated && state.message != null)
                        AuthErrorText(state.message!),
                      AuthSubmitButton(label: 'Ingresar', loading: state is AuthInProgress, onPressed: _submit),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() => _mostrarError = false);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
          },
          child: const Text('¿No tienes cuenta? Regístrate'),
        ),
      ],
    );
  }
}
