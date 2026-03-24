import 'package:flutter/material.dart';
import 'package:lacteos_app/models/user.dart';
import 'package:lacteos_app/services/users_service.dart';

class UsersProvider extends ChangeNotifier {
  final UsersService _service = UsersService();

  List<User> _operarios = [];
  bool _isLoading = false;
  String? _error;

  List<User> get operarios => _operarios;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadOperarios() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _operarios = await _service.getOperarios();
    } catch (e) {
      _error = 'Error al cargar operarios: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateOperario(User user) async {
    await _service.updateOperario(user);
    final index = _operarios.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _operarios[index] = user;
      notifyListeners();
    }
  }

  Future<void> deleteOperario(String id) async {
    await _service.deleteOperario(id);
    _operarios.removeWhere((u) => u.id == id);
    notifyListeners();
  }
}
