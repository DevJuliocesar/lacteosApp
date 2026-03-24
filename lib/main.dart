import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lacteos_app/config/supabase_config.dart';
import 'package:lacteos_app/providers/auth_provider.dart';
import 'package:lacteos_app/providers/config_provider.dart';
import 'package:lacteos_app/providers/products_provider.dart';
import 'package:lacteos_app/providers/invoices_provider.dart';
import 'package:lacteos_app/theme/app_theme.dart';
import 'package:lacteos_app/utils/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(const LacteosApp());
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
