import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lacteos_app/models/invoice.dart';
import 'package:lacteos_app/models/invoice_item.dart';

class InvoicesService {
  final _client = Supabase.instance.client;

  Future<List<Invoice>> getInvoices() async {
    final data = await _client
        .from('invoices')
        .select('*, invoice_items(*)')
        .order('created_at', ascending: false);
    return (data as List).map((j) => Invoice.fromJson(j)).toList();
  }

  Future<Invoice> createInvoice({
    required String operarioId,
    required String operarioName,
    required String clientName,
    required List<InvoiceItem> items,
    String? dailyRouteId,
    String? notes,
  }) async {
    if (dailyRouteId != null) {
      await _validateAvailability(dailyRouteId, items);
    }

    final invoiceData = await _client
        .from('invoices')
        .insert({
          'operario_id': operarioId,
          'operario_name': operarioName,
          if (dailyRouteId != null) 'daily_route_id': dailyRouteId,
          'client_name': clientName,
          'status': InvoiceStatus.pendiente.name,
          if (notes != null) 'notes': notes,
        })
        .select()
        .single();

    final invoiceId = invoiceData['id'] as String;

    await _client.from('invoice_items').insert(
          items
              .map((item) => {
                    ...item.toJson(),
                    'invoice_id': invoiceId,
                  })
              .toList(),
        );

    if (dailyRouteId != null) {
      await _discountAvailability(dailyRouteId, items);
    }

    final full = await _client
        .from('invoices')
        .select('*, invoice_items(*)')
        .eq('id', invoiceId)
        .single();

    return Invoice.fromJson(full);
  }

  Future<void> updateStatus(String invoiceId, InvoiceStatus status) async {
    await _client
        .from('invoices')
        .update({'status': status.name}).eq('id', invoiceId);
  }

  Future<void> _validateAvailability(
      String dailyRouteId, List<InvoiceItem> items) async {
    final qtyByProduct = <String, double>{};
    final nameByProduct = <String, String>{};
    final unitByProduct = <String, String>{};
    for (final item in items) {
      qtyByProduct[item.productId] =
          (qtyByProduct[item.productId] ?? 0) + item.quantity;
      nameByProduct[item.productId] = item.productName;
      unitByProduct[item.productId] = item.unit;
    }

    final data = await _client
        .from('daily_route_products')
        .select('product_id, available_quantity')
        .eq('daily_route_id', dailyRouteId);

    final availableByProduct = <String, double>{};
    for (final row in (data as List)) {
      final productId = row['product_id'] as String;
      final available = (row['available_quantity'] as num?)?.toDouble() ?? 0;
      availableByProduct[productId] = available;
    }

    for (final entry in qtyByProduct.entries) {
      final need = entry.value;
      final available = availableByProduct[entry.key] ?? 0;
      if (need > available) {
        final name = nameByProduct[entry.key] ?? entry.key;
        final unit = unitByProduct[entry.key] ?? '';
        throw Exception(
          'Stock insuficiente para $name. Necesitas ${need.toStringAsFixed(2)}, disponible ${available.toStringAsFixed(2)} $unit.',
        );
      }
    }
  }

  Future<void> _discountAvailability(
      String dailyRouteId, List<InvoiceItem> items) async {
    final qtyByProduct = <String, double>{};
    for (final item in items) {
      qtyByProduct[item.productId] =
          (qtyByProduct[item.productId] ?? 0) + item.quantity;
    }

    final data = await _client
        .from('daily_route_products')
        .select('product_id, available_quantity, sold_quantity')
        .eq('daily_route_id', dailyRouteId);

    final availableByProduct = <String, double>{};
    final soldByProduct = <String, double>{};
    for (final row in (data as List)) {
      final productId = row['product_id'] as String;
      final available = (row['available_quantity'] as num?)?.toDouble() ?? 0;
      final sold = (row['sold_quantity'] as num?)?.toDouble() ?? 0;
      availableByProduct[productId] = available;
      soldByProduct[productId] = sold;
    }

    for (final entry in qtyByProduct.entries) {
      final productId = entry.key;
      final invoiceQty = entry.value;
      final current = availableByProduct[productId] ?? 0;
      final updated = current - invoiceQty;
      final prevSold = soldByProduct[productId] ?? 0;

      final rows = await _client
          .from('daily_route_products')
          .update({
            'available_quantity': updated < 0 ? 0 : updated,
            'sold_quantity': prevSold + invoiceQty,
          })
          .eq('daily_route_id', dailyRouteId)
          .eq('product_id', productId)
          .select();

      final list = rows as List;
      if (list.isEmpty) {
        throw Exception(
          'No se pudo actualizar el stock de la ruta del día para el producto $productId. '
          'Comprueba que exista en la ruta y que tu rol tenga permiso de actualización (RLS).',
        );
      }
    }
  }
}
