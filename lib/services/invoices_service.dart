import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lacteos_app/models/invoice.dart';
import 'package:lacteos_app/models/invoice_item.dart';

class InvoicesService {
  final _client = Supabase.instance.client;

  Future<void> _ensureDailyRouteOpen(String? dailyRouteId) async {
    if (dailyRouteId == null) return;
    final row = await _client
        .from('daily_routes')
        .select('status')
        .eq('id', dailyRouteId)
        .maybeSingle();
    if (row == null) {
      throw Exception('Ruta del día no encontrada.');
    }
    if (row['status']?.toString() == 'cerrada') {
      throw Exception(
        'La ruta del día está cerrada. No se pueden crear ni modificar facturas.',
      );
    }
  }

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
    await _ensureDailyRouteOpen(dailyRouteId);
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

  Map<String, double> _qtyByProduct(List<InvoiceItem> items) {
    final m = <String, double>{};
    for (final item in items) {
      m[item.productId] = (m[item.productId] ?? 0) + item.quantity;
    }
    return m;
  }

  Future<Invoice> getInvoiceById(String invoiceId) async {
    final data = await _client
        .from('invoices')
        .select('*, invoice_items(*)')
        .eq('id', invoiceId)
        .single();
    return Invoice.fromJson(data);
  }

  /// Devuelve a la ruta del día lo vendido en la factura (disponible ↑, vendido ↓).
  Future<void> _returnQuantitiesToDailyRoute(
      String dailyRouteId, List<InvoiceItem> items) async {
    final qtyBy = _qtyByProduct(items);
    for (final entry in qtyBy.entries) {
      final productId = entry.key;
      final q = entry.value;
      final row = await _client
          .from('daily_route_products')
          .select('available_quantity, sold_quantity')
          .eq('daily_route_id', dailyRouteId)
          .eq('product_id', productId)
          .maybeSingle();
      if (row == null) continue;
      final av = (row['available_quantity'] as num).toDouble();
      final sold = (row['sold_quantity'] as num).toDouble();
      final newSold = sold - q;
      final rows = await _client
          .from('daily_route_products')
          .update({
            'available_quantity': av + q,
            'sold_quantity': newSold < 0 ? 0 : newSold,
          })
          .eq('daily_route_id', dailyRouteId)
          .eq('product_id', productId)
          .select();
      if ((rows as List).isEmpty) {
        throw Exception(
            'No se pudo restaurar stock de ruta del día para $productId.');
      }
    }
  }

  Future<void> _applyDailyRouteDelta(
    String dailyRouteId,
    Map<String, double> oldQty,
    Map<String, double> newQty,
  ) async {
    final keys = {...oldQty.keys, ...newQty.keys};
    for (final k in keys) {
      final oldQ = oldQty[k] ?? 0;
      final newQ = newQty[k] ?? 0;
      final delta = newQ - oldQ;
      if (delta == 0) continue;

      final row = await _client
          .from('daily_route_products')
          .select('available_quantity, sold_quantity')
          .eq('daily_route_id', dailyRouteId)
          .eq('product_id', k)
          .maybeSingle();
      if (row == null) {
        throw Exception(
            'El producto no está en la ruta del día; no se puede ajustar la factura.');
      }
      final av = (row['available_quantity'] as num).toDouble();
      final sold = (row['sold_quantity'] as num).toDouble();

      if (delta > 0 && av < delta) {
        throw Exception(
          'Stock insuficiente en la ruta del día para aumentar la cantidad. '
          'Disponible: ${av.toStringAsFixed(2)}, necesitas ${delta.toStringAsFixed(2)} extra.',
        );
      }
      if (delta < 0 && sold < -delta) {
        throw Exception(
            'No se puede reducir tanto la cantidad: solo hay ${sold.toStringAsFixed(2)} vendidos registrados en la ruta.');
      }

      final rows = await _client
          .from('daily_route_products')
          .update({
            'available_quantity': av - delta,
            'sold_quantity': sold + delta,
          })
          .eq('daily_route_id', dailyRouteId)
          .eq('product_id', k)
          .select();
      if ((rows as List).isEmpty) {
        throw Exception('No se pudo actualizar la ruta del día para el producto $k.');
      }
    }
  }

  Future<void> deleteInvoice(String invoiceId) async {
    final inv = await getInvoiceById(invoiceId);
    await _ensureDailyRouteOpen(inv.dailyRouteId);
    if (inv.dailyRouteId != null && inv.items.isNotEmpty) {
      await _returnQuantitiesToDailyRoute(inv.dailyRouteId!, inv.items);
    }
    await _client.from('invoice_items').delete().eq('invoice_id', invoiceId);
    await _client.from('invoices').delete().eq('id', invoiceId);
  }

  Future<Invoice> updateInvoice({
    required String invoiceId,
    required String clientName,
    String? notes,
    required List<InvoiceItem> items,
  }) async {
    final old = await getInvoiceById(invoiceId);
    await _ensureDailyRouteOpen(old.dailyRouteId);
    final oldMap = _qtyByProduct(old.items);
    final newMap = _qtyByProduct(items);
    if (old.dailyRouteId != null) {
      await _applyDailyRouteDelta(old.dailyRouteId!, oldMap, newMap);
    }

    await _client.from('invoice_items').delete().eq('invoice_id', invoiceId);
    if (items.isNotEmpty) {
      await _client.from('invoice_items').insert(
            items
                .map((e) {
                  final m = Map<String, dynamic>.from(e.toJson());
                  m.remove('id');
                  m['invoice_id'] = invoiceId;
                  return m;
                })
                .toList(),
          );
    }

    await _client.from('invoices').update({
      'client_name': clientName,
      'notes': notes,
    }).eq('id', invoiceId);

    return getInvoiceById(invoiceId);
  }
}
