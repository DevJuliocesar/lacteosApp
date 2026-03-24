import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:lacteos_app/services/config_service.dart';

class ConfigProvider extends ChangeNotifier {
  final ConfigService _service = ConfigService();

  double _percentageSale = 1.0;
  bool _isLoading = false;

  double get percentageSale => _percentageSale;
  bool get isLoading => _isLoading;

  Future<void> loadConfig() async {
    dev.log('[ConfigProvider] loadConfig() iniciado');
    _isLoading = true;
    notifyListeners();
    try {
      dev.log('[ConfigProvider] llamando a Supabase...');
      _percentageSale = await _service.getPercentageSale();
      dev.log('[ConfigProvider] percengate_sale = $_percentageSale');
    } catch (e, stack) {
      dev.log('[ConfigProvider] ERROR al cargar config: $e\n$stack');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}