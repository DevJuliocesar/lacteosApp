import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/providers/auth_provider.dart';
import 'package:lacteos_app/providers/invoices_provider.dart';
import 'package:lacteos_app/providers/products_provider.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductsProvider>().loadProducts();
      context.read<InvoicesProvider>().loadInvoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Bienvenido, ${user.name}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          _SummaryRow(),
          const SizedBox(height: 24),
          _MenuCard(
            icon: Icons.inventory_2_outlined,
            title: 'Productos',
            subtitle: 'Agregar, editar y gestionar productos',
            onTap: () => context.push('/admin/products'),
          ),
          const SizedBox(height: 12),
          _MenuCard(
            icon: Icons.receipt_long_outlined,
            title: 'Facturas',
            subtitle: 'Revisar facturas generadas por operarios',
            onTap: () => context.push('/admin/invoices'),
          ),
          const SizedBox(height: 12),
          _MenuCard(
            icon: Icons.group_outlined,
            title: 'Operarios',
            subtitle: 'Invitar y gestionar operarios',
            onTap: () => context.push('/admin/users'),
          ),
          const SizedBox(height: 12),
          _MenuCard(
            icon: Icons.route_outlined,
            title: 'Rutas',
            subtitle: 'Crear y asignar rutas a operarios',
            onTap: () => context.push('/admin/rutas'),
          ),
          const SizedBox(height: 12),
          _MenuCard(
            icon: Icons.today_outlined,
            title: 'Rutas del día',
            subtitle: 'Planificar carga de productos por ruta',
            onTap: () => context.push('/admin/rutas-dia'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductsProvider>().products;
    final invoices = context.watch<InvoicesProvider>().invoices;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Productos',
            value: '${products.length}',
            icon: Icons.inventory_2,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Facturas',
            value: '${invoices.length}',
            icon: Icons.receipt,
            color: Colors.green,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(label,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
