import 'package:lacteos_app/models/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class UsersService {
  final _client = Supabase.instance.client;

  Future<List<User>> getOperarios() async {
    final session = _client.auth.currentSession;
    if (session == null) throw Exception('Sesión no activa');

    final response = await _client.functions.invoke(
      'list-operarios',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );
    if (response.status != 200) {
      throw Exception(response.data?['error'] ?? 'Error al cargar operarios');
    }
    final list = response.data['operarios'] as List;
    return List<User>.from(list.map((j) => User.fromJson(j)));
  }

  Future<void> updateOperario(User user) async {
    final session = _client.auth.currentSession;
    if (session == null) throw Exception('Sesión no activa');

    final response = await _client.functions.invoke(
      'update-operario',
      body: {'id': user.id, 'name': user.name},
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );
    if (response.status != 200) {
      throw Exception(response.data?['error'] ?? 'Error al actualizar operario');
    }
  }

  Future<void> deleteOperario(String id) async {
    final session = _client.auth.currentSession;
    if (session == null) throw Exception('Sesión no activa');

    final response = await _client.functions.invoke(
      'delete-operario',
      body: {'id': id},
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );
    if (response.status != 200) {
      throw Exception(response.data?['error'] ?? 'Error al eliminar operario');
    }
  }

  Future<void> resendInvitation({required String email, required String name}) async {
    await inviteOperario(email: email, name: name);
  }

  Future<void> inviteOperario({required String email, required String name}) async {
    final session = _client.auth.currentSession;
    if (session == null) throw Exception('Sesión no activa');

    try {
      final response = await _client.functions.invoke(
        'invite-operario',
        body: {'email': email, 'name': name},
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      if (response.status != 200) {
        final error = response.data?['error'] ?? 'Error al enviar invitación';
        throw Exception(error);
      }
    } on FunctionException catch (e) {
      final message = e.details?['error'] ?? e.reasonPhrase ?? 'Error al enviar invitación';
      throw Exception(message);
    }
  }
}
