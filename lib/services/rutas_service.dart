import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lacteos_app/models/ruta.dart';
import 'package:lacteos_app/models/ruta_dia.dart';

class RutasService {
  final _client = Supabase.instance.client;

  // ---------- Routes ----------

  Future<List<DeliveryRoute>> getRoutes() async {
    final data = await _client
        .from('routes')
        .select('*, route_users(user_id)')
        .order('name');
    return (data as List).map((j) => DeliveryRoute.fromJson(j)).toList();
  }

  Future<DeliveryRoute> createRoute(DeliveryRoute route) async {
    final data = await _client
        .from('routes')
        .insert(route.toJson())
        .select()
        .single();
    final created = DeliveryRoute.fromJson({...data, 'route_users': []});
    await _syncUsers(created.id, route.userIds);
    return created.copyWith(userIds: route.userIds);
  }

  Future<DeliveryRoute> updateRoute(DeliveryRoute route) async {
    final data = await _client
        .from('routes')
        .update(route.toJson())
        .eq('id', route.id)
        .select()
        .single();
    await _syncUsers(route.id, route.userIds);
    return DeliveryRoute.fromJson({...data, 'route_users': []})
        .copyWith(userIds: route.userIds);
  }

  Future<void> deleteRoute(String id) async {
    await _client.from('routes').delete().eq('id', id);
  }

  Future<void> _syncUsers(String routeId, List<String> userIds) async {
    await _client.from('route_users').delete().eq('route_id', routeId);
    if (userIds.isNotEmpty) {
      await _client.from('route_users').insert(
            userIds
                .map((uid) => {'route_id': routeId, 'user_id': uid})
                .toList(),
          );
    }
  }

  // ---------- Daily routes ----------

  static const String _dailyRouteProductsSelect =
      'product_id, quantity, available_quantity, sold_quantity, returned_quantity, products(name)';

  Future<List<DailyRoute>> getDailyRoutes() async {
    final data = await _client
        .from('daily_routes')
        .select(
            '*, routes(name), daily_route_products($_dailyRouteProductsSelect)')
        .order('date', ascending: false);
    return (data as List).map((j) => DailyRoute.fromJson(j)).toList();
  }

  /// Una ruta del día con productos actuales desde Supabase (para refrescar UI).
  Future<DailyRoute> getDailyRouteById(String id) async {
    final data = await _client
        .from('daily_routes')
        .select(
            '*, routes(name), daily_route_products($_dailyRouteProductsSelect)')
        .eq('id', id)
        .single();
    return DailyRoute.fromJson(data);
  }

  Future<DailyRoute> createDailyRoute(
      String routeId, DateTime date, List<DailyRouteItem> items) async {
    final qtyByProduct = <String, double>{};
    final nameByProduct = <String, String>{};
    for (final i in items) {
      qtyByProduct[i.productId] =
          (qtyByProduct[i.productId] ?? 0) + i.quantity;
      nameByProduct[i.productId] = i.productName;
    }

    final stockById = <String, double>{};
    if (qtyByProduct.isNotEmpty) {
      final ids = qtyByProduct.keys.toList();
      final rows = await _client
          .from('products')
          .select('id, stock')
          .inFilter('id', ids);
      for (final row in (rows as List)) {
        stockById[row['id'] as String] =
            (row['stock'] as num).toDouble();
      }
      for (final entry in qtyByProduct.entries) {
        final need = entry.value;
        final stock = stockById[entry.key] ?? 0;
        if (need > stock) {
          final name = nameByProduct[entry.key] ?? entry.key;
          throw Exception(
            'Stock insuficiente para "$name". Necesitas ${need.toStringAsFixed(2)}, disponible ${stock.toStringAsFixed(2)}.',
          );
        }
      }
    }

    final data = await _client
        .from('daily_routes')
        .insert({
          'route_id': routeId,
          'date': date.toIso8601String().substring(0, 10),
        })
        .select()
        .single();
    final id = data['id'] as String;
    if (items.isNotEmpty) {
      await _client.from('daily_route_products').insert(
            items.map((i) => {...i.toJson(), 'daily_route_id': id}).toList(),
          );
    }

    for (final entry in qtyByProduct.entries) {
      final stock = stockById[entry.key]!;
      final need = entry.value;
      final next = stock - need;
      await _client.from('products').update({'stock': next}).eq('id', entry.key);
    }

    final full = await _client
        .from('daily_routes')
        .select(
            '*, routes(name), daily_route_products($_dailyRouteProductsSelect)')
        .eq('id', id)
        .single();
    return DailyRoute.fromJson(full);
  }

  Future<void> deleteDailyRoute(String id) async {
    await _client.from('daily_routes').delete().eq('id', id);
  }
}
