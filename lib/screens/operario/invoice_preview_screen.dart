import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/providers/auth_provider.dart';
import 'package:lacteos_app/providers/invoices_provider.dart';
import 'package:lacteos_app/providers/rutas_provider.dart';

class InvoicePreviewScreen extends StatefulWidget {
  const InvoicePreviewScreen({super.key});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  bool _isSaving = false;

  Future<void> _confirm(
      BuildContext context, String clientName, String notes, String? dailyRouteId) async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final goRouter = GoRouter.of(context);
    try {
      final user = context.read<AuthProvider>().user!;
      final invoices = context.read<InvoicesProvider>();
      final rutas = context.read<RutasProvider>();
      await invoices.submitInvoice(
            operarioId: user.id,
            operarioName: user.name,
            clientName: clientName,
            dailyRouteId: dailyRouteId,
            notes: notes.isEmpty ? null : notes,
          );
      if (!mounted) return;
      if (dailyRouteId != null) {
        await rutas.loadDailyRoutes();
        if (!mounted) return;
        await rutas.refreshDailyRouteById(dailyRouteId);
      }
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Factura generada correctamente')),
      );
      goRouter.go('/operario');
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final clientName = extra?['clientName'] ?? '';
    final notes = extra?['notes'] ?? '';
    final rawDailyRouteId = extra?['dailyRouteId'];
    final dailyRouteId = rawDailyRouteId == null || rawDailyRouteId.toString().isEmpty
        ? null
        : rawDailyRouteId.toString();
    final draft = context.watch<InvoicesProvider>();
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Vista previa')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('FACTURA',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 20)),
                        const SizedBox(height: 8),
                        Text('Cliente: $clientName'),
                        Text('Fecha: ${fmt.format(DateTime.now())}'),
                        if (notes.isNotEmpty) Text('Notas: $notes'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...draft.draftItems.map((item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productName),
                      subtitle: Text(
                          '${item.quantity} ${item.unit}  ×  \$${item.unitPrice.toStringAsFixed(2)}'
                          '${item.isQualityReturn ? ' • Devolución calidad' : ''}'
                          '${item.isExpirationReturn ? ' • Devolución vencimiento' : ''}'),
                      trailing: Text('\$${item.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('\$${draft.draftTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Corregir'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _isSaving ? null : () => _confirm(context, clientName, notes, dailyRouteId),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Confirmar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
