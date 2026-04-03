import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/models/daily_route_extra_expense.dart';
import 'package:lacteos_app/models/invoice.dart';
import 'package:lacteos_app/models/ruta_dia.dart';
import 'package:lacteos_app/providers/invoices_provider.dart';
import 'package:lacteos_app/providers/rutas_provider.dart';

class _ExpenseLine {
  _ExpenseLine()
      : description = TextEditingController(),
        amount = TextEditingController();

  final TextEditingController description;
  final TextEditingController amount;

  void dispose() {
    description.dispose();
    amount.dispose();
  }
}

/// Resumen de cierre: balance de productos, total facturado, gastos extras, confirmación de retorno al depósito.
class OperarioEndDayScreen extends StatefulWidget {
  final DailyRoute dailyRoute;

  const OperarioEndDayScreen({super.key, required this.dailyRoute});

  @override
  State<OperarioEndDayScreen> createState() => _OperarioEndDayScreenState();
}

class _OperarioEndDayScreenState extends State<OperarioEndDayScreen> {
  bool _busy = false;
  DailyRoute? _route;
  final List<_ExpenseLine> _expenseLines = [];

  @override
  void initState() {
    super.initState();
    _route = widget.dailyRoute;
    _expenseLines.add(_ExpenseLine());
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshRoute());
  }

  @override
  void dispose() {
    for (final l in _expenseLines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _refreshRoute() async {
    await context.read<InvoicesProvider>().loadInvoices();
    if (!mounted) return;
    await context.read<RutasProvider>().refreshDailyRouteById(widget.dailyRoute.id);
    if (!mounted) return;
    final list = context.read<RutasProvider>().dailyRoutes;
    final i = list.indexWhere((r) => r.id == widget.dailyRoute.id);
    if (i >= 0) {
      setState(() => _route = list[i]);
    }
  }

  void _addExpenseLine() {
    setState(() => _expenseLines.add(_ExpenseLine()));
  }

  void _removeExpenseLine(int index) {
    if (_expenseLines.length <= 1) {
      _expenseLines[index].description.clear();
      _expenseLines[index].amount.clear();
      setState(() {});
      return;
    }
    _expenseLines[index].dispose();
    _expenseLines.removeAt(index);
    setState(() {});
  }

  double? _parseAmount(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  /// Filas completas para el RPC; null si hay fila incompleta o monto inválido.
  List<Map<String, dynamic>>? _collectExpensesOrError() {
    final out = <Map<String, dynamic>>[];
    for (final line in _expenseLines) {
      final d = line.description.text.trim();
      final a = line.amount.text.trim();
      if (d.isEmpty && a.isEmpty) continue;
      if (d.isEmpty || a.isEmpty) {
        return null;
      }
      final v = _parseAmount(a);
      if (v == null || v < 0) {
        return null;
      }
      out.add(DailyRouteExtraExpense(description: d, amount: v).toRpcJson());
    }
    return out;
  }

  double _totalExpensesDraft() {
    double sum = 0;
    for (final line in _expenseLines) {
      final d = line.description.text.trim();
      final a = line.amount.text.trim();
      if (d.isEmpty && a.isEmpty) continue;
      final v = _parseAmount(a);
      if (v != null && v > 0) sum += v;
    }
    return sum;
  }

  Future<void> _confirmClose(DailyRoute route) async {
    final expenses = _collectExpensesOrError();
    if (expenses == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Revisa los gastos: cada fila debe tener descripción y monto válido (≥ 0), o déjalas vacías.',
          ),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminar el día'),
        content: Text(
          'Se registrará como retorno todo lo disponible en el camión, se guardará el stock '
          'y los gastos extras indicados (${expenses.length} ítem${expenses.length == 1 ? '' : 's'}). '
          'No podrás crear ni editar facturas de esta ruta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final goRouter = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      await context.read<RutasProvider>().closeDailyRoute(
            route.id,
            extraExpenses: expenses,
          );
      if (!mounted) return;
      await context.read<InvoicesProvider>().loadInvoices();
      messenger.showSnackBar(
        const SnackBar(content: Text('Jornada cerrada correctamente')),
      );
      goRouter.pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = _route ?? widget.dailyRoute;
    final fmt = DateFormat('dd/MM/yyyy');
    final invoices = context.watch<InvoicesProvider>().invoices;
    final routeInvoices = invoices
        .where((i) =>
            i.dailyRouteId == route.id && i.status != InvoiceStatus.anulada)
        .toList();
    final totalFacturado =
        routeInvoices.fold<double>(0, (s, i) => s + i.total);
    final totalGastos = _totalExpensesDraft();
    final liquido = totalFacturado - totalGastos;

    if (!route.isOpen) {
      return Scaffold(
        appBar: AppBar(title: const Text('Terminar el día')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Esta jornada ya está cerrada (${fmt.format(route.date)} — ${route.routeName}).',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.pop(),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Terminar el día')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              Text(
                '${route.routeName} · ${fmt.format(route.date)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resumen facturado',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${routeInvoices.length} factura(s) vigentes',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total facturado: \$${totalFacturado.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Gastos extras (estimado): \$${totalGastos.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Text(
                        'Líquido estimado: \$${liquido.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: liquido >= 0 ? null : Colors.red,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Gastos extras',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addExpenseLine,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Agregar'),
                  ),
                ],
              ),
              Text(
                'Describe cada gasto (ej. peaje, combustible) y el valor en pesos.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              ),
              const SizedBox(height: 8),
              ...List.generate(_expenseLines.length, (index) {
                final line = _expenseLines[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: line.description,
                              decoration: const InputDecoration(
                                labelText: 'Descripción',
                                isDense: true,
                              ),
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: line.amount,
                              decoration: const InputDecoration(
                                labelText: 'Valor \$',
                                isDense: true,
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Quitar fila',
                            onPressed: () => _removeExpenseLine(index),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Text(
                'Balance de productos',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Lo cargado menos lo vendido: lo que queda disponible volverá al depósito como retorno.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              ),
              const SizedBox(height: 12),
              ...route.items.map((item) {
                final u = item.unit.isEmpty ? '' : ' ${item.unit}';
                final retorna = item.availableQuantity;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(item.productName),
                    subtitle: Text(
                      'Salida: ${item.quantity.toStringAsFixed(2)}$u · '
                      'Vendido: ${item.soldQuantity.toStringAsFixed(2)}$u · '
                      'Ya retornado: ${item.returnedQuantity.toStringAsFixed(2)}$u',
                    ),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Retorna',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          '${retorna.toStringAsFixed(2)}$u',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: FilledButton(
              onPressed: _busy ? null : () => _confirmClose(route),
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmar cierre del día'),
            ),
          ),
        ],
      ),
    );
  }
}
