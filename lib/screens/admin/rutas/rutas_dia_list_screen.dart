import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/models/ruta_dia.dart';
import 'package:lacteos_app/providers/rutas_provider.dart';

class RutasDiaListScreen extends StatefulWidget {
  const RutasDiaListScreen({super.key});

  @override
  State<RutasDiaListScreen> createState() => _RutasDiaListScreenState();
}

class _RutasDiaListScreenState extends State<RutasDiaListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RutasProvider>().loadDailyRoutes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rutas del día')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/rutas-dia/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva ruta del día'),
      ),
      body: Consumer<RutasProvider>(
        builder: (_, provider, __) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(child: Text(provider.error!));
          }
          if (provider.dailyRoutes.isEmpty) {
            return const Center(child: Text('No hay rutas del día registradas'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: provider.dailyRoutes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) =>
                _DailyRouteTile(dailyRoute: provider.dailyRoutes[index]),
          );
        },
      ),
    );
  }
}

class _DailyRouteTile extends StatelessWidget {
  final DailyRoute dailyRoute;
  const _DailyRouteTile({required this.dailyRoute});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy').format(dailyRoute.date);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.shade50,
        child: const Icon(Icons.today_outlined, color: Colors.blue),
      ),
      title: Text(dailyRoute.routeName),
      subtitle: Text(
        '$dateStr  •  ${dailyRoute.items.length} producto(s)'
        '${dailyRoute.isOpen ? '' : '  •  Cerrada'}',
      ),
      trailing: _DeleteDailyRouteButton(dailyRoute: dailyRoute),
      onTap: () => _showDetail(context, dailyRoute),
    );
  }

  void _showDetail(BuildContext context, DailyRoute dailyRoute) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _DailyRouteDetail(dailyRoute: dailyRoute),
    );
  }
}

class _DailyRouteDetail extends StatelessWidget {
  final DailyRoute dailyRoute;
  const _DailyRouteDetail({required this.dailyRoute});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dailyRoute.routeName,
              style: Theme.of(context).textTheme.titleLarge),
          Text(DateFormat('dd/MM/yyyy').format(dailyRoute.date),
              style: Theme.of(context).textTheme.bodySmall),
          const Divider(height: 24),
          Text('Productos', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...dailyRoute.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.productName),
                    Text('${item.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DeleteDailyRouteButton extends StatelessWidget {
  final DailyRoute dailyRoute;
  const _DeleteDailyRouteButton({required this.dailyRoute});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete_outline, color: Colors.red),
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Eliminar ruta del día'),
            content: Text(
                '¿Eliminar la ruta "${dailyRoute.routeName}" del ${DateFormat('dd/MM/yyyy').format(dailyRoute.date)}?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Eliminar',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          await context.read<RutasProvider>().deleteDailyRoute(dailyRoute.id);
        }
      },
    );
  }
}
