import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/hive_init.dart';
import '../../../core/utils/currency.dart';
import '../data/models/product.dart';
import '../data/models/invoice.dart';
import '../data/models/customer.dart';
import '../../finance/logic/finance_engine.dart';

final productsProvider = StreamProvider<List<Product>>((ref) async* { final box=HiveInit.products; yield box.values.toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt)); yield* box.watch().map((_)=> box.values.toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt))); });
final productByIdProvider = Provider.family<Product?,String>((ref,id){ ref.watch(productsProvider); try{ return HiveInit.products.values.firstWhere((p)=> p.id==id);}catch(_){ return null; } });
class ProductNotifier { Future<void> add(Product p) async => await HiveInit.products.put(p.id,p); Future<void> update(Product p) async => await p.save(); Future<void> delete(Product p) async => await p.delete(); }
final invoicesProvider = StreamProvider<List<Invoice>>((ref) async* { final box=HiveInit.invoices; yield box.values.toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt)); yield* box.watch().map((_)=> box.values.toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt))); });
class InvoiceService {
  Future<Invoice> create({required String customerName, required String customerPhone, required String deliveryAddress, required Product product, required double quantity, required double downPayment, AppCurrency currency = AppCurrency.syp}) async {
    if(downPayment<=0) throw Exception('الدفعة الأولى مطلوبة');
    if(downPayment>quantity*product.unitPrice) throw Exception('الدفعة أكبر من الإجمالي');
    if(product.stockQuantity<quantity) throw Exception('الكمية غير متوفرة: متاح ${product.stockQuantity}');
    Customer? customer; try{ customer=HiveInit.customers.values.firstWhere((c)=> c.phone==customerPhone);}catch(_){}
    customer ??= Customer(name:customerName, phone:customerPhone, address:deliveryAddress);
    // Keep customer name fresh.
    customer.name = customerName;
    customer.address = deliveryAddress;
    await HiveInit.customers.put(customer.id,customer);
    final total=quantity*product.unitPrice;
    final inv=Invoice(customerId:customer.id, customerName:customer.name, customerPhone:customer.phone, deliveryAddress:deliveryAddress, productId:product.id, productName:product.name, quantity:quantity, unitPrice:product.unitPrice, totalPrice:total, downPayment:downPayment, currency: currency);
    product.stockQuantity-=quantity; await product.save();
    await HiveInit.invoices.put(inv.id,inv);
    await FinanceEngine.onInvoiceCreated(inv);
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
    if (downPayment <= 0) throw Exception('الدفعة الأولى مطلوبة');
    final newTotal = quantity * product.unitPrice;
    if (downPayment > newTotal) throw Exception('الدفعة أكبر من الإجمالي');

    // Stock reconciliation.
    if (product.id == inv.productId) {
      // Same product: available = current stock + old qty.
      final available = product.stockQuantity + inv.quantity;
      if (quantity > available) {
        throw Exception('الكمية غير متوفرة: متاح $available');
      }
      product.stockQuantity = available - quantity;
      await product.save();
    } else {
      // Product changed: restore old, deduct new.
      final oldProd = HiveInit.products.get(inv.productId);
      if (oldProd != null) {
        oldProd.stockQuantity += inv.quantity;
        await oldProd.save();
      }
      if (product.stockQuantity < quantity) {
        throw Exception('الكمية غير متوفرة: متاح ${product.stockQuantity}');
      }
      product.stockQuantity -= quantity;
      await product.save();
    }

    inv.customerName = customerName;
    inv.customerPhone = customerPhone;
    inv.deliveryAddress = deliveryAddress;
    inv.productId = product.id;
    inv.productName = product.name;
    inv.quantity = quantity;
    inv.unitPrice = product.unitPrice;
    inv.totalPrice = newTotal;
    inv.downPayment = downPayment;
    inv.currency = currency;
    inv.recalc();
    await inv.save();

    // Refresh customer link (phone may have changed).
    Customer? customer;
    try {
      customer = HiveInit.customers.values.firstWhere((c) => c.id == inv.customerId);
    } catch (_) {}
    if (customer != null) {
      customer.name = customerName;
      customer.phone = customerPhone;
      customer.address = deliveryAddress;
      await customer.save();
    }

    await FinanceEngine.onInvoiceUpdated(inv);
    return inv;
  }

  /// Delete: restore stock + fully remove client debt (no write-off payment).
  Future<void> delete(Invoice inv) async {
    final prod=HiveInit.products.get(inv.productId);
    if(prod!=null){ prod.stockQuantity+=inv.quantity; await prod.save(); }
    await FinanceEngine.onInvoiceDeleted(inv);
    await inv.delete();
  }
}
final invoiceServiceProvider = Provider((ref)=> InvoiceService());
final productServiceProvider = Provider((ref)=> ProductNotifier());
