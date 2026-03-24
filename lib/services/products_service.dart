import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lacteos_app/config/supabase_config.dart';
import 'package:lacteos_app/models/product.dart';

class ProductsService {
  final _client = Supabase.instance.client;

  Future<List<Product>> getProducts() async {
    final data = await _client
        .from('products')
        .select()
        .eq('is_active', true)
        .order('name');
    return (data as List).map((j) => Product.fromJson(j)).toList();
  }

  Future<Product> createProduct(Product product) async {
    final data = await _client
        .from('products')
        .insert(product.toJson())
        .select()
        .single();
    return Product.fromJson(data);
  }

  Future<Product> updateProduct(Product product) async {
    final data = await _client
        .from('products')
        .update(product.toJson())
        .eq('id', product.id)
        .select()
        .single();
    return Product.fromJson(data);
  }

  Future<void> deleteProduct(String id) async {
    await _client.from('products').update({'is_active': false}).eq('id', id);
  }

  /// Sube una imagen al bucket de Storage y retorna la URL pública.
  Future<String> uploadProductImage(String productId, Uint8List bytes, String extension) async {
    final path = '$productId.$extension';
    await _client.storage
        .from(SupabaseConfig.productImagesBucket)
        .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
    return _client.storage
        .from(SupabaseConfig.productImagesBucket)
        .getPublicUrl(path);
  }

  /// Elimina la imagen de un producto del bucket.
  Future<void> deleteProductImage(String productId, String extension) async {
    await _client.storage
        .from(SupabaseConfig.productImagesBucket)
        .remove(['$productId.$extension']);
  }
}
