/// URL base de la API de Karta. Se cambia sin tocar código, por ejemplo
/// para el emulador de Android:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000/api/v1',
);
