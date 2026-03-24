import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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
import 'package:lacteos_app/screens/operario/operario_home_screen.dart';
import 'package:lacteos_app/screens/operario/create_invoice_screen.dart';
import 'package:lacteos_app/screens/operario/invoice_preview_screen.dart';

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
          ],
        ),

        // --- Operario ---
        GoRoute(
          path: '/operario',
          builder: (_, __) => const OperarioHomeScreen(),
          routes: [
            GoRoute(
              path: 'nueva-factura',
              builder: (_, __) => const CreateInvoiceScreen(),
            ),
            GoRoute(
              path: 'preview',
              builder: (_, __) => const InvoicePreviewScreen(),
            ),
          ],
        ),
      ],
    );
