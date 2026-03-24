import 'package:flutter/material.dart';
import 'package:lacteos_app/models/invoice.dart';
import 'package:lacteos_app/models/invoice_item.dart';
import 'package:lacteos_app/models/product.dart';
import 'package:lacteos_app/services/invoices_service.dart';

class InvoicesProvider extends ChangeNotifier {
  final InvoicesService _service = InvoicesService();

  List<Invoice> _invoices = [];
  // Items del borrador de factura actual (operario)
  final Map<String, InvoiceItem> _draftItems = {};
  bool _isLoading = false;
  String? _error;

  List<Invoice> get invoices => _invoices;
  List<InvoiceItem> get draftItems => _draftItems.values.toList();
  double get draftTotal =>
      _draftItems.values.fold(0, (sum, i) => sum + i.subtotal);
  bool get hasDraftItems => _draftItems.isNotEmpty;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadInvoices() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _invoices = await _service.getInvoices();
    } catch (e) {
      _error = 'Error al cargar facturas: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Borrador de factura ---

  void addToDraft(Product product, double quantity) {
    if (_draftItems.containsKey(product.id)) {
      final existing = _draftItems[product.id]!;
      _draftItems[product.id] = InvoiceItem(
        productId: existing.productId,
        productName: existing.productName,
        unit: existing.unit,
        quantity: existing.quantity + quantity,
        unitPrice: existing.unitPrice,
      );
    } else {
      _draftItems[product.id] = InvoiceItem.fromProduct(product, quantity);
    }
    notifyListeners();
  }

  void removeFromDraft(String productId) {
    _draftItems.remove(productId);
    notifyListeners();
  }

  void clearDraft() {
    _draftItems.clear();
    notifyListeners();
  }

  Future<Invoice> submitInvoice({
    required String operarioId,
    required String operarioName,
    required String clientName,
    String? notes,
  }) async {
    final invoice = await _service.createInvoice(
      operarioId: operarioId,
      operarioName: operarioName,
      clientName: clientName,
      items: draftItems,
      notes: notes,
    );
    _invoices.insert(0, invoice);
    _draftItems.clear();
    notifyListeners();
    return invoice;
  }

  Future<void> updateStatus(String invoiceId, InvoiceStatus status) async {
    await _service.updateStatus(invoiceId, status);
    final index = _invoices.indexWhere((i) => i.id == invoiceId);
    if (index != -1) {
      final inv = _invoices[index];
      _invoices[index] = Invoice(
        id: inv.id,
        operarioId: inv.operarioId,
        operarioName: inv.operarioName,
        clientName: inv.clientName,
        createdAt: inv.createdAt,
        items: inv.items,
        status: status,
        notes: inv.notes,
      );
      notifyListeners();
    }
  }
}
