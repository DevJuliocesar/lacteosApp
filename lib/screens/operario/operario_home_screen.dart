import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/models/invoice.dart';
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
  bool _scheduledClearInvalidSelection = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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

    final routeOpen =
        selectedDailyRoute == null || selectedDailyRoute.isOpen;

    final List<Invoice> invoicesThisRoute = selectedValid
        ? invoices
            .where((i) =>
                i.operarioId == user.id &&
                i.dailyRouteId == _selectedDailyRouteId)
            .toList()
        : <Invoice>[];

    if (!selectedValid &&
        _selectedDailyRouteId != null &&
        !_scheduledClearInvalidSelection) {
      _scheduledClearInvalidSelection = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduledClearInvalidSelection = false;
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
                if (assignedDailyRoutes.isEmpty)
                  Text(
                    'Facturas en jornada: —',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else if (!selectedValid)
                  Text(
                    'Selecciona una ruta del día para ver sus facturas.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                  )
                else
                  Text(
                    'Facturas en esta jornada: ${invoicesThisRoute.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
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
                                "${DateFormat('dd/MM/yyyy').format(dr.date)} — ${dr.routeName}"
                                "${dr.isOpen ? '' : ' (cerrada)'}",
                              ),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedDailyRouteId = v),
                  ),
                  const SizedBox(height: 12),
                  if (!routeOpen)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Esta ruta está cerrada: solo consulta. '
                        'El disponible en camión ya fue retornado al depósito.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.orange.shade900,
                            ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedDailyRouteId == null || !routeOpen
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
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _selectedDailyRouteId == null || !routeOpen
                          ? null
                          : () {
                              final dailyRoute = assignedDailyRoutes
                                  .firstWhere(
                                      (dr) => dr.id == _selectedDailyRouteId);
                              context.push('/operario/cerrar-dia',
                                  extra: dailyRoute);
                            },
                      icon: const Icon(Icons.task_alt_outlined),
                      label: const Text('Terminar el día'),
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
                if (assignedDailyRoutes.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      selectedValid && selectedDailyRoute != null
                          ? 'Mis facturas · ${DateFormat('dd/MM/yyyy').format(selectedDailyRoute.date)} · ${selectedDailyRoute.routeName}'
                          : 'Mis facturas',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (!selectedValid)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      child: Text(
                        'Elige una jornada en el campo de arriba para listar solo las facturas ligadas a esa ruta.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    )
                  else if (invoicesThisRoute.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 24),
                      child: Center(
                        child: Text(
                          'No hay facturas tuyas en esta jornada.',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...invoicesThisRoute.map((inv) => ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: Text(inv.clientName),
                          subtitle: Text(
                              '${inv.items.length} productos  •  \$${inv.total.toStringAsFixed(2)}'),
                          trailing: Text(inv.status.name,
                              style: const TextStyle(fontSize: 12)),
                          onTap: () =>
                              context.push('/operario/factura/${inv.id}'),
                        )),
                ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
