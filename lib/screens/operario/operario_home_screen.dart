import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/providers/auth_provider.dart';
import 'package:lacteos_app/providers/invoices_provider.dart';

class OperarioHomeScreen extends StatefulWidget {
  const OperarioHomeScreen({super.key});

  @override
  State<OperarioHomeScreen> createState() => _OperarioHomeScreenState();
}

class _OperarioHomeScreenState extends State<OperarioHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvoicesProvider>().loadInvoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final invoices = context.watch<InvoicesProvider>().invoices;
    final myInvoices =
        invoices.where((i) => i.operarioId == user.id).toList();

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/operario/nueva-factura'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva factura'),
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
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: myInvoices.isEmpty
                ? const Center(
                    child: Text('Aún no has generado facturas'))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: myInvoices.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final inv = myInvoices[index];
                      return ListTile(
                        leading: const Icon(Icons.receipt_long),
                        title: Text(inv.clientName),
                        subtitle: Text(
                            '${inv.items.length} productos  •  \$${inv.total.toStringAsFixed(2)}'),
                        trailing: Text(inv.status.name,
                            style: const TextStyle(fontSize: 12)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
