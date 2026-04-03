/// URL y anon key desde compilación: no pongas claves en este archivo.
///
/// Uso local:
/// ```bash
/// cp secrets.json.example secrets.json
/// # editá secrets.json con tus valores
/// flutter run --dart-define-from-file=secrets.json
/// ```
///
/// Release / CI:
/// ```bash
/// flutter build apk --dart-define-from-file=secrets.json
/// ```
///
/// O bien:
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String productImagesBucket = 'product-images';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
