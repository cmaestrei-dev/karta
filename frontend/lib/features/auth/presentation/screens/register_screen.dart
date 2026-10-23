import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../widgets/auth_layout.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _tipoViajero = 'Residente';
  bool _aceptaTerminos = false;
  // El estado de sesión es compartido: solo se muestran los errores de este formulario.
  bool _enviado = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviado = true);
    context.read<AuthBloc>().add(RegisterRequested(
          nombre: _nombreController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          tipoViajero: _tipoViajero,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      // Al registrarse la sesión queda iniciada: se vuelve a la raíz, donde ya está el mapa.
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: AuthLayout(
        title: 'Crear cuenta',
        subtitle: 'Reporta incidentes y ayuda a otros viajeros de Cartagena.',
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nombreController,
                  textCapitalization: TextCapitalization.words,
                  decoration: authInputDecoration('Nombre', Icons.person_outline),
                  validator: (value) => (value ?? '').trim().isEmpty ? 'Ingresa tu nombre.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: authInputDecoration('Correo', Icons.mail_outline),
                  validator: validateEmail,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: authInputDecoration('Contraseña (mínimo 8 caracteres)', Icons.lock_outline),
                  validator: (value) => (value ?? '').length < 8 ? 'Usa al menos 8 caracteres.' : null,
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Residente', label: Text('Residente'), icon: Icon(Icons.home_outlined)),
                    ButtonSegment(value: 'Turista', label: Text('Turista'), icon: Icon(Icons.luggage_outlined)),
                  ],
                  selected: {_tipoViajero},
                  onSelectionChanged: (seleccion) => setState(() => _tipoViajero = seleccion.first),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _aceptaTerminos,
                  onChanged: (value) => setState(() => _aceptaTerminos = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Autorizo el tratamiento de mis datos personales y de ubicación según la Ley 1581 de 2012.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 16),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_enviado && state is AuthUnauthenticated && state.message != null)
                          AuthErrorText(state.message!),
                        AuthSubmitButton(
                          label: 'Crear cuenta',
                          loading: state is AuthInProgress,
                          onPressed: _aceptaTerminos ? _submit : null,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ya tengo cuenta'),
          ),
        ],
      ),
    );
  }
}
