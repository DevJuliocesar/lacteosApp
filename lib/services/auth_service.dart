import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:lacteos_app/models/user.dart';

class AuthService {
  final _client = sb.Supabase.instance.client;

  Future<User> login(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final supabaseUser = response.user;
    if (supabaseUser == null) throw Exception('Credenciales incorrectas');

    return _mapUser(supabaseUser);
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  User? currentUser() {
    final supabaseUser = _client.auth.currentUser;
    return supabaseUser != null ? _mapUser(supabaseUser) : null;
  }

  Stream<User?> authStateChanges() {
    return _client.auth.onAuthStateChange.map((data) {
      final supabaseUser = data.session?.user;
      return supabaseUser != null ? _mapUser(supabaseUser) : null;
    });
  }

  User _mapUser(sb.User supabaseUser) => User(
        id: supabaseUser.id,
        name: supabaseUser.userMetadata?['name'] as String? ??
            supabaseUser.email ??
            '',
        email: supabaseUser.email ?? '',
        role: supabaseUser.userMetadata?['role'] == 'admin'
            ? UserRole.admin
            : UserRole.operario,
      );
}
