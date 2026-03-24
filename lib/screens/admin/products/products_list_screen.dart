import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lacteos_app/models/product.dart';
import 'package:lacteos_app/providers/products_provider.dart';

class ProductsListScreen extends StatelessWidget {
  const ProductsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/products/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo producto'),
      ),
      body: Consumer<ProductsProvider>(
        builder: (_, provider, __) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.products.isEmpty) {
            return const Center(child: Text('No hay productos registrados'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: provider.products.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final product = provider.products[index];
              return _ProductTile(product: product);
            },
          );
        },
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;

  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: product.isActive
            ? Colors.blue.shade50
            : Colors.grey.shade200,
        child: Icon(
          Icons.water_drop,
          color: product.isActive ? Colors.blue : Colors.grey,
        ),
      ),
      title: Text(product.name,
          style: TextStyle(
              color: product.isActive ? null : Colors.grey,
              decoration:
                  product.isActive ? null : TextDecoration.lineThrough)),
      subtitle: Text(
          '\$${product.price.toStringAsFixed(2)} / ${product.unit}  •  Stock: ${product.stock}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.push('/admin/products/${product.id}/edit'),
          ),
          _DeleteButton(product: product),
        ],
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final Product product;

  const _DeleteButton({required this.product});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete_outline, color: Colors.red),
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Eliminar producto'),
            content:
                Text('¿Eliminar "${product.name}"? Esta acción no se puede deshacer.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Eliminar',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          await context.read<ProductsProvider>().deleteProduct(product.id);
        }
      },
    );
  }
}
