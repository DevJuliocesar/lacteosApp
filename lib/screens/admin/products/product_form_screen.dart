import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/models/product.dart';
import 'package:lacteos_app/providers/products_provider.dart';

class ProductFormScreen extends StatefulWidget {
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

  bool get isEditing => productId != null;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  static const _unitOptions = ['gramos', 'mililitros', 'unidad'];

  final _formKey = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  final _nameCtrl = TextEditingController();
  String _selectedUnit = 'unidad';
  final _priceCtrl = TextEditingController();
  final _salePriceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isEditing) {
        final product =
            context.read<ProductsProvider>().getById(widget.productId!);
        if (product != null) _populateForm(product);
      }
      _nameFocus.requestFocus();
    });
  }

  void _populateForm(Product product) {
    _nameCtrl.text = product.name;
    _priceCtrl.text = product.price.toString();
    _salePriceCtrl.text = product.salePrice.toString();
    _stockCtrl.text = product.stock.toString();
    setState(() {
      _selectedUnit = _unitOptions.contains(product.unit) ? product.unit : 'unidad';
      _isActive = product.isActive;
    });
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _salePriceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final provider = context.read<ProductsProvider>();
      if (widget.isEditing) {
        final existing = provider.getById(widget.productId!)!;
        await provider.updateProduct(existing.copyWith(
          name: _nameCtrl.text.trim(),
          unit: _selectedUnit,
          price: double.parse(_priceCtrl.text),
          salePrice: double.parse(_salePriceCtrl.text),
          stock: double.parse(_stockCtrl.text),
          isActive: _isActive,
        ));
      } else {
        await provider.createProduct(Product(
          id: '',
          name: _nameCtrl.text.trim(),
          unit: _selectedUnit,
          price: double.parse(_priceCtrl.text),
          salePrice: double.parse(_salePriceCtrl.text),
          stock: double.parse(_stockCtrl.text),
          isActive: _isActive,
        ));
      }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar producto' : 'Nuevo producto'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              focusNode: _nameFocus,
              decoration: const InputDecoration(labelText: 'Nombre del producto'),
              validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedUnit,
              decoration: const InputDecoration(labelText: 'Unidad de medida'),
              items: _unitOptions
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedUnit = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceCtrl,
              decoration: const InputDecoration(
                  labelText: 'Precio de costo', prefixText: '\$ '),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v!.isEmpty) return 'Campo requerido';
                if (double.tryParse(v) == null) return 'Precio inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _salePriceCtrl,
              decoration: const InputDecoration(
                  labelText: 'Precio de venta', prefixText: '\$ '),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v!.isEmpty) return 'Campo requerido';
                if (double.tryParse(v) == null) return 'Precio inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stockCtrl,
              decoration: const InputDecoration(labelText: 'Stock disponible'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v!.isEmpty) return 'Campo requerido';
                if (double.tryParse(v) == null) return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Producto activo'),
              subtitle: const Text('Visible para los operarios'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
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
                    : Text(widget.isEditing ? 'Guardar cambios' : 'Crear producto'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
