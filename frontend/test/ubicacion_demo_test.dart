import 'package:flutter_test/flutter_test.dart';
import 'package:karta/core/location_service.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('la ubicación de demostración se lee de «latitud,longitud»', () {
    expect(LocationService.ubicacionDemo('10.413958,-75.524358'), const LatLng(10.413958, -75.524358));
    expect(LocationService.ubicacionDemo(' 10.4 , -75.5 '), const LatLng(10.4, -75.5));
  });

  test('sin ubicación de demostración, o mal escrita, se usa el GPS', () {
    expect(LocationService.ubicacionDemo(''), isNull);
    expect(LocationService.ubicacionDemo('10.4'), isNull);
    expect(LocationService.ubicacionDemo('norte,sur'), isNull);
    expect(LocationService.ubicacionDemo('95,-75.5'), isNull);
  });
}
