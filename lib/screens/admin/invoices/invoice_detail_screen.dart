import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/models/invoice.dart';
import 'package:lacteos_app/providers/invoices_provider.dart';

class InvoiceDetailScreen extends StatelessWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoicesProvider>();
    final invoice = provider.invoices.where((i) => i.id == invoiceId).firstOrNull;

    if (invoice == null) {
      return Scaffold(
          appBar: AppBar(), body: const Center(child: Text('Factura no encontrada')));
    }

    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text('Factura #${invoice.id}'),
        actions: [
          if (invoice.status == InvoiceStatus.pendiente)
            PopupMenuButton<InvoiceStatus>(
              onSelected: (status) =>
                  context.read<InvoicesProvider>().updateStatus(invoice.id, status),
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: InvoiceStatus.pagada,
                    child: Text('Marcar como pagada')),
                const PopupMenuItem(
                    value: InvoiceStatus.anulada,
                    child: Text('Anular factura')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoRow('Cliente', invoice.clientName),
          _InfoRow('Operario', invoice.operarioName),
          _InfoRow('Fecha', fmt.format(invoice.createdAt)),
          _InfoRow('Estado', invoice.status.name.toUpperCase()),
          if (invoice.notes != null) _InfoRow('Notas', invoice.notes!),
          const Divider(height: 32),
          const Text('Detalle',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...invoice.items.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.productName),
              subtitle: Text(
                  '${item.quantity} ${item.unit}  ×  \$${item.unitPrice.toStringAsFixed(2)}'
                  '${item.isQualityReturn ? ' • Devolución calidad' : ''}'
                  '${item.isExpirationReturn ? ' • Devolución vencimiento' : ''}'),
              trailing: Text('\$${item.subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Text('\$${invoice.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
