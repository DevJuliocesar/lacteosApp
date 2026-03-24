import 'package:lacteos_app/models/product.dart';

class InvoiceItem {
  final String productId;
  final String productName;
  final String unit;
  final double quantity;
  final double unitPrice;

  const InvoiceItem({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => quantity * unitPrice;

  factory InvoiceItem.fromProduct(Product product, double quantity) =>
      InvoiceItem(
        productId: product.id,
        productName: product.name,
        unit: product.unit,
        quantity: quantity,
        unitPrice: product.price,
      );

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
        productId: json['product_id'],
        productName: json['product_name'],
        unit: json['unit'],
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: (json['unit_price'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'unit': unit,
        'quantity': quantity,
        'unit_price': unitPrice,
      };
}
