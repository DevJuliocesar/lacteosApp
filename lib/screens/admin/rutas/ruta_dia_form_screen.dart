import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/models/ruta_dia.dart';
import 'package:lacteos_app/providers/products_provider.dart';
import 'package:lacteos_app/providers/rutas_provider.dart';

class RutaDiaFormScreen extends StatefulWidget {
  const RutaDiaFormScreen({super.key});

  @override
  State<RutaDiaFormScreen> createState() => _RutaDiaFormScreenState();
}

class _RutaDiaFormScreenState extends State<RutaDiaFormScreen> {
  String? _selectedRouteId;
  DateTime _selectedDate = DateTime.now();
  final List<DailyRouteItem> _items = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RutasProvider>().loadRoutes();
      context.read<ProductsProvider>().loadProducts();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _showAddProductDialog() {
    final products = context.read<ProductsProvider>().activeProducts;
    String? productId;
    final qtyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Agregar producto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Producto'),
                items: products
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        ))
                    .toList(),
                onChanged: (v) => setDialogState(() => productId = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyCtrl,
                decoration: const InputDecoration(labelText: 'Cantidad'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final qty = double.tryParse(qtyCtrl.text);
                if (productId == null || qty == null || qty <= 0) return;
                final product =
                    products.firstWhere((p) => p.id == productId);
                setState(() {
                  _items.add(DailyRouteItem(
                    productId: product.id,
                    productName: product.name,
                    quantity: qty,
                  ));
                });
                Navigator.pop(ctx);
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedRouteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una ruta')),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await context
          .read<RutasProvider>()
          .createDailyRoute(_selectedRouteId!, _selectedDate, _items);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routes = context
        .watch<RutasProvider>()
        .routes
        .where((r) => r.isActive)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva ruta del día')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _selectedRouteId,
            decoration: const InputDecoration(labelText: 'Ruta'),
            items: routes
                .map((r) =>
                    DropdownMenuItem(value: r.id, child: Text(r.name)))
                .toList(),
            onChanged: (v) => setState(() => _selectedRouteId = v),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Fecha'),
            subtitle: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _pickDate,
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Productos',
                  style: Theme.of(context).textTheme.titleSmall),
              TextButton.icon(
                onPressed: _showAddProductDialog,
                icon: const Icon(Icons.add),
                label: const Text('Agregar'),
              ),
            ],
          ),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Sin productos agregados',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            ..._items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(item.productName),
                subtitle: Text('Cantidad: ${item.quantity}'),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => setState(() => _items.removeAt(i)),
                ),
              );
            }),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Crear ruta del día'),
            ),
          ),
        ],
      ),
    );
  }
}
