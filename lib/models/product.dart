class Product {
  final String id;
  final String name;
  final String unit;
  final double price;
  final double salePrice;
  final double stock;
  final bool isActive;

  const Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.salePrice,
    required this.stock,
    this.isActive = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'],
        name: json['name'],
        unit: json['unit'],
        price: (json['price'] as num).toDouble(),
        salePrice: (json['sale_price'] as num? ?? 0).toDouble(),
        stock: (json['stock'] as num).toDouble(),
        isActive: json['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'unit': unit,
        'price': price,
        'sale_price': salePrice,
        'stock': stock,
        'is_active': isActive,
      };

  Product copyWith({
    String? name,
    String? unit,
    double? price,
    double? salePrice,
    double? stock,
    bool? isActive,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        unit: unit ?? this.unit,
        price: price ?? this.price,
        salePrice: salePrice ?? this.salePrice,
        stock: stock ?? this.stock,
        isActive: isActive ?? this.isActive,
      );
}
