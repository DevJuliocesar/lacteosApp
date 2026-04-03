import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gotrue/gotrue.dart' show AuthException;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:lacteos_app/models/user.dart';
import 'package:lacteos_app/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = sb.Supabase.instance.client;
  final _service = AuthService();

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _needsPasswordSetup = false;
  StreamSubscription? _authSubscription;

  AuthProvider() {
    final supaUser = _supabase.auth.currentUser;
    if (supaUser != null) _user = _fromSupabase(supaUser);

    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final supaUser = data.session?.user;
      final wasUnauthenticated = _user == null;

      if (supaUser != null) {
        _user = _fromSupabase(supaUser);
        if (wasUnauthenticated) _detectInviteSignIn(supaUser);
      } else {
        _user = null;
        _needsPasswordSetup = false;
      }
      notifyListeners();
    });
  }

  /// Detecta si es el primer login de un usuario invitado comparando
  /// createdAt con lastSignInAt (diferencia < 60s = primer acceso)
  void _detectInviteSignIn(sb.User user) {
    final created = DateTime.tryParse(user.createdAt)?.toUtc();
    final lastSignIn = user.lastSignInAt != null
        ? DateTime.tryParse(user.lastSignInAt!)?.toUtc()
        : null;
    if (created != null && lastSignIn != null) {
      _needsPasswordSetup =
          lastSignIn.difference(created).inSeconds.abs() < 60;
    }
  }

  User _fromSupabase(sb.User u) => User(
        id: u.id,
        name: u.userMetadata?['name'] as String? ?? u.email ?? '',
        email: u.email ?? '',
        role: u.userMetadata?['role'] == 'admin'
            ? UserRole.admin
            : UserRole.operario,
      );

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _user?.role == UserRole.admin;
  bool get isOperario => _user?.role == UserRole.operario;
  String? get error => _error;
  bool get needsPasswordSetup => _needsPasswordSetup;

  Future<bool> login(String email, String password) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    // Deja que el framework pinte el botón / overlay de carga antes del await de red.
    await Future<void>.delayed(Duration.zero);

    try {
      await _service.login(email, password);
      return true;
    } catch (e) {
      _error = _messageForAuthFailure(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static String _messageForAuthFailure(Object e) {
    if (e is AuthException) {
      final msg = e.message;
      final code = e.code?.toLowerCase();
      if (code == 'invalid_credentials' ||
          msg.toLowerCase().contains('invalid login credentials')) {
        return 'Correo o contraseña incorrectos.';
      }
      if (msg.toLowerCase().contains('email not confirmed')) {
        return 'Debes confirmar tu correo electrónico antes de ingresar.';
      }
      if (msg.toLowerCase().contains('too many requests')) {
        return 'Demasiados intentos. Espera unos minutos e intenta de nuevo.';
      }
      return msg;
    }
    final s = e.toString();
    return s.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  Future<void> logout() async {
    await _service.logout();
  }

  void markPasswordSetup() {
    _needsPasswordSetup = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
