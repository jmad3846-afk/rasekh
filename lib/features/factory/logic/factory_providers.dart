import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/hive_init.dart';
import '../../../core/utils/currency.dart';
import '../data/models/product.dart';
import '../data/models/invoice.dart';
import '../data/models/customer.dart';
import '../../finance/logic/finance_engine.dart';
import '../../finance/data/models/transaction.dart';

final productsProvider = StreamProvider<List<Product>>((ref) async* { final box=HiveInit.products; yield box.values.toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt)); yield* box.watch().map((_)=> box.values.toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt))); });
final productByIdProvider = Provider.family<Product?,String>((ref,id){ ref.watch(productsProvider); try{ return HiveInit.products.values.firstWhere((p)=> p.id==id);}catch(_){ return null; } });
class ProductNotifier { Future<void> add(Product p) async => await HiveInit.products.put(p.id,p); Future<void> update(Product p) async => await p.save(); Future<void> delete(Product p) async => await p.delete(); }
final invoicesProvider = StreamProvider<List<Invoice>>((ref) async* { final box=HiveInit.invoices; yield box.values.toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt)); yield* box.watch().map((_)=> box.values.toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt))); });
final customersProvider = StreamProvider<List<Customer>>((ref) async* {
  final box = HiveInit.customers;
  List<Customer> getList() => box.values.toList()..sort((a,b)=> a.name.compareTo(b.name));
  yield getList();
  yield* box.watch().map((_)=> getList());
});

class InvoiceService {
  Future<Customer> _resolveCustomer(String name, String phone, String address) async {
    Customer? customer;
    try { customer=HiveInit.customers.values.firstWhere((c)=> c.phone==phone);}catch(_){}
    customer ??= Customer(name:name, phone:phone, address:address);
    customer.name = name;
    customer.address = address;
    await HiveInit.customers.put(customer.id,customer);
    return customer;
  }

  /// Legacy single-product create (kept for compat).
  Future<Invoice> create({required String customerName, required String customerPhone, required String deliveryAddress, required Product product, required double quantity, required double downPayment, AppCurrency currency = AppCurrency.syp}) async {
    return createStandard(
      customerName: customerName, customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      lines: [InvoiceItem(productId: product.id, productName: product.name, quantity: quantity, unitPrice: product.unitPrice, unit: product.unit)],
      downPayment: downPayment, currency: currency,
    );
  }

  /// Req #9 standard: multi-item invoice with stock deduction per line.
  Future<Invoice> createStandard({
    required String customerName, required String customerPhone,
    required String deliveryAddress, required List<InvoiceItem> lines,
    required double downPayment, AppCurrency currency = AppCurrency.syp,
    String notes = '',
  }) async {
    if (lines.isEmpty) throw Exception('أضف منتجاً واحداً على الأقل');
    final total = lines.fold(0.0, (s, e) => s + e.lineTotal);
    if (downPayment < 0) throw Exception('الدفعة غير صالحة');
    if (downPayment > total) throw Exception('الدفعة أكبر من الإجمالي');
    // Stock check first (atomic-ish).
    for (final l in lines) {
      final prod = HiveInit.products.get(l.productId);
      if (prod == null) throw Exception('منتج غير موجود: ${l.productName}');
      if (prod.stockQuantity < l.quantity) {
        throw Exception('الكمية غير متوفرة لـ ${l.productName}: متاح ${prod.stockQuantity}');
      }
    }
    final customer = await _resolveCustomer(customerName, customerPhone, deliveryAddress);
    final first = lines.first;
    final inv = Invoice(
      customerId: customer.id, customerName: customer.name, customerPhone: customer.phone,
      deliveryAddress: deliveryAddress,
      productId: first.productId, productName: first.productName,
      quantity: first.quantity, unitPrice: first.unitPrice,
      totalPrice: total, downPayment: downPayment, currency: currency,
      type: InvoiceType.standard, items: List.of(lines), notes: notes,
    );
    inv.recalc();
    for (final l in lines) {
      final prod = HiveInit.products.get(l.productId)!;
      prod.stockQuantity -= l.quantity;
      await prod.save();
    }
    await HiveInit.invoices.put(inv.id, inv);
    await FinanceEngine.onInvoiceCreated(inv);
    return inv;
  }

  /// Req #9 payment-only: no products, direct settlement.
  /// Posts a client PAYMENT (reduces debt) instead of a debit.
  Future<Invoice> createPaymentOnly({
    required String customerName, required String customerPhone,
    required double amount, AppCurrency currency = AppCurrency.syp,
    String notes = '',
  }) async {
    if (amount <= 0) throw Exception('المبلغ مطلوب');
    final customer = await _resolveCustomer(customerName, customerPhone, '');
    final inv = Invoice.paymentOnly(
      customerId: customer.id, customerName: customer.name,
      customerPhone: customer.phone, amount: amount,
      currency: currency, notes: notes,
    );
    await HiveInit.invoices.put(inv.id, inv);
    // A payment-only invoice settles debt: record as payment entry.
    await FinanceEngine.clearRelatedTransactions(inv.id);
    await FinanceEngine.addPayment(
      party: TransactionParty.client,
      partyId: customer.id, partyName: customer.name, partyPhone: customer.phone,
      amount: amount, source: 'فاتورة دفعة ${inv.invoiceNumber}',
      reason: notes.isEmpty ? 'تسوية مالية مباشرة' : notes,
      relatedId: inv.id, currency: currency,
    );
    return inv;
  }

  /// Edit: adjust stock by difference, recalc totals, refresh ledger exactly once.
  Future<Invoice> update({
    required Invoice inv,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required Product product,
    required double quantity,
    required double downPayment,
    required AppCurrency currency,
  }) async {
    // Migrate legacy edit onto multi-item path.
    return updateStandard(
      inv: inv, customerName: customerName, customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      lines: [InvoiceItem(productId: product.id, productName: product.name, quantity: quantity, unitPrice: product.unitPrice, unit: product.unit)],
      downPayment: downPayment, currency: currency,
    );
  }

  Future<Invoice> updateStandard({
    required Invoice inv,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required List<InvoiceItem> lines,
    required double downPayment,
    required AppCurrency currency,
    String? notes,
  }) async {
    if (inv.isPaymentOnly) {
      // Edit payment-only: just update amount/notes + refresh payment entry.
      if (lines.isNotEmpty) throw Exception('فاتورة الدفعة لا تحتوي منتجات');
      inv.customerName = customerName;
      inv.customerPhone = customerPhone;
      inv.notes = notes ?? inv.notes;
      inv.currency = currency;
      await inv.save();
      await FinanceEngine.clearRelatedTransactions(inv.id);
      await _postPaymentOnlyEntry(inv);
      // Refresh customer link.
      await _syncCustomer(inv, customerName, customerPhone, deliveryAddress);
      return inv;
    }
    if (lines.isEmpty) throw Exception('أضف منتجاً واحداً على الأقل');
    final newTotal = lines.fold(0.0, (s, e) => s + e.lineTotal);
    if (downPayment < 0 || downPayment > newTotal) throw Exception('الدفعة غير صالحة');
    // Restore old stock.
    for (final old in inv.effectiveItems) {
      final prod = HiveInit.products.get(old.productId);
      if (prod != null) { prod.stockQuantity += old.quantity; await prod.save(); }
    }
    // Deduct new stock.
    for (final l in lines) {
      final prod = HiveInit.products.get(l.productId);
      if (prod == null) throw Exception('منتج غير موجود: ${l.productName}');
      if (prod.stockQuantity < l.quantity) throw Exception('الكمية غير متوفرة لـ ${l.productName}: متاح ${prod.stockQuantity}');
    }
    for (final l in lines) {
      final prod = HiveInit.products.get(l.productId)!;
      prod.stockQuantity -= l.quantity;
      await prod.save();
    }
    final first = lines.first;
    inv.customerName = customerName;
    inv.customerPhone = customerPhone;
    inv.deliveryAddress = deliveryAddress;
    inv.productId = first.productId;
    inv.productName = lines.length == 1 ? first.productName : '${first.productName} +${lines.length - 1}';
    inv.quantity = lines.fold(0.0, (s, e) => s + e.quantity);
    inv.unitPrice = first.unitPrice;
    inv.totalPrice = newTotal;
    inv.downPayment = downPayment;
    inv.currency = currency;
    inv.items = List.of(lines);
    if (notes != null) inv.notes = notes;
    inv.recalc();
    await inv.save();
    await _syncCustomer(inv, customerName, customerPhone, deliveryAddress);
    await FinanceEngine.onInvoiceUpdated(inv);
    return inv;
  }

  Future<void> _postPaymentOnlyEntry(Invoice inv) async {
    await FinanceEngine.addPayment(
      party: TransactionParty.client, partyId: inv.customerId, partyName: inv.customerName,
      partyPhone: inv.customerPhone, amount: inv.totalPrice,
      source: 'فاتورة دفعة ${inv.invoiceNumber}',
      reason: inv.notes.isEmpty ? 'تسوية مالية مباشرة' : inv.notes,
      relatedId: inv.id, currency: inv.currency,
    );
  }

  Future<void> _syncCustomer(Invoice inv, String name, String phone, String address) async {
    Customer? customer;
    try {
      customer = HiveInit.customers.values.firstWhere((c) => c.id == inv.customerId);
    } catch (_) {}
    if (customer != null) {
      customer.name = name;
      customer.phone = phone;
      customer.address = address;
      await customer.save();
    }
  }

  /// Delete: restore stock + fully remove client debt (no write-off payment).
  Future<void> delete(Invoice inv) async {
    if (!inv.isPaymentOnly) {
      for (final l in inv.effectiveItems) {
        final prod = HiveInit.products.get(l.productId);
        if (prod != null) { prod.stockQuantity += l.quantity; await prod.save(); }
      }
    }
    await FinanceEngine.onInvoiceDeleted(inv);
    await inv.delete();
  }
}

final invoiceServiceProvider = Provider((ref)=> InvoiceService());
final productServiceProvider = Provider((ref)=> ProductNotifier());
