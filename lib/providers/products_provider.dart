import 'package:flutter/material.dart';
import 'package:lacteos_app/models/product.dart';
import 'package:lacteos_app/services/products_service.dart';

class ProductsProvider extends ChangeNotifier {
  final ProductsService _service = ProductsService();

  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  List<Product> get activeProducts =>
      _products.where((p) => p.isActive).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _service.getProducts();
    } catch (e) {
      _error = 'Error al cargar productos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createProduct(Product product) async {
    final created = await _service.createProduct(product);
    _products.add(created);
    notifyListeners();
  }

  Future<void> updateProduct(Product product) async {
    final updated = await _service.updateProduct(product);
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String id) async {
    await _service.deleteProduct(id);
    _products.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  Product? getById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
