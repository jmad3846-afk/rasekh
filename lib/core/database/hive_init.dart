import 'package:hive_flutter/hive_flutter.dart';
import '../../core/utils/currency.dart';
import '../../features/factory/data/models/product.dart';
import '../../features/factory/data/models/customer.dart';
import '../../features/factory/data/models/invoice.dart';
import '../../features/projects/data/models/project.dart';
import '../../features/projects/data/models/procedure.dart';
import '../../features/finance/data/models/transaction.dart';

class HiveInit {
  static Future<void> init() async {
    await Hive.initFlutter();
    // Register adapters - order matters, keep typeIds unique
    Hive.registerAdapter(ProductAdapter());
    Hive.registerAdapter(CustomerAdapter());
    Hive.registerAdapter(InvoiceAdapter());
    Hive.registerAdapter(ProjectAdapter());
    Hive.registerAdapter(ProcedureAdapter());
    Hive.registerAdapter(WorkshopWorkerAdapter());
    Hive.registerAdapter(SupplierInfoAdapter());
    Hive.registerAdapter(TransactionEntryAdapter());
    Hive.registerAdapter(ProcedureStatusAdapter());
    Hive.registerAdapter(TransactionTypeAdapter());
    Hive.registerAdapter(TransactionPartyAdapter());
    Hive.registerAdapter(AppCurrencyAdapter());

    await Future.wait([
      Hive.openBox<Product>('products'),
      Hive.openBox<Customer>('customers'),
      Hive.openBox<Invoice>('invoices'),
      Hive.openBox<Project>('projects'),
      Hive.openBox<Procedure>('procedures'),
      Hive.openBox<TransactionEntry>('transactions'),
    ]);
  }

  static Box<Product> get products => Hive.box<Product>('products');
  static Box<Customer> get customers => Hive.box<Customer>('customers');
  static Box<Invoice> get invoices => Hive.box<Invoice>('invoices');
  static Box<Project> get projects => Hive.box<Project>('projects');
  static Box<Procedure> get procedures => Hive.box<Procedure>('procedures');
  static Box<TransactionEntry> get transactions => Hive.box<TransactionEntry>('transactions');
}
