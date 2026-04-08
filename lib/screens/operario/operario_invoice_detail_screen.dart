import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/models/invoice.dart';
import 'package:lacteos_app/providers/auth_provider.dart';
import 'package:lacteos_app/models/ruta_dia.dart';
import 'package:lacteos_app/providers/invoices_provider.dart';
import 'package:lacteos_app/providers/rutas_provider.dart';

class OperarioInvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;

  const OperarioInvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<OperarioInvoiceDetailScreen> createState() =>
      _OperarioInvoiceDetailScreenState();
}

class _OperarioInvoiceDetailScreenState
    extends State<OperarioInvoiceDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<InvoicesProvider>().loadInvoices();
      if (!mounted) return;
      await context.read<RutasProvider>().loadDailyRoutes();
    });
  }

  Future<void> _refreshRutas(String? dailyRouteId) async {
    if (dailyRouteId == null) return;
    final rutas = context.read<RutasProvider>();
    await rutas.loadDailyRoutes();
    if (!mounted) return;
    await rutas.refreshDailyRouteById(dailyRouteId);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Invoice invoice,
    String operarioId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar factura'),
        content: Text(
          '¿Eliminar la factura de "${invoice.clientName}"? '
          'Se revertirá el stock en la ruta del día si aplica.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final goRouter = GoRouter.of(context);
    final invoices = context.read<InvoicesProvider>();
    try {
      final dailyRouteId = await invoices.deleteOperarioInvoice(
        invoiceId: invoice.id,
        operarioId: operarioId,
      );
      await _refreshRutas(dailyRouteId);
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Factura eliminada')),
      );
      goRouter.pop();
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final provider = context.watch<InvoicesProvider>();
    final rutasProvider = context.watch<RutasProvider>();
    Invoice? invoice;
    for (final i in provider.invoices) {
      if (i.id == widget.invoiceId) {
        invoice = i;
        break;
      }
    }

    if (invoice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Factura')),
        body: const Center(child: Text('Factura no encontrada')),
      );
    }

    if (invoice.operarioId != user.id) {
      return Scaffold(
        appBar: AppBar(title: const Text('Factura')),
        body: const Center(child: Text('No autorizado')),
      );
    }

    final inv = invoice;
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    DailyRoute? dailyForInv;
    if (inv.dailyRouteId != null) {
      for (final r in rutasProvider.dailyRoutes) {
        if (r.id == inv.dailyRouteId) {
          dailyForInv = r;
          break;
        }
      }
    }
    final routeClosed = dailyForInv != null && !dailyForInv.isOpen;
    final canMutate =
        inv.status == InvoiceStatus.pendiente && !routeClosed;

    return Scaffold(
      appBar: AppBar(
        title: Text('Factura — ${inv.clientName}'),
        actions: [
          if (canMutate)
            TextButton(
              onPressed: () =>
                  context.push('/operario/factura/${inv.id}/editar'),
              child: const Text('Editar'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoRow('Cliente', inv.clientName),
          _InfoRow('Fecha', fmt.format(inv.createdAt)),
          _InfoRow('Estado', inv.status.name.toUpperCase()),
          if (routeClosed)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'La ruta del día está cerrada: no se puede editar ni eliminar esta factura.',
                style: TextStyle(color: Colors.orange, fontSize: 13),
              ),
            ),
          if (inv.notes != null && inv.notes!.isNotEmpty)
            _InfoRow('Notas', inv.notes!),
          const Divider(height: 32),
          const Text('Productos',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...inv.items.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.productName),
              subtitle: Text(
                '${item.quantity} ${item.unit}  ×  \$${item.unitPrice.toStringAsFixed(2)}'
                '${item.isQualityReturn ? ' • Devolución calidad' : ''}'
                '${item.isExpirationReturn ? ' • Devolución vencimiento' : ''}',
              ),
              trailing: Text(
                '\$${item.subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                '\$${inv.total.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          if (canMutate) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, inv, user.id),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Eliminar factura',
                    style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
