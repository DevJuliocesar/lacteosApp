import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/models/product.dart';
import 'package:lacteos_app/models/ruta_dia.dart';
import 'package:lacteos_app/providers/invoices_provider.dart';
import 'package:lacteos_app/providers/products_provider.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final DailyRoute? dailyRoute;

  const CreateInvoiceScreen({super.key, this.dailyRoute});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _clientCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool get _hasDailyRoute => widget.dailyRoute != null;
  late final List<String> _allowedProductIds =
      widget.dailyRoute?.items.map((i) => i.productId).toSet().toList() ??
          <String>[];
  late final Map<String, double> _availableByProduct = {
    for (final item in widget.dailyRoute?.items ?? <DailyRouteItem>[])
      item.productId: item.availableQuantity,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = widget.dailyRoute;
      if (route != null && !route.isOpen) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Esta ruta del día está cerrada; no puedes emitir facturas.',
            ),
          ),
        );
        context.pop();
        return;
      }
      context.read<ProductsProvider>().loadProducts();
      context.read<InvoicesProvider>().clearDraft();
    });
  }

  @override
  void dispose() {
    _clientCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _showAddProductDialog(BuildContext context) {
    final productsProvider = context.read<ProductsProvider>();
    final activeProducts = productsProvider.activeProducts;
    final products = _hasDailyRoute
        ? activeProducts
            .where((p) => _allowedProductIds.contains(p.id))
            .toList()
        : activeProducts;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _AddProductSheet(
        products: products,
        availableByProduct: _hasDailyRoute ? _availableByProduct : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<InvoicesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva factura')),
      body: Column(
        children: [
          if (_hasDailyRoute)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'Ruta del día: ${widget.dailyRoute!.routeName}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
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
                      onPressed: () => _showAddProductDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar'),
                    ),
                  ],
                ),
                if (draft.draftItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: Text('Agrega productos a la factura',
                            style: TextStyle(color: Colors.grey))),
                  )
                else
                  ...draft.draftItems.map((item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.productName),
                        subtitle: Text(
                            '${item.quantity} ${item.unit}  ×  \$${item.unitPrice.toStringAsFixed(2)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('\$${item.subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 18, color: Colors.red),
                              onPressed: () => context
                                  .read<InvoicesProvider>()
                                  .removeFromDraft(item.productId),
                            ),
                          ],
                        ),
                      )),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Notas (opcional)'),
                  maxLines: 3,
                  minLines: 1,
                ),
              ],
            ),
          ),
          if (draft.hasDraftItems)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(blurRadius: 8, color: Colors.black12)
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total: \$${draft.draftTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_clientCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Ingresa el nombre del cliente')),
                        );
                        return;
                      }
                      context.push('/operario/preview', extra: {
                        'clientName': _clientCtrl.text.trim(),
                        'notes': _notesCtrl.text.trim(),
                        'dailyRouteId': widget.dailyRoute?.id,
                      });
                    },
                    child: const Text('Revisar factura'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AddProductSheet extends StatefulWidget {
  final List<Product> products;
  final Map<String, double>? availableByProduct;

  const _AddProductSheet({
    required this.products,
    this.availableByProduct,
  });

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
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
          left: 16, right: 16, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Agregar producto',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          DropdownButtonFormField<Product>(
            value: _selected,
            decoration: const InputDecoration(labelText: 'Producto'),
            items: widget.products
                .map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(
                        '${p.name} — \$${p.salePrice.toStringAsFixed(2)}/${p.unit}')))
                .toList(),
            onChanged: (p) => setState(() => _selected = p),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _qtyCtrl,
            decoration: const InputDecoration(labelText: 'Cantidad'),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
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
                  setState(() => _error = 'Ingresa una cantidad valida');
                  return;
                }

                final available = widget.availableByProduct?[_selected!.id];
                if (available != null) {
                  final currentInDraft = context
                      .read<InvoicesProvider>()
                      .draftItems
                      .where((i) => i.productId == _selected!.id)
                      .fold<double>(0, (sum, i) => sum + i.quantity);
                  if (currentInDraft + qty > available) {
                    setState(() {
                      _error =
                          'Stock insuficiente. Disponible: ${available.toStringAsFixed(2)} ${_selected!.unit}.';
                    });
                    return;
                  }
                }

                context
                    .read<InvoicesProvider>()
                    .addToDraft(_selected!, qty);
                Navigator.pop(context);
              },
              child: const Text('Agregar'),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
