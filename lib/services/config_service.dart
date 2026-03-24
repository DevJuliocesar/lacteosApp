import 'package:supabase_flutter/supabase_flutter.dart';

class ConfigService {
  final _client = Supabase.instance.client;

  Future<double> getPercentageSale() async {
    final data = await _client
        .from('config')
        .select('percentage_sale')
        .single();
    return (data['percentage_sale'] as num).toDouble();
  }
}
