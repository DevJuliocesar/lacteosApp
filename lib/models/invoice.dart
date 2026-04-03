import 'package:lacteos_app/models/invoice_item.dart';

enum InvoiceStatus { pendiente, pagada, anulada }

class Invoice {
  final String id;
  final String operarioId;
  final String operarioName;
  final String? dailyRouteId;
  final String clientName;
  final DateTime createdAt;
  final List<InvoiceItem> items;
  final InvoiceStatus status;
  final String? notes;

  const Invoice({
    required this.id,
    required this.operarioId,
    required this.operarioName,
    this.dailyRouteId,
    required this.clientName,
    required this.createdAt,
    required this.items,
    this.status = InvoiceStatus.pendiente,
    this.notes,
  });

  double get total => items.fold(0, (sum, i) => sum + i.subtotal);

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: json['id'],
        operarioId: json['operario_id'],
        operarioName: json['operario_name'],
        dailyRouteId: json['daily_route_id'],
        clientName: json['client_name'],
        createdAt: DateTime.parse(json['created_at']),
        items: (json['invoice_items'] as List? ?? [])
            .map((i) => InvoiceItem.fromJson(i))
            .toList(),
        status: InvoiceStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => InvoiceStatus.pendiente,
        ),
        notes: json['notes'],
      );

  Map<String, dynamic> toJson() => {
        'operario_id': operarioId,
        'operario_name': operarioName,
        if (dailyRouteId != null) 'daily_route_id': dailyRouteId,
        'client_name': clientName,
        'created_at': createdAt.toIso8601String(),
        'status': status.name,
        'notes': notes,
      };

  Invoice copyWith({
    String? clientName,
    DateTime? createdAt,
    List<InvoiceItem>? items,
    InvoiceStatus? status,
    String? notes,
  }) =>
      Invoice(
        id: id,
        operarioId: operarioId,
        operarioName: operarioName,
        dailyRouteId: dailyRouteId,
        clientName: clientName ?? this.clientName,
        createdAt: createdAt ?? this.createdAt,
        items: items ?? this.items,
        status: status ?? this.status,
        notes: notes ?? this.notes,
      );
}
