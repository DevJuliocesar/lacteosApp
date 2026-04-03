import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/providers/auth_provider.dart';
import 'package:lacteos_app/providers/invoices_provider.dart';
import 'package:lacteos_app/providers/rutas_provider.dart';
import 'package:intl/intl.dart';

class OperarioHomeScreen extends StatefulWidget {
  const OperarioHomeScreen({super.key});

  @override
  State<OperarioHomeScreen> createState() => _OperarioHomeScreenState();
}

class _OperarioHomeScreenState extends State<OperarioHomeScreen> {
  String? _selectedDailyRouteId;
  GoRouter? _router;
  String? _routerPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvoicesProvider>().loadInvoices();
      context.read<RutasProvider>().loadRoutes();
      context.read<RutasProvider>().loadDailyRoutes();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (!identical(_router, router)) {
      _router?.routeInformationProvider.removeListener(_onRouterChanged);
      _router = router;
      _routerPath = router.routeInformationProvider.value.uri.path;
      _router!.routeInformationProvider.addListener(_onRouterChanged);
    }
  }

  @override
  void dispose() {
    _router?.routeInformationProvider.removeListener(_onRouterChanged);
    super.dispose();
  }

  void _onRouterChanged() {
    if (!mounted || _router == null) return;
    final path = _router!.routeInformationProvider.value.uri.path;
    final prev = _routerPath;
    _routerPath = path;
    if (path != '/operario') return;
    final cameFromOperarioFlow = prev != null &&
        prev != '/operario' &&
        prev.startsWith('/operario/');
    if (!cameFromOperarioFlow) return;
    _refreshFromServer();
  }

  Future<void> _refreshFromServer() async {
    if (!mounted) return;
    await context.read<RutasProvider>().loadRoutes();
    if (!mounted) return;
    await context.read<RutasProvider>().loadDailyRoutes();
    if (!mounted) return;
    await context.read<InvoicesProvider>().loadInvoices();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final routesProvider = context.watch<RutasProvider>();
    final routes = routesProvider.routes;
    final dailyRoutes = routesProvider.dailyRoutes;
    final invoices = context.watch<InvoicesProvider>().invoices;
    final myInvoices =
        invoices.where((i) => i.operarioId == user.id).toList();

    final assignedRouteIds = routes
        .where((r) => r.userIds.contains(user.id) && r.isActive)
        .map((r) => r.id)
        .toSet();

    final assignedDailyRoutes = dailyRoutes
        .where((dr) => assignedRouteIds.contains(dr.routeId))
        .toList();
    final selectedDailyRoute = _selectedDailyRouteId == null
        ? null
        : (() {
            try {
              return assignedDailyRoutes
                  .firstWhere((dr) => dr.id == _selectedDailyRouteId);
            } catch (_) {
              return null;
            }
          })();

    final selectedValid = _selectedDailyRouteId != null &&
        assignedDailyRoutes.any((dr) => dr.id == _selectedDailyRouteId);

    if (!selectedValid && _selectedDailyRouteId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedDailyRouteId = null);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hola, ${user.name}',
                    style: Theme.of(context).textTheme.titleLarge),
                Text('Facturas generadas: ${myInvoices.length}',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                Text('Ruta del día',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (assignedDailyRoutes.isEmpty)
                  const Text(
                    'No tienes rutas del día asignadas.',
                    style: TextStyle(color: Colors.grey),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    value: selectedValid ? _selectedDailyRouteId : null,
                    decoration:
                        const InputDecoration(labelText: 'Seleccionar'),
                    items: assignedDailyRoutes
                        .map((dr) => DropdownMenuItem(
                              value: dr.id,
                              child: Text(
                                "${DateFormat('dd/MM/yyyy').format(dr.date)} - ${dr.routeName}",
                              ),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedDailyRouteId = v),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedDailyRouteId == null
                          ? null
                          : () {
                              final dailyRoute = assignedDailyRoutes
                                  .firstWhere(
                                      (dr) => dr.id == _selectedDailyRouteId);
                              context.push('/operario/nueva-factura',
                                  extra: dailyRoute);
                            },
                      child: const Text('Ir a factura'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshFromServer,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 80),
                children: [
                if (selectedDailyRoute != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Productos del día',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  ...selectedDailyRoute.items.map((item) {
                    final total = item.quantity;
                    final available = item.availableQuantity;
                    final progress = total <= 0
                        ? 0.0
                        : (available / total).clamp(0.0, 1.0).toDouble();

                    return ListTile(
                      title: Text(item.productName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 6),
                          Text(
                            'Disponible: ${available.toStringAsFixed(2)} / ${total.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 1),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Mis facturas',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (myInvoices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Aún no has generado facturas')),
                  )
                else
                  ...myInvoices.map((inv) => ListTile(
                        leading: const Icon(Icons.receipt_long),
                        title: Text(inv.clientName),
                        subtitle: Text(
                            '${inv.items.length} productos  •  \$${inv.total.toStringAsFixed(2)}'),
                        trailing: Text(inv.status.name,
                            style: const TextStyle(fontSize: 12)),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
