class DailyRouteItem {
  final String productId;
  final String productName;
  final double quantity;
  final double availableQuantity;
  /// Cantidad vendida (facturada) acumulada para este producto en la ruta del día.
  final double soldQuantity;
  /// Cantidad retornada acumulada.
  final double returnedQuantity;

  const DailyRouteItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.availableQuantity,
    this.soldQuantity = 0,
    this.returnedQuantity = 0,
  });

  factory DailyRouteItem.fromJson(Map<String, dynamic> json) => DailyRouteItem(
        productId: json['product_id'],
        productName: (json['products'] as Map?)?['name'] ?? '',
        quantity: (json['quantity'] as num).toDouble(),
        availableQuantity:
            ((json['available_quantity'] ?? json['quantity']) as num)
                .toDouble(),
        soldQuantity: (json['sold_quantity'] as num?)?.toDouble() ?? 0,
        returnedQuantity: (json['returned_quantity'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'quantity': quantity,
        'available_quantity': availableQuantity,
        'sold_quantity': soldQuantity,
        'returned_quantity': returnedQuantity,
      };
}

class DailyRoute {
  final String id;
  final String routeId;
  final String routeName;
  final DateTime date;
  final List<DailyRouteItem> items;

  const DailyRoute({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.date,
    required this.items,
  });

  factory DailyRoute.fromJson(Map<String, dynamic> json) => DailyRoute(
        id: json['id'],
        routeId: json['route_id'],
        routeName: (json['routes'] as Map?)?['name'] ?? '',
        date: DateTime.parse(json['date']),
        items: (json['daily_route_products'] as List? ?? [])
            .map((e) => DailyRouteItem.fromJson(e))
            .toList(),
      );
}
