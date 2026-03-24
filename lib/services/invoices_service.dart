import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lacteos_app/models/invoice.dart';
import 'package:lacteos_app/models/invoice_item.dart';

class InvoicesService {
  final _client = Supabase.instance.client;

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
    String? notes,
  }) async {
    final invoiceData = await _client
        .from('invoices')
        .insert({
          'operario_id': operarioId,
          'operario_name': operarioName,
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
}
