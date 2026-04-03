import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lacteos_app/models/user.dart';
import 'package:lacteos_app/providers/auth_provider.dart';
import 'package:lacteos_app/screens/auth/login_screen.dart';
import 'package:lacteos_app/screens/auth/set_password_screen.dart';
import 'package:lacteos_app/screens/admin/admin_home_screen.dart';
import 'package:lacteos_app/screens/admin/products/products_list_screen.dart';
import 'package:lacteos_app/screens/admin/products/product_form_screen.dart';
import 'package:lacteos_app/screens/admin/invoices/invoices_list_screen.dart';
import 'package:lacteos_app/screens/admin/invoices/invoice_detail_screen.dart';
import 'package:lacteos_app/screens/admin/users/users_screen.dart';
import 'package:lacteos_app/screens/admin/rutas/rutas_list_screen.dart';
import 'package:lacteos_app/screens/admin/rutas/ruta_form_screen.dart';
import 'package:lacteos_app/screens/admin/rutas/rutas_dia_list_screen.dart';
import 'package:lacteos_app/screens/admin/rutas/ruta_dia_form_screen.dart';
import 'package:lacteos_app/screens/operario/operario_home_screen.dart';
import 'package:lacteos_app/screens/operario/create_invoice_screen.dart';
import 'package:lacteos_app/screens/operario/invoice_preview_screen.dart';
import 'package:lacteos_app/screens/operario/operario_invoice_detail_screen.dart';
import 'package:lacteos_app/screens/operario/operario_invoice_edit_screen.dart';
import 'package:lacteos_app/screens/operario/operario_end_day_screen.dart';
import 'package:lacteos_app/models/ruta_dia.dart';

GoRouter buildRouter(AuthProvider auth) => GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final location = state.matchedLocation;
        if (!auth.isAuthenticated) {
          return location == '/login' ? null : '/login';
        }
        if (auth.needsPasswordSetup) {
          return location == '/set-password' ? null : '/set-password';
        }
        if (location == '/login' || location == '/set-password') {
          return auth.user!.role == UserRole.admin ? '/admin' : '/operario';
        }
        return null;
      },
      refreshListenable: auth,
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/set-password',
          builder: (_, __) => const SetPasswordScreen(),
        ),

        // --- Admin ---
        GoRoute(
          path: '/admin',
          builder: (_, __) => const AdminHomeScreen(),
          routes: [
            GoRoute(
              path: 'products',
              builder: (_, __) => const ProductsListScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, __) => const ProductFormScreen(),
                ),
                GoRoute(
                  path: ':id/edit',
                  builder: (context, state) => ProductFormScreen(
                    productId: state.pathParameters['id'],
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'invoices',
              builder: (_, __) => const InvoicesListScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) => InvoiceDetailScreen(
                    invoiceId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'users',
              builder: (_, __) => const UsersScreen(),
            ),
            GoRoute(
              path: 'rutas',
              builder: (_, __) => const RutasListScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, __) => const RutaFormScreen(),
                ),
                GoRoute(
                  path: ':id/edit',
                  builder: (_, state) =>
                      RutaFormScreen(rutaId: state.pathParameters['id']),
                ),
              ],
            ),
            GoRoute(
              path: 'rutas-dia',
              builder: (_, __) => const RutasDiaListScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, __) => const RutaDiaFormScreen(),
                ),
              ],
            ),
          ],
        ),

        // --- Operario ---
        GoRoute(
          path: '/operario',
          builder: (_, __) => const OperarioHomeScreen(),
          routes: [
            GoRoute(
              path: 'nueva-factura',
              builder: (context, state) {
                final extra = state.extra;
                final dailyRoute = extra is DailyRoute ? extra : null;
                return CreateInvoiceScreen(dailyRoute: dailyRoute);
              },
            ),
            GoRoute(
              path: 'cerrar-dia',
              builder: (context, state) {
                final extra = state.extra;
                final dailyRoute = extra is DailyRoute ? extra : null;
                if (dailyRoute == null) {
                  return const Scaffold(
                    body: Center(child: Text('Ruta del día no válida')),
                  );
                }
                return OperarioEndDayScreen(dailyRoute: dailyRoute);
              },
            ),
            GoRoute(
              path: 'preview',
              builder: (_, __) => const InvoicePreviewScreen(),
            ),
            GoRoute(
              path: 'factura/:id',
              builder: (context, state) => OperarioInvoiceDetailScreen(
                invoiceId: state.pathParameters['id']!,
              ),
              routes: [
                GoRoute(
                  path: 'editar',
                  builder: (context, state) => OperarioInvoiceEditScreen(
                    invoiceId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
