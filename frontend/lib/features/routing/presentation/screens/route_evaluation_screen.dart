import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../incidents/presentation/bloc/incident_bloc.dart';
import '../../../incidents/presentation/widgets/incident_bottom_sheet.dart';
import '../../domain/models/route_risk.dart';
import '../bloc/route_bloc.dart';
import '../bloc/route_event.dart';
import '../bloc/route_state.dart';
import '../risk_style.dart';

class RouteEvaluationScreen extends StatelessWidget {
  const RouteEvaluationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          BlocBuilder<RouteBloc, RouteState>(
            builder: (context, routeState) {

              List<LatLng> currentRoute = [];
              if (routeState is RouteTraced) {
                currentRoute = routeState.routePoints;
              } else if (routeState is RouteRiskEvaluated) {
                currentRoute = routeState.routePoints;
              }

              return BlocBuilder<IncidentBloc, IncidentState>(
                // Solo se redibuja con una lista nueva: mientras se envía o recarga
                // un reporte, el mapa conserva los marcadores anteriores.
                buildWhen: (previous, current) => current is IncidentsLoaded,
                builder: (context, incidentState) {
                  List<Marker> mapMarkers = [];

                  if (incidentState is IncidentsLoaded) {
                    mapMarkers = incidentState.incidents.map((incident) {
                      return Marker(
                        point: LatLng(incident.latitud, incident.longitud),
                        width: 40,
                        height: 40,
                        child: Tooltip(
                          message: 'Alerta: ${incident.categoria}',
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.redAccent,
                            size: 40,
                          ),
                        ),
                      );
                    }).toList();
                  }

                  return FlutterMap(
                    options: const MapOptions(
                      initialCenter: LatLng(10.4233, -75.5496),
                      initialZoom: 13.5,
                    ),
                    children: [
                      // Teselas públicas de OpenStreetMap (sin API key) invertidas a modo oscuro.
                      // Su política de uso exige atribución visible y no admite tráfico de producción.
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.karta.app',
                        tileBuilder: darkModeTileBuilder,
                      ),
                      PolylineLayer(
                        polylines: [
                          if (currentRoute.isNotEmpty)
                            Polyline(
                              points: currentRoute,
                              color: Colors.blueAccent,
                              strokeWidth: 4.0,
                            ),
                        ],
                      ),
                      MarkerLayer(
                        markers: mapMarkers,
                      ),
                      const SimpleAttributionWidget(
                        source: Text('OpenStreetMap contributors'),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: AppBar(
                title: const Text('Karta', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.warning_rounded, color: Colors.amberAccent),
                      onPressed: () => IncidentBottomSheet.show(context),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: BlocBuilder<RouteBloc, RouteState>(
              builder: (context, state) {
                if (state is RouteInitial) {
                  return _buildInitialCard(context, null);
                } else if (state is RouteLoading) {
                  return _buildLoadingCard();
                } else if (state is RouteTraced) {
                  return _buildInitialCard(context, state.routePoints);
                } else if (state is RouteError) {
                  return _buildErrorCard(state.message, context);
                } else if (state is RouteRiskEvaluated) {
                  return _buildRiskCard(state.routeRisk, context);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialCard(BuildContext context, List<LatLng>? currentRoute) {
    final bool isRouteTraced = currentRoute != null && currentRoute.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Destino Frecuente', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          const Text('Bocagrande', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Desde tu ubicación actual', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.map),
              label: Text(isRouteTraced ? 'Ruta Satelital Trazada' : 'Trazar Ruta Satelital', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: isRouteTraced ? null : () {
                const end = LatLng(10.3986, -75.5532);
                context.read<RouteBloc>().add(const TraceRealRouteEvent(end: end));
              },
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isRouteTraced ? Colors.redAccent : Colors.grey,
                side: BorderSide(color: isRouteTraced ? Colors.redAccent : Colors.grey),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.radar),
              label: const Text('Escanear Riesgo Táctico', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: isRouteTraced
                ? () {
                    context.read<RouteBloc>().add(EvaluateRouteRiskEvent(routePoints: currentRoute));
                  }
                : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskCard(RouteRisk risk, BuildContext context) {
    final style = RiskStyle.forLevel(risk.nivel);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.color.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(color: style.color.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(style.icon, color: style.color, size: 32),
              const SizedBox(width: 12),
              Text('Alerta: ${risk.nivel}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: style.color)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: style.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: Text('Score: ${risk.score}', style: TextStyle(color: style.color, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Se detectaron ${risk.totalIncidentes} incidentes reportados cerca de esta ruta.',
            style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.white),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: style.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                context.read<RouteBloc>().add(ResetRouteEvent());
              },
              child: const Text('Comprendido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildErrorCard(String message, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Error del radar: ${message.replaceAll('Exception: ', '')}',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
            ),
            onPressed: () {
              context.read<RouteBloc>().add(ResetRouteEvent());
            },
            child: const Text('Volver a intentar'),
          ),
        ],
      ),
    );
  }
}
