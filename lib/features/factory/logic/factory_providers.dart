import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/hive_init.dart';
import '../../../core/utils/currency.dart';
import '../data/models/product.dart';
import '../data/models/invoice.dart';
import '../data/models/customer.dart';
import '../data/models/stock_log.dart';
import '../data/models/price_tier.dart';
import '../../finance/logic/finance_engine.dart';
import '../../finance/data/models/transaction.dart';

final productsProvider = StreamProvider<List<Product>>((ref) async* { final box=HiveInit.products; yield box.values.toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt)); yield* box.watch().map((_)=> box.values.toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt))); });
final productByIdProvider = Provider.family<Product?,String>((ref,id){ ref.watch(productsProvider); try{ return HiveInit.products.values.firstWhere((p)=> p.id==id);}catch(_){ return null; } });
class ProductNotifier {
  /// Duplicate guard (case-insensitive): block creation if name exists.
  Future<void> add(Product p) async {
    final exists = HiveInit.products.values.any(
        (e) => e.name.trim().toLowerCase() == p.name.trim().toLowerCase());
    if (exists) {
      throw Exception('هذا المنتج موجود مسبقاً، يرجى التعديل على مخزونه فقط');
    }
    p.currency = AppCurrency.syp; // single-currency architecture
    await HiveInit.products.put(p.id, p);
    await _seedPriceTier(p);
  }
  Future<void> update(Product p, {double? oldUnitPrice}) async {
    // Prevent renaming into another existing product's name.
    final clash = HiveInit.products.values.any((e) =>
        e.id != p.id &&
        e.name.trim().toLowerCase() == p.name.trim().toLowerCase());
    if (clash) {
      throw Exception('هذا المنتج موجود مسبقاً، يرجى التعديل على مخزونه فقط');
    }
    p.currency = AppCurrency.syp;
    await p.save();
    // Sprint 2026-09: price-change tier tracking.
    final before = oldUnitPrice ?? p.unitPrice;
    if ((p.unitPrice - before).abs() > 0.0001) {
      await _rollPriceTier(p, oldPrice: before);
    }
  }
  Future<void> delete(Product p) async => await p.delete();

  /// Ensures an initial price tier exists right after product creation.
  Future<void> _seedPriceTier(Product p) async {
    final has = HiveInit.priceTiers.values.any((t) => t.productId == p.id);
    if (has) return;
    await HiveInit.priceTiers.put(
      '${p.id}-init',
      ProductPriceTier(
        id: '${p.id}-init',
        productId: p.id,
        productName: p.name,
        unitPrice: p.unitPrice,
        unit: p.unit,
        startedAt: p.createdAt,
      ),
    );
  }

  /// Closes the active tier at [oldPrice] and opens a new one at current price.
  Future<void> _rollPriceTier(Product p, {required double oldPrice}) async {
    final now = DateTime.now();
    final tiers = HiveInit.priceTiers.values
        .where((t) => t.productId == p.id)
        .toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    if (tiers.isEmpty) {
      // No history: seed the old price as the first interval, then the new.
      await HiveInit.priceTiers.put(
        '${p.id}-${now.millisecondsSinceEpoch}-old',
        ProductPriceTier(
          productId: p.id,
          productName: p.name,
          unitPrice: oldPrice,
          unit: p.unit,
          startedAt: p.createdAt,
          endedAt: now,
        ),
      );
    } else {
      final active = tiers.where((t) => t.isActive).toList();
      for (final t in active) {
        t.endedAt = now;
        t.productName = p.name;
        t.unit = p.unit;
        await t.save();
      }
    }
    await HiveInit.priceTiers.put(
      '${p.id}-${now.millisecondsSinceEpoch}',
      ProductPriceTier(
        productId: p.id,
        productName: p.name,
        unitPrice: p.unitPrice,
        unit: p.unit,
        startedAt: now,
      ),
    );
  }

  /// Sprint 2026-09: restock with batch finance.
  /// [purchaseCost] = TOTAL batch cost → supplier CREDIT (we owe).
  /// [downPayment] = initial amount paid → supplier PAYMENT entry.
  /// Batch remaining = purchaseCost - downPayment (minus later partial pays).
  /// Only [quantityAdded] mutates Product.stockQuantity.
  Future<StockLog> addStock({
    required Product product,
    required double quantityAdded,
    double purchaseCost = 0,
    double downPayment = 0,
    String supplierName = '',
    String supplierPhone = '',
    String suppliedMaterials = '',
    String notes = '',
  }) async {
    if (quantityAdded <= 0) throw Exception('الكمية المضافة مطلوبة ويجب أن تكون أكبر من صفر');
    if (supplierName.trim().isEmpty) throw Exception('اسم المورد/المصدر مطلوب');
    if (purchaseCost < 0) throw Exception('تكلفة الدفعة غير صالحة');
    if (downPayment < 0 || downPayment > purchaseCost) {
      throw Exception('الدفعة الأولى يجب أن تكون بين 0 وإجمالي تكلفة الدفعة');
    }
    product.stockQuantity += quantityAdded;
    await product.save();
    final log = StockLog(
      productId: product.id,
      productName: product.name,
      quantityAdded: quantityAdded,
      purchaseCost: purchaseCost,
      downPayment: downPayment,
      supplierName: supplierName.trim(),
      supplierPhone: supplierPhone.trim(),
      suppliedMaterials: suppliedMaterials.trim(),
      notes: notes.trim(),
    );
    await HiveInit.stockLogs.put(log.id, log);
    // Post batch finance (credit + down-payment), idempotent per batch id.
    await FinanceEngine.onStockBatchAdded(log);
    return log;
  }

  /// Records a partial payment to an inventory supplier (factory scope).
  /// Guarded by the inventory-scoped remaining (never global/project dues).
  Future<void> payInventorySupplier({
    required String partyId,
    required String partyName,
    String? partyPhone,
    required double amount,
    String reason = 'دفعة جزئية لمورد مخزون',
  }) async {
    if (amount <= 0) throw Exception('المبلغ مطلوب');
    final remaining = FinanceEngine.inventorySupplierRemaining(partyId);
    if (amount > remaining + 0.005) {
      throw Exception('المبلغ المدخل أكبر من المتبقي المستحق');
    }
    await FinanceEngine.addPayment(
      party: TransactionParty.supplier,
      partyId: partyId,
      partyName: partyName,
      partyPhone: partyPhone,
      amount: amount,
      source: 'دفعة جزئية مخزون - $partyName',
      reason: reason,
      relatedId: null,
      projectId: null,
      currency: AppCurrency.syp,
    );
  }
}
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

/// Sprint 2026-09 Task 5: chronological stock audit log stream.
final stockLogsProvider = StreamProvider<List<StockLog>>((ref) async* {
  final box = HiveInit.stockLogs;
  List<StockLog> getList() => box.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  yield getList();
  yield* box.watch().map((_) => getList());
});

/// Sprint 2026-09: live price-tier history stream.
final priceTiersProvider = StreamProvider<List<ProductPriceTier>>((ref) async* {
  final box = HiveInit.priceTiers;
  List<ProductPriceTier> getList() => box.values.toList()
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  yield getList();
  yield* box.watch().map((_) => getList());
});

/// Sprint 2026-09: sales & consumption analytics derived from invoices.
///
/// Source of truth = invoice lines (productId + quantity + invoice unitPrice
/// + invoice date). Each line is attributed to the price tier whose
/// [startedAt, endedAt) interval contains the invoice date; lines predating
/// all tiers fall back to matching by unitPrice, then to the earliest tier.
class ProductAnalytics {
  /// Total sold quantity + revenue per product (across ALL invoices).
  static Map<String, ({String name, String unit, double qty, double revenue, int invoices})>
      salesByProduct() {
    final out = <String, ({String name, String unit, double qty, double revenue, int invoices})>{};
    final seenInv = <String, Set<String>>{};
    for (final inv in HiveInit.invoices.values) {
      if (inv.isPaymentOnly) continue;
      for (final l in inv.effectiveItems) {
        final cur = out[l.productId];
        final set = seenInv.putIfAbsent(l.productId, () => <String>{});
        set.add(inv.id);
        out[l.productId] = (
          name: l.productName,
          unit: l.unit,
          qty: (cur?.qty ?? 0) + l.quantity,
          revenue: (cur?.revenue ?? 0) + l.lineTotal,
          invoices: set.length,
        );
      }
    }
    return out;
  }

  /// Tiers for one product, oldest → newest. Falls back to a synthetic tier
  /// from the catalog when no persisted history exists (pre-upgrade data).
  static List<ProductPriceTier> tiersForProduct(String productId) {
    final tiers = HiveInit.priceTiers.values
        .where((t) => t.productId == productId)
        .toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    if (tiers.isNotEmpty) return tiers;
    try {
      final p = HiveInit.products.values.firstWhere((e) => e.id == productId);
      return [
        ProductPriceTier(
          productId: p.id,
          productName: p.name,
          unitPrice: p.unitPrice,
          unit: p.unit,
          startedAt: p.createdAt,
        ),
      ];
    } catch (_) {
      return [];
    }
  }

  /// Sold qty + revenue inside ONE tier interval for a product.
  static ({double qty, double revenue, int lines}) salesInTier(
      String productId, ProductPriceTier tier) {
    double qty = 0, revenue = 0;
    int lines = 0;
    for (final inv in HiveInit.invoices.values) {
      if (inv.isPaymentOnly) continue;
      if (!tier.covers(inv.createdAt)) continue;
      for (final l in inv.effectiveItems) {
        if (l.productId != productId) continue;
        qty += l.quantity;
        revenue += l.lineTotal;
        lines++;
      }
    }
    return (qty: qty, revenue: revenue, lines: lines);
  }

  /// Distinct sold unit-prices inside a tier interval (handles invoice-level
  /// custom pricing): price → qty sold at exactly that price.
  static Map<double, double> priceBreakdownInTier(
      String productId, ProductPriceTier tier) {
    final map = <double, double>{};
    for (final inv in HiveInit.invoices.values) {
      if (inv.isPaymentOnly) continue;
      if (!tier.covers(inv.createdAt)) continue;
      for (final l in inv.effectiveItems) {
        if (l.productId != productId) continue;
        map[l.unitPrice] = (map[l.unitPrice] ?? 0) + l.quantity;
      }
    }
    return map;
  }
}
