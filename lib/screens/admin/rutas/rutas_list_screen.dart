import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/models/ruta.dart';
import 'package:lacteos_app/providers/rutas_provider.dart';

class RutasListScreen extends StatefulWidget {
  const RutasListScreen({super.key});

  @override
  State<RutasListScreen> createState() => _RutasListScreenState();
}

class _RutasListScreenState extends State<RutasListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RutasProvider>().loadRoutes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rutas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/rutas/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva ruta'),
      ),
      body: Consumer<RutasProvider>(
        builder: (_, provider, __) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(child: Text(provider.error!));
          }
          if (provider.routes.isEmpty) {
            return const Center(child: Text('No hay rutas registradas'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: provider.routes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) =>
                _RouteTile(route: provider.routes[index]),
          );
        },
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  final DeliveryRoute route;
  const _RouteTile({required this.route});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            route.isActive ? Colors.green.shade50 : Colors.grey.shade200,
        child: Icon(Icons.route,
            color: route.isActive ? Colors.green : Colors.grey),
      ),
      title: Text(route.name,
          style: TextStyle(
              color: route.isActive ? null : Colors.grey,
              decoration:
                  route.isActive ? null : TextDecoration.lineThrough)),
      subtitle: Text('${route.userIds.length} operario(s)'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.push('/admin/rutas/${route.id}/edit'),
          ),
          _DeleteRouteButton(route: route),
        ],
      ),
    );
  }
}

class _DeleteRouteButton extends StatelessWidget {
  final DeliveryRoute route;
  const _DeleteRouteButton({required this.route});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete_outline, color: Colors.red),
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Eliminar ruta'),
            content: Text('¿Eliminar "${route.name}"?'),
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
          await context.read<RutasProvider>().deleteRoute(route.id);
        }
      },
    );
  }
}
