import 'package:hive_flutter/hive_flutter.dart';
import '../../core/utils/currency.dart';
import '../../features/factory/data/models/product.dart';
import '../../features/factory/data/models/customer.dart';
import '../../features/factory/data/models/invoice.dart';
import '../../features/factory/data/models/stock_log.dart';
import '../../features/factory/data/models/price_tier.dart';
import '../../features/projects/data/models/project.dart';
import '../../features/projects/data/models/procedure.dart';
import '../../features/finance/data/models/transaction.dart';
import '../../features/personnel/data/models/personnel.dart';
import '../../features/projects/data/models/site_materials.dart';
import '../../features/projects/data/models/site_procedure.dart';

class HiveInit {
  static Future<void> init() async {
    await Hive.initFlutter();
    // Register adapters - order matters, keep typeIds unique
    Hive.registerAdapter(ProductAdapter());
    Hive.registerAdapter(CustomerAdapter());
    Hive.registerAdapter(InvoiceAdapter());
    Hive.registerAdapter(InvoiceItemAdapter());
    Hive.registerAdapter(InvoiceTypeAdapter());
    Hive.registerAdapter(ProjectAdapter());
    Hive.registerAdapter(ProcedureAdapter());
    Hive.registerAdapter(WorkshopWorkerAdapter());
    Hive.registerAdapter(SupplierInfoAdapter());
    Hive.registerAdapter(TransactionEntryAdapter());
    Hive.registerAdapter(ProcedureStatusAdapter());
    Hive.registerAdapter(TransactionTypeAdapter());
    Hive.registerAdapter(TransactionPartyAdapter());
    Hive.registerAdapter(AppCurrencyAdapter());
    // Req #10 / #11: new entities
    Hive.registerAdapter(PersonnelEntryAdapter());
    Hive.registerAdapter(PersonnelRoleAdapter());
    Hive.registerAdapter(RequiredMaterialAdapter());
    Hive.registerAdapter(DailyLogAdapter());
    Hive.registerAdapter(SiteProcedureAdapter());
    Hive.registerAdapter(SiteProcedureKindAdapter());
    Hive.registerAdapter(MasterContractTypeAdapter());
    Hive.registerAdapter(ConsumedMaterialAdapter());
    Hive.registerAdapter(StockLogAdapter());
    Hive.registerAdapter(ProductPriceTierAdapter());

    await Future.wait([
      Hive.openBox<Product>('products'),
      Hive.openBox<Customer>('customers'),
      Hive.openBox<Invoice>('invoices'),
      Hive.openBox<Project>('projects'),
      Hive.openBox<Procedure>('procedures'),
      Hive.openBox<TransactionEntry>('transactions'),
      Hive.openBox<PersonnelEntry>('personnel'),
      Hive.openBox<RequiredMaterial>('required_materials'),
      Hive.openBox<DailyLog>('daily_logs'),
      Hive.openBox<SiteProcedure>('site_procedures'),
      Hive.openBox<StockLog>('stock_logs'),
      Hive.openBox<ProductPriceTier>('price_tiers'),
    ]);
  }

  static Box<Product> get products => Hive.box<Product>('products');
  static Box<Customer> get customers => Hive.box<Customer>('customers');
  static Box<Invoice> get invoices => Hive.box<Invoice>('invoices');
  static Box<Project> get projects => Hive.box<Project>('projects');
  static Box<Procedure> get procedures => Hive.box<Procedure>('procedures');
  static Box<TransactionEntry> get transactions => Hive.box<TransactionEntry>('transactions');
  static Box<PersonnelEntry> get personnel => Hive.box<PersonnelEntry>('personnel');
  static Box<RequiredMaterial> get requiredMaterials => Hive.box<RequiredMaterial>('required_materials');
  static Box<DailyLog> get dailyLogs => Hive.box<DailyLog>('daily_logs');
  static Box<SiteProcedure> get siteProcedures => Hive.box<SiteProcedure>('site_procedures');
  static Box<StockLog> get stockLogs => Hive.box<StockLog>('stock_logs');
  static Box<ProductPriceTier> get priceTiers => Hive.box<ProductPriceTier>('price_tiers');
}
