import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/models/invoice.dart';
import 'package:lacteos_app/providers/invoices_provider.dart';

class InvoicesListScreen extends StatelessWidget {
  const InvoicesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Facturas')),
      body: Consumer<InvoicesProvider>(
        builder: (_, provider, __) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.invoices.isEmpty) {
            return const Center(child: Text('No hay facturas registradas'));
          }
          return ListView.separated(
            itemCount: provider.invoices.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final invoice = provider.invoices[index];
              return _InvoiceTile(invoice: invoice);
            },
          );
        },
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final Invoice invoice;

  const _InvoiceTile({required this.invoice});

  Color _statusColor(InvoiceStatus status) => switch (status) {
        InvoiceStatus.pendiente => Colors.orange,
        InvoiceStatus.pagada => Colors.green,
        InvoiceStatus.anulada => Colors.red,
      };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    return ListTile(
      leading: const Icon(Icons.receipt_long),
      title: Text(invoice.clientName,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
          '${invoice.operarioName}  •  ${fmt.format(invoice.createdAt)}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('\$${invoice.total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _statusColor(invoice.status).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              invoice.status.name.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  color: _statusColor(invoice.status),
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      onTap: () => context.push('/admin/invoices/${invoice.id}'),
    );
  }
}
