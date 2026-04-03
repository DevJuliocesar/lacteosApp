import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lacteos_app/config/supabase_config.dart';
import 'package:lacteos_app/providers/auth_provider.dart';
import 'package:lacteos_app/providers/config_provider.dart';
import 'package:lacteos_app/providers/products_provider.dart';
import 'package:lacteos_app/providers/invoices_provider.dart';
import 'package:lacteos_app/providers/rutas_provider.dart';
import 'package:lacteos_app/providers/users_provider.dart';
import 'package:lacteos_app/theme/app_theme.dart';
import 'package:lacteos_app/utils/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!SupabaseConfig.isConfigured) {
    debugPrint(
      'Falta configuración Supabase. Copiá secrets.json.example → secrets.json '
      'y ejecutá: flutter run --dart-define-from-file=secrets.json',
    );
    runApp(const _MissingSupabaseConfigApp());
    return;
  }
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(const LacteosApp());
}

class _MissingSupabaseConfigApp extends StatelessWidget {
  const _MissingSupabaseConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuración incompleta',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Definí SUPABASE_URL y SUPABASE_ANON_KEY al compilar.\n\n'
                  '• Copiá secrets.json.example a secrets.json y completá los valores.\n'
                  '• Luego: flutter run --dart-define-from-file=secrets.json\n\n'
                  'En release:\n'
                  'flutter build apk --dart-define-from-file=secrets.json',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LacteosApp extends StatelessWidget {
  const LacteosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConfigProvider()..loadConfig(), lazy: false),
        ChangeNotifierProvider(create: (_) => ProductsProvider()),
        ChangeNotifierProvider(create: (_) => InvoicesProvider()),
        ChangeNotifierProvider(create: (_) => UsersProvider()),
        ChangeNotifierProvider(create: (_) => RutasProvider()),
      ],
      child: Builder(
        builder: (context) {
          final auth = context.watch<AuthProvider>();
          return MaterialApp.router(
            title: 'Lácteos App',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: buildRouter(auth),
          );
        },
      ),
    );
  }
}
