import 'package:flutter/material.dart';
import 'package:lacteos_app/models/ruta.dart';
import 'package:lacteos_app/models/ruta_dia.dart';
import 'package:lacteos_app/services/rutas_service.dart';

class RutasProvider extends ChangeNotifier {
  final RutasService _service = RutasService();

  List<DeliveryRoute> _routes = [];
  List<DailyRoute> _dailyRoutes = [];
  bool _isLoading = false;
  String? _error;

  List<DeliveryRoute> get routes => _routes;
  List<DailyRoute> get dailyRoutes => _dailyRoutes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadRoutes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _routes = await _service.getRoutes();
    } catch (e) {
      _error = 'Error al cargar rutas: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createRoute(DeliveryRoute route) async {
    final created = await _service.createRoute(route);
    _routes.add(created);
    notifyListeners();
  }

  Future<void> updateRoute(DeliveryRoute route) async {
    final updated = await _service.updateRoute(route);
    final index = _routes.indexWhere((r) => r.id == route.id);
    if (index != -1) {
      _routes[index] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteRoute(String id) async {
    await _service.deleteRoute(id);
    _routes.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  Future<void> loadDailyRoutes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _dailyRoutes = await _service.getDailyRoutes();
    } catch (e) {
      _error = 'Error al cargar rutas del día: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sustituye o inserta una ruta del día leída de Supabase (disponibilidad / vendido actual).
  Future<void> refreshDailyRouteById(String id) async {
    try {
      final fresh = await _service.getDailyRouteById(id);
      final i = _dailyRoutes.indexWhere((r) => r.id == id);
      if (i >= 0) {
        _dailyRoutes = List<DailyRoute>.from(_dailyRoutes)..[i] = fresh;
      } else {
        _dailyRoutes = [fresh, ..._dailyRoutes];
      }
      notifyListeners();
    } catch (e) {
      _error = 'Error al actualizar ruta del día: $e';
      notifyListeners();
      await loadDailyRoutes();
    }
  }

  Future<void> createDailyRoute(
      String routeId, DateTime date, List<DailyRouteItem> items) async {
    final created = await _service.createDailyRoute(routeId, date, items);
    _dailyRoutes.insert(0, created);
    notifyListeners();
  }

  Future<void> deleteDailyRoute(String id) async {
    await _service.deleteDailyRoute(id);
    _dailyRoutes.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  /// Cierra la jornada: retorna disponible al depósito y bloquea nuevas facturas.
  Future<void> closeDailyRoute(
    String dailyRouteId, {
    List<Map<String, dynamic>> extraExpenses = const [],
  }) async {
    await _service.closeDailyRoute(
      dailyRouteId,
      extraExpenses: extraExpenses,
    );
    await refreshDailyRouteById(dailyRouteId);
  }
}
