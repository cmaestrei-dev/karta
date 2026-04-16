import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/routing/data/repositories/route_repository.dart';
import 'features/routing/presentation/bloc/route_bloc.dart';
import 'features/routing/presentation/screens/route_evaluation_screen.dart';

import 'features/incidents/data/repositories/incident_repository.dart';
import 'features/incidents/presentation/bloc/incident_bloc.dart';
import 'features/incidents/presentation/widgets/incident_bottom_sheet.dart';

void main() {
  runApp(const KartaApp());
}

class KartaApp extends StatelessWidget {
  const KartaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (context) => RouteRepository()),
        RepositoryProvider(create: (context) => IncidentRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => RouteBloc(routeRepository: context.read<RouteRepository>())),
          BlocProvider(create: (context) => IncidentBloc(repository: context.read<IncidentRepository>())),
        ],
        
        child: MaterialApp(
          title: 'Karta',
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