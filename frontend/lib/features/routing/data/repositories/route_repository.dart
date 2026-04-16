import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/models/route_models.dart';

class RouteRepository {

  static const String baseUrl = 'http://127.0.0.1:8000/api/v1';

  Future<DecisionResponse> evaluateRoute(double distanceKm) async {
    final url = Uri.parse('$baseUrl/routes/evaluate');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'distancia_km': distanceKm}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DecisionResponse.fromJson(data);
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión con el Cerebro Digital: $e');
    }
  }
}