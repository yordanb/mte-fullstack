/// Base URL API yang bisa dioverride saat build/run:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8802`
class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mte2.mibt.my.id/api',
  );
}
