import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/models/invoice.dart';
import 'package:lacteos_app/models/invoice_item.dart';
import 'package:lacteos_app/models/product.dart';
import 'package:lacteos_app/models/ruta_dia.dart';
import 'package:lacteos_app/providers/auth_provider.dart';
import 'package:lacteos_app/providers/invoices_provider.dart';
import 'package:lacteos_app/providers/products_provider.dart';
import 'package:lacteos_app/providers/rutas_provider.dart';

class OperarioInvoiceEditScreen extends StatefulWidget {
  final String invoiceId;

  const OperarioInvoiceEditScreen({super.key, required this.invoiceId});

  @override
  State<OperarioInvoiceEditScreen> createState() =>
      _OperarioInvoiceEditScreenState();
}

class _OperarioInvoiceEditScreenState extends State<OperarioInvoiceEditScreen> {
  final _clientCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  late Invoice _original;
  final List<InvoiceItem> _items = [];
  bool _loaded = false;
  bool _saving = false;

  DailyRoute? _dailyRouteForInvoice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ProductsProvider>().loadProducts();
      if (!mounted) return;
      await context.read<InvoicesProvider>().loadInvoices();
      if (!mounted) return;
      await context.read<RutasProvider>().loadDailyRoutes();
      if (!mounted) return;
      _loadInvoiceIntoState();
    });
  }

  void _loadInvoiceIntoState() {
    final user = context.read<AuthProvider>().user!;
    final provider = context.read<InvoicesProvider>();
    Invoice? inv;
    for (final i in provider.invoices) {
      if (i.id == widget.invoiceId) {
        inv = i;
        break;
      }
    }
    if (inv == null || inv.operarioId != user.id) {
      setState(() => _loaded = true);
      return;
    }
    if (inv.status != InvoiceStatus.pendiente) {
      setState(() => _loaded = true);
      return;
    }

    DailyRoute? dr;
    if (inv.dailyRouteId != null) {
      for (final r in context.read<RutasProvider>().dailyRoutes) {
        if (r.id == inv.dailyRouteId) {
          dr = r;
          break;
        }
      }
    }

    if (dr != null && !dr.isOpen) {
      setState(() => _loaded = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La ruta del día está cerrada; no se puede editar la factura.',
            ),
          ),
        );
        context.pop();
      });
      return;
    }

    _original = inv;
    _dailyRouteForInvoice = dr;
    _clientCtrl.text = inv.clientName;
    _notesCtrl.text = inv.notes ?? '';
    _items.clear();
    _items.addAll(inv.items
        .map((e) => e.copyWith())
        .toList()); // copy rows so we don't mutate original refs only

    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _clientCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Map<String, double> _maxQtyByProduct() {
    final m = <String, double>{};
    if (_dailyRouteForInvoice == null) return m;
    for (final dr in _dailyRouteForInvoice!.items) {
      final orig = _original.items
          .where((i) => i.productId == dr.productId)
          .fold<double>(0, (a, b) => a + b.quantity);
      m[dr.productId] = dr.availableQuantity + orig;
    }
    return m;
  }

  double _currentQtyForProduct(String productId) {
    return _items
        .where((i) => i.productId == productId)
        .fold<double>(0, (a, b) => a + b.quantity);
  }

  void _removeLine(int index) {
    setState(() => _items.removeAt(index));
  }

  void _updateQty(int index, double q) {
    if (q <= 0 || index < 0 || index >= _items.length) return;
    setState(() {
      final old = _items[index];
      _items[index] = old.copyWith(quantity: q);
    });
  }

  Future<void> _editQuantityDialog(int index, InvoiceItem item) async {
    final ctrl = TextEditingController(text: item.quantity.toString());
    final maxBy = _maxQtyByProduct();
    final cap = maxBy[item.productId];

    final q = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cantidad — ${item.productName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Cantidad (${item.unit})',
              ),
            ),
            if (cap != null) ...[
              const SizedBox(height: 8),
              Text(
                'Tope en esta factura: ${cap.toStringAsFixed(2)} ${item.unit}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(ctrl.text);
              if (parsed == null || parsed <= 0) return;
              if (cap != null) {
                final rest = _currentQtyForProduct(item.productId) -
                    item.quantity;
                if (rest + parsed > cap + 1e-9) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Máximo ${cap.toStringAsFixed(2)} ${item.unit} en total.',
                      ),
                    ),
                  );
                  return;
                }
              }
              Navigator.pop(ctx, parsed);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (q != null && mounted) _updateQty(index, q);
  }

  void _showAddProduct() {
    final products = context.read<ProductsProvider>().activeProducts;
    final allowedIds = _dailyRouteForInvoice?.items.map((e) => e.productId).toSet();
    final list = _dailyRouteForInvoice != null
        ? products.where((p) => allowedIds!.contains(p.id)).toList()
        : products;
    final maxBy = _maxQtyByProduct();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _EditAddProductSheet(
        products: list,
        maxQtyByProduct: _dailyRouteForInvoice != null ? maxBy : null,
        currentQtyFor: _currentQtyForProduct,
      ),
    ).then((added) {
      if (added is InvoiceItem) {

        setState(() {
          final ix =
              _items.indexWhere((i) => i.productId == added.productId);
          if (ix >= 0) {
            final ex = _items[ix];
            _items[ix] =
                ex.copyWith(quantity: ex.quantity + added.quantity);
          } else {
            _items.add(added);
          }
        });
      }
    });
  }

  Future<void> _save() async {
    if (_clientCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el nombre del cliente')),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final goRouter = GoRouter.of(context);
    final invoices = context.read<InvoicesProvider>();
    final rutas = context.read<RutasProvider>();
    final user = context.read<AuthProvider>().user!;
    setState(() => _saving = true);
    try {
      final notes = _notesCtrl.text.trim();
      final dailyRouteId = await invoices.updateOperarioInvoice(
        invoiceId: _original.id,
        operarioId: user.id,
        clientName: _clientCtrl.text.trim(),
        notes: notes.isEmpty ? null : notes,
        items: List<InvoiceItem>.from(_items),
      );
      await rutas.loadDailyRoutes();
      if (!mounted) return;
      if (dailyRouteId != null) {
        await rutas.refreshDailyRouteById(dailyRouteId);
      }
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Factura actualizada')),
      );
      goRouter.pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar factura')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final user = context.watch<AuthProvider>().user!;
    final provider = context.watch<InvoicesProvider>();
    Invoice? inv;
    for (final i in provider.invoices) {
      if (i.id == widget.invoiceId) {
        inv = i;
        break;
      }
    }

    if (inv == null || inv.operarioId != user.id) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar factura')),
        body: const Center(child: Text('Factura no encontrada')),
      );
    }
    if (inv.status != InvoiceStatus.pendiente) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar factura')),
        body: const Center(
            child: Text('Solo se pueden editar facturas pendientes.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Editar factura')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _clientCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Nombre del cliente'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Productos',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    TextButton.icon(
                      onPressed: _showAddProduct,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar'),
                    ),
                  ],
                ),
                if (_items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Sin productos',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ..._items.asMap().entries.map((e) {
                    final i = e.key;
                    final item = e.value;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productName),
                      subtitle: Text(
                        '${item.quantity} ${item.unit}  ×  \$${item.unitPrice.toStringAsFixed(2)} '
                        '= \$${item.subtotal.toStringAsFixed(2)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => _editQuantityDialog(i, item),
                            child: const Text('Cantidad'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.red, size: 20),
                            onPressed: () => _removeLine(i),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar cambios'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditAddProductSheet extends StatefulWidget {
  final List<Product> products;
  final Map<String, double>? maxQtyByProduct;
  final double Function(String productId) currentQtyFor;

  const _EditAddProductSheet({
    required this.products,
    required this.maxQtyByProduct,
    required this.currentQtyFor,
  });

  @override
  State<_EditAddProductSheet> createState() => _EditAddProductSheetState();
}

class _EditAddProductSheetState extends State<_EditAddProductSheet> {
  Product? _selected;
  final _qtyCtrl = TextEditingController(text: '1');
  String? _error;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Agregar producto',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          DropdownButtonFormField<Product>(
            initialValue: _selected,
            decoration: const InputDecoration(labelText: 'Producto'),
            items: widget.products
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(
                          '${p.name} — \$${p.salePrice.toStringAsFixed(2)}/${p.unit}'),
                    ))
                .toList(),
            onChanged: (p) => setState(() {
              _selected = p;
              _error = null;
            }),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _qtyCtrl,
            decoration: const InputDecoration(labelText: 'Cantidad'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_selected == null) {
                  setState(() => _error = 'Selecciona un producto');
                  return;
                }
                final qty = double.tryParse(_qtyCtrl.text);
                if (qty == null || qty <= 0) {
                  setState(() => _error = 'Cantidad inválida');
                  return;
                }
                final maxQ = widget.maxQtyByProduct?[_selected!.id];
                if (maxQ != null) {
                  final cur = widget.currentQtyFor(_selected!.id);
                  if (cur + qty > maxQ + 1e-9) {
                    setState(() {
                      _error =
                          'Máximo para este producto en la factura: ${maxQ.toStringAsFixed(2)} (${_selected!.unit}). '
                          'Ya tienes ${cur.toStringAsFixed(2)}.';
                    });
                    return;
                  }
                }
                final p = _selected!;
                Navigator.pop(
                  context,
                  InvoiceItem(
                    productId: p.id,
                    productName: p.name,
                    unit: p.unit,
                    quantity: qty,
                    unitPrice: p.salePrice,
                  ),
                );
              },
              child: const Text('Agregar'),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
