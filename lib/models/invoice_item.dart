import 'package:lacteos_app/models/product.dart';

class InvoiceItem {
  final String? id;
  final String productId;
  final String productName;
  final String unit;
  final double quantity;
  final double unitPrice;

  const InvoiceItem({
    this.id,
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
        unitPrice: product.salePrice,
      );

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
        id: json['id'] as String?,
        productId: json['product_id'],
        productName: json['product_name'],
        unit: json['unit'],
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: (json['unit_price'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'product_id': productId,
        'product_name': productName,
        'unit': unit,
        'quantity': quantity,
        'unit_price': unitPrice,
      };

  InvoiceItem copyWith({
    String? id,
    String? productId,
    String? productName,
    String? unit,
    double? quantity,
    double? unitPrice,
  }) =>
      InvoiceItem(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        unit: unit ?? this.unit,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
      );
}
