import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/models/ruta_dia.dart';
import 'package:lacteos_app/models/user.dart';
import 'package:lacteos_app/providers/products_provider.dart';
import 'package:lacteos_app/providers/auth_provider.dart';
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

  Future<void> _showAddProductDialog() async {
    final products = context.read<ProductsProvider>().activeProducts;
    final existingProductIds = _items.map((e) => e.productId).toSet();
    final availableProducts = products
        .where((p) => !existingProductIds.contains(p.id))
        .toList();
    String? productId;
    final qtyCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        String? qtyError;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Agregar producto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (availableProducts.isEmpty)
                  const Text(
                    'Ya agregaste todos los productos disponibles.',
                    style: TextStyle(color: Colors.grey),
                  ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Producto'),
                  items: availableProducts
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text('${p.name} (stock ${p.stock.toStringAsFixed(2)})'),
                          ))
                      .toList(),
                  onChanged: availableProducts.isEmpty
                      ? null
                      : (v) => setDialogState(() {
                            productId = v;
                            qtyError = null;
                          }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  onChanged: (_) => setDialogState(() => qtyError = null),
                ),
                if (qtyError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      qtyError!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                },
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: availableProducts.isEmpty
                    ? null
                    : () {
                        final qty = double.tryParse(qtyCtrl.text);
                        if (productId == null || qty == null || qty <= 0) {
                          setDialogState(() {
                            qtyError = 'Ingresa una cantidad válida mayor a 0';
                          });
                          return;
                        }
                        final product =
                            availableProducts.firstWhere((p) => p.id == productId);
                        if (qty > product.stock) {
                          setDialogState(() {
                            qtyError =
                                'Stock insuficiente. Disponible: ${product.stock.toStringAsFixed(2)} ${product.unit}.';
                          });
                          return;
                        }
                        setState(() {
                          _items.add(DailyRouteItem(
                            productId: product.id,
                            productName: product.name,
                            unit: product.unit,
                            quantity: qty,
                            availableQuantity: qty,
                            soldQuantity: 0,
                            returnedQuantity: 0,
                          ));
                        });
                        Navigator.pop(ctx);
                      },
                child: const Text('Agregar'),
              ),
            ],
          ),
        );
      },
    );

    qtyCtrl.dispose();
  }

  Future<void> _submit() async {
    if (_selectedRouteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una ruta')),
      );
      return;
    }

    final user = context.read<AuthProvider>().user;
    if (user?.role == UserRole.operario) {
      final operarioId = user!.id;
      final allowed = context
          .read<RutasProvider>()
          .routes
          .any(
              (r) => r.id == _selectedRouteId && r.userIds.contains(operarioId));

      if (!allowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tienes permisos para esa ruta')),
        );
        return;
      }
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
      if (mounted) {
        context.read<ProductsProvider>().loadProducts();
        context.pop();
      }
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
    final allActiveRoutes = context
        .watch<RutasProvider>()
        .routes
        .where((r) => r.isActive)
        .toList();

    final user = context.watch<AuthProvider>().user;
    final isOperario = user?.role == UserRole.operario;
    final routes = isOperario
        ? allActiveRoutes.where((r) => r.userIds.contains(user!.id)).toList()
        : allActiveRoutes;

    final selectedValid = _selectedRouteId == null ||
        routes.any((r) => r.id == _selectedRouteId);

    if (!selectedValid && _selectedRouteId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedRouteId = null);
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva ruta del día')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _selectedRouteId != null && selectedValid
                ? _selectedRouteId
                : null,
            decoration: const InputDecoration(labelText: 'Ruta'),
            items: routes
                .map((r) =>
                    DropdownMenuItem(value: r.id, child: Text(r.name)))
                .toList(),
            onChanged: routes.isEmpty ? null : (v) => setState(() => _selectedRouteId = v),
          ),
          if (routes.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'No tienes rutas asignadas.',
                style: TextStyle(color: Colors.grey),
              ),
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
