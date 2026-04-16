import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/routing/data/repositories/route_repository.dart';
import 'features/routing/presentation/bloc/route_bloc.dart';
import 'features/routing/presentation/screens/route_evaluation_screen.dart';

void main() {
  runApp(const KartaApp());
}

class KartaApp extends StatelessWidget {
  const KartaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Proveemos el Repositorio a nivel global (Capa de Datos)
    return RepositoryProvider(
      create: (context) => RouteRepository(),
      
      // 2. Proveemos el BLoC, inyectándole el Repositorio (Capa de Lógica)
      child: BlocProvider(
        create: (context) => RouteBloc(
          routeRepository: context.read<RouteRepository>(),
        ),
        
        // 3. Configuramos la App con el tema Minimalista Urbano Premium
        child: MaterialApp(
          title: 'Cartagena en Ruta',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            primaryColor: Colors.white,
            useMaterial3: true,
          ),
          home: const RouteEvaluationScreen(),
        ),
      ),
    );
  }
}