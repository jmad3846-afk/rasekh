import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/hive_init.dart';
import '../data/models/product.dart';
import '../data/models/invoice.dart';
import '../data/models/customer.dart';
import '../../finance/logic/finance_engine.dart';
import '../../finance/data/models/transaction.dart';

final productsProvider = StreamProvider<List<Product>>((ref) async* { final box=HiveInit.products; yield box.values.toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt)); yield* box.watch().map((_)=> box.values.toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt))); });
final productByIdProvider = Provider.family<Product?,String>((ref,id){ ref.watch(productsProvider); try{ return HiveInit.products.values.firstWhere((p)=> p.id==id);}catch(_){ return null; } });
class ProductNotifier { Future<void> add(Product p) async => await HiveInit.products.put(p.id,p); Future<void> update(Product p) async => await p.save(); Future<void> delete(Product p) async => await p.delete(); }
final invoicesProvider = StreamProvider<List<Invoice>>((ref) async* { final box=HiveInit.invoices; yield box.values.toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt)); yield* box.watch().map((_)=> box.values.toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt))); });
class InvoiceService {
  Future<Invoice> create({required String customerName, required String customerPhone, required String deliveryAddress, required Product product, required double quantity, required double downPayment}) async {
    if(downPayment<=0) throw Exception('الدفعة الأولى مطلوبة');
    if(downPayment>quantity*product.unitPrice) throw Exception('الدفعة أكبر من الإجمالي');
    if(product.stockQuantity<quantity) throw Exception('الكمية غير متوفرة: متاح ${product.stockQuantity}');
    Customer? customer; try{ customer=HiveInit.customers.values.firstWhere((c)=> c.phone==customerPhone);}catch(_){}
    customer ??= Customer(name:customerName, phone:customerPhone, address:deliveryAddress);
    await HiveInit.customers.put(customer.id,customer);
    final total=quantity*product.unitPrice;
    final inv=Invoice(customerId:customer.id, customerName:customer.name, customerPhone:customer.phone, deliveryAddress:deliveryAddress, productId:product.id, productName:product.name, quantity:quantity, unitPrice:product.unitPrice, totalPrice:total, downPayment:downPayment);
    product.stockQuantity-=quantity; await product.save();
    await HiveInit.invoices.put(inv.id,inv);
    await FinanceEngine.onInvoiceCreated(inv);
    return inv;
  }
  Future<void> delete(Invoice inv) async { final prod=HiveInit.products.get(inv.productId); if(prod!=null){ prod.stockQuantity+=inv.quantity; await prod.save(); } await inv.delete(); await FinanceEngine.addPayment(party:TransactionParty.client, partyId:inv.customerId, partyName:inv.customerName, amount:inv.remainingBalance, source:'حذف فاتورة ${inv.invoiceNumber}', relatedId:inv.id); }
}
final invoiceServiceProvider = Provider((ref)=> InvoiceService());
final productServiceProvider = Provider((ref)=> ProductNotifier());
