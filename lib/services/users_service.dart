import 'package:supabase_flutter/supabase_flutter.dart';

class UsersService {
  final _client = Supabase.instance.client;

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
