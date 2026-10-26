import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/bahia.dart';
import '../data/politica_repository.dart';
import 'politica_screen.dart';

/// El aviso de privacidad (Ley 1581; Decreto 1074, arts. 2.2.2.25.3.2 y 2.2.2.25.3.3): antes de recoger cualquier
/// dato, quién es el responsable, qué se trata y para qué, los derechos y cómo leer la política completa. Se acepta
/// con un acto afirmativo («Acepto y continuar»): el silencio o seguir usando la app nunca cuentan. Vuelve a salir si
/// la política cambia.
class AvisoDePrivacidad extends StatefulWidget {
  /// Recibe la versión aceptada.
  final ValueChanged<String> onAceptar;

  /// Ya la había aceptado en otra versión: se dice que cambió.
  final bool porCambio;

  const AvisoDePrivacidad({super.key, required this.onAceptar, this.porCambio = false});

  @override
  State<AvisoDePrivacidad> createState() => _AvisoDePrivacidadState();
}

class _AvisoDePrivacidadState extends State<AvisoDePrivacidad> {
  late Future<Politica> _politica = context.read<PoliticaRepository>().politica();
  bool _mayorDeEdad = false;

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Politica>(
          future: _politica,
          builder: (context, estado) {
            final politica = estado.data;
            if (politica == null) {
              return Center(
                child: estado.hasError
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_outlined, size: 48),
                            const SizedBox(height: 16),
                            Text('Karta necesita internet la primera vez que se abre. Revisa tus datos o tu Wi-Fi.',
                                textAlign: TextAlign.center, style: texto.bodyLarge),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: () => setState(
                                  () => _politica = context.read<PoliticaRepository>().politica()),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : const CircularProgressIndicator(semanticsLabel: 'Abriendo Karta'),
              );
            }
            Widget punto(IconData icono, String linea) => Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icono, size: 22, color: b.acento),
                      const SizedBox(width: 14),
                      Expanded(child: Text(linea, style: texto.bodyLarge)),
                    ],
                  ),
                );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(widget.porCambio ? 'Actualizamos la política de datos' : 'Antes de empezar',
                              style: texto.headlineMedium),
                        ),
                        const SizedBox(height: 10),
                        Text('Karta funciona con lo que comparten sus viajeros. Esto es lo que necesitas saber '
                            'sobre tus datos:', style: texto.bodyLarge?.copyWith(color: b.textoSuave)),
                        punto(Icons.person_off_outlined,
                            'No te pedimos nombre ni correo: tu cuenta es un código al azar en este teléfono.'),
                        punto(Icons.place_outlined,
                            'Tu ubicación sirve para planificar y mostrar lo que está cerca, sin guardarla. Puedes '
                            'negarla y elegir el punto de partida a mano.'),
                        punto(Icons.sensors,
                            'En tus viajes en bus se comparte dónde va el bus, sin tu nombre, y se borra a los 5 '
                            'minutos. Te lo explicamos antes del primer viaje y lo apagas cuando quieras.'),
                        punto(Icons.campaign_outlined,
                            'Tus reportes se muestran a todos con tu alias y se borran solos en horas.'),
                        punto(Icons.cloud_outlined,
                            'Los datos se guardan en servidores de Amazon Web Services y MongoDB en Estados Unidos. '
                            'No hay publicidad y no vendemos datos.'),
                        punto(Icons.verified_user_outlined,
                            'Puedes conocer, corregir y borrar tus datos, y retirar esta autorización, desde Perfil › '
                            'Privacidad o escribiendo a ${politica.correo}.'),
                        const SizedBox(height: 18),
                        Text('Responsable: ${politica.responsable}, Cartagena · ${politica.correo}',
                            style: texto.bodySmall?.copyWith(color: b.textoSuave)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 48)),
                            onPressed: () => PoliticaScreen.abrir(context),
                            child: Text('Leer la política completa (versión ${politica.version})'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CheckboxListTile(
                        value: _mayorDeEdad,
                        onChanged: (si) => setState(() => _mayorDeEdad = si ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Tengo 18 años o más'),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: FilledButton(
                          onPressed: _mayorDeEdad ? () => widget.onAceptar(politica.version) : null,
                          child: const Text('Acepto y continuar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
