import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/widgets.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/theme/finance_widgets.dart';
import '../../logic/factory_providers.dart';
import '../../data/models/product.dart';
import '../../data/models/invoice.dart';
import '../../data/models/stock_log.dart';
import '../../../finance/logic/finance_engine.dart';
import '../../../finance/presentation/screens/ledger_screen.dart';
import 'product_form.dart';
import 'invoice_form.dart';
import 'inventory_suppliers_screen.dart';
import 'product_analytics_screen.dart';

class FactoryScreen extends ConsumerStatefulWidget {
  const FactoryScreen({super.key});
  @override ConsumerState<FactoryScreen> createState()=> _State();
}
class _State extends ConsumerState<FactoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  String productQuery = '';
  String invoiceQuery = '';
  String stockQuery = '';
  DateTime? stockDateFilter;
  final _productSearchCtrl = TextEditingController();
  final _invoiceSearchCtrl = TextEditingController();
  final _stockSearchCtrl = TextEditingController();

  @override void initState(){ super.initState(); _tab=TabController(length:5, vsync:this); _tab.addListener(()=> setState((){})); }
  @override void dispose(){ _tab.dispose(); _productSearchCtrl.dispose(); _invoiceSearchCtrl.dispose(); _stockSearchCtrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context){
    final productsAsync = ref.watch(productsProvider);
    final invoicesAsync = ref.watch(invoicesProvider);
    final stockAsync = ref.watch(stockLogsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('قسم المعمل', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        bottom: TabBar(controller:_tab, labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: AppColors.gold, isScrollable: true, tabs: const [
          Tab(text:'المنتجات', icon: Icon(Icons.inventory_2)),
          Tab(text:'الفواتير', icon: Icon(Icons.receipt_long)),
          Tab(text:'إدارة المخزون', icon: Icon(Icons.inventory_outlined)),
          Tab(text:'المصروفات والإحصائيات', icon: Icon(Icons.analytics_outlined)),
          Tab(text:'موردو المخزون', icon: Icon(Icons.local_shipping_outlined)),
        ]),
      ),
      body: TabBarView(controller:_tab, children:[
        // PRODUCTS TAB with inline search
        productsAsync.when(
          data:(products)=> Column(children:[
            _searchBar(_productSearchCtrl, 'بحث بالاسم أو الفئة...', (v)=> setState(()=> productQuery = v)),
            Expanded(child: _productsList(_filteredProducts(products))),
          ]),
          loading: ()=> const Center(child: CircularProgressIndicator()),
          error:(e,s)=> Center(child: Text('$e')),
        ),
        invoicesAsync.when(
          data:(invoices)=> Column(children:[
            _searchBar(_invoiceSearchCtrl, 'بحث باسم الزبون أو الهاتف...', (v)=> setState(()=> invoiceQuery = v)),
            Expanded(child: _invoicesList(_filteredInvoices(invoices))),
          ]),
          loading: ()=> const Center(child: CircularProgressIndicator()),
          error:(e,s)=> Center(child: Text('$e')),
        ),
        // STOCK MANAGEMENT LOGS TAB (Task 5) — right next to Invoices.
        stockAsync.when(
          data:(logs)=> Column(children:[
            _searchBar(_stockSearchCtrl, 'بحث باسم الشخص/المورد...', (v)=> setState(()=> stockQuery = v)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children:[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                          context: context,
                          initialDate: stockDateFilter ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2040));
                      if (picked != null) setState(()=> stockDateFilter = picked);
                    },
                    icon: const Icon(Icons.calendar_month_outlined, size: 16),
                    label: Text(
                        stockDateFilter == null
                            ? 'فلترة بالتاريخ'
                            : 'التاريخ: ${stockDateFilter.toString().substring(0, 10)}',
                        style: GoogleFonts.cairo(fontSize: 12)),
                  ),
                ),
                if (stockDateFilter != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'مسح فلتر التاريخ',
                    onPressed: ()=> setState(()=> stockDateFilter = null),
                    icon: const Icon(Icons.clear, size: 18),
                  ),
                ],
              ]),
            ),
            Expanded(child: _stockLogsList(_filteredStockLogs(logs))),
          ]),
          loading: ()=> const Center(child: CircularProgressIndicator()),
          error:(e,s)=> Center(child: Text('$e')),
        ),
        // EXPENSES & ANALYTICS TAB — right next to Inventory.
        const ProductAnalyticsTab(),
        // INVENTORY SUPPLIERS LEDGER TAB.
        const InventorySuppliersTab(),
      ]),
      floatingActionButton: _tab.index > 1
          ? null
          : FloatingActionButton.extended(
        backgroundColor: AppColors.gold, foregroundColor: Colors.white,
        onPressed: ()=> _tab.index==0
            ? showModalBottomSheet(context:context, isScrollControlled:true, builder:(_)=> const ProductFormSheet())
            : Navigator.push(context, MaterialPageRoute(builder:(_)=> const InvoiceFormScreen())),
        icon: const Icon(Icons.add), label: Text(_tab.index==0?'منتج جديد':'فاتورة جديدة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _searchBar(TextEditingController ctrl, String hint, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16,12,16,4),
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.cairo(fontSize:12, color: AppColors.textSecondary),
          prefixIcon: const Icon(Icons.search, size:20),
          suffixIcon: ctrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size:18), onPressed:(){ ctrl.clear(); onChanged(''); }) : null,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        ),
      ),
    );
  }

  List<Product> _filteredProducts(List<Product> all) {
    final q = productQuery.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((p) => p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q)).toList();
  }

  List<Invoice> _filteredInvoices(List<Invoice> all) {
    final q = invoiceQuery.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((i) => i.customerName.toLowerCase().contains(q) || i.customerPhone.toLowerCase().contains(q) || i.invoiceNumber.toLowerCase().contains(q)).toList();
  }

  List<dynamic> _filteredStockLogs(List<dynamic> all) {
    return all.where((l) {
      final query = stockQuery.trim().toLowerCase();
      final matchesQ = FinanceEngine.matchesStockLogQuery(
        StockLog(
          productId: (l.productId as String?) ?? '',
          productName: (l.productName as String?) ?? '',
          quantityAdded: (l.quantityAdded as double?) ?? 0,
          purchaseCost: (l.purchaseCost as double?) ?? 0,
          supplierName: (l.supplierName as String?) ?? '',
          supplierPhone: (l.supplierPhone as String?) ?? '',
          suppliedMaterials: (l.suppliedMaterials as String?) ?? '',
          notes: (l.notes as String?) ?? '',
          createdAt: l.createdAt as DateTime,
          downPayment: (l.downPayment as double?) ?? 0,
        ),
        query,
      );
      final matchesDate = stockDateFilter == null ||
          (l.createdAt.year == stockDateFilter!.year &&
              l.createdAt.month == stockDateFilter!.month &&
              l.createdAt.day == stockDateFilter!.day);
      return matchesQ && matchesDate;
    }).toList();
  }

  Widget _productsList(List<Product> products){
    if(products.isEmpty) return Center(child: Column(mainAxisAlignment:MainAxisAlignment.center, children:[Icon(Icons.inventory_2_outlined,size:64,color: Colors.grey[300]), const SizedBox(height:12), Text(productQuery.isEmpty ? 'لا توجد منتجات' : 'لا نتائج مطابقة للبحث', style: GoogleFonts.cairo(color: AppColors.textSecondary))]));
    return ListView.separated(
      padding: const EdgeInsets.all(16), itemCount: products.length,
      separatorBuilder: (_,__)=> const SizedBox(height:12),
      itemBuilder: (_,i){
        final p=products[i];
        final low = p.isLowStock;
        return GlassCard(child: Row(children:[
          Container(width:56,height:56,decoration:BoxDecoration(color: low?AppColors.errorBg:AppColors.goldLight, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.category, color: low?AppColors.error:AppColors.goldDark)),
          const SizedBox(width:12),
          Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
            Row(children:[
              Flexible(child: Text(p.name, style: GoogleFonts.cairo(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
              const SizedBox(width:6),
              CurrencyBadge(p.currency),
            ]),
            Text('${p.category} • ${Money.withCurrency(p.unitPrice, p.currency)}/${p.unit}', style: GoogleFonts.cairo(fontSize:11,color: AppColors.textSecondary)),
            const SizedBox(height:4),
            Row(children:[
              Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:2), decoration: BoxDecoration(color: low?AppColors.errorBg:AppColors.successBg, borderRadius: BorderRadius.circular(20)), child: Text('${p.stockQuantity.toStringAsFixed(0)} متوفر', style: GoogleFonts.cairo(fontSize:11,color: low?AppColors.error:AppColors.success, fontWeight: FontWeight.w700))),
            ])
          ])),
          PopupMenuButton(onSelected: (v) async {
            if(v=='edit') showModalBottomSheet(context:context, isScrollControlled:true, builder:(_)=> ProductFormSheet(product:p));
            if(v=='stock') _showManageStock(p);
            if(v=='delete'){
              final ok = await confirmDelete(context,
                  title: 'حذف المنتج؟',
                  message: 'هل أنت متأكد من حذف "${p.name}" نهائياً؟ لا يمكن التراجع.');
              if(ok){
                await ref.read(productServiceProvider).delete(p);
                if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف ${p.name}', style: GoogleFonts.cairo())));
              }
            }
          }, itemBuilder: (_)=> [
            PopupMenuItem(value:'edit', child: Text('تعديل', style: GoogleFonts.cairo())),
            PopupMenuItem(value:'stock', child: Text('إدارة المخزون / إضافة مخزون', style: GoogleFonts.cairo(fontWeight: FontWeight.w700))),
            PopupMenuItem(value:'delete', child: Text('حذف', style: GoogleFonts.cairo(color: AppColors.error))),
          ]),
        ]));
      },
    );
  }

  /// Manage Stock dialog: restock + batch finance (down payment → ledger).
  /// Supplier name auto-completes from existing inventory suppliers and
  /// auto-fills phone + supplied materials; unknown names become new suppliers.
  void _showManageStock(Product p) {
    final qtyC = TextEditingController();
    final costC = TextEditingController();
    final downC = TextEditingController();
    final supplierC = TextEditingController();
    final phoneC = TextEditingController();
    final materialsC = TextEditingController();
    final notesC = TextEditingController();
    final profiles = FinanceEngine.inventorySupplierProfiles();
    bool autoFilled = false;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setD) {
        final total = double.tryParse(costC.text) ?? 0;
        final dp = double.tryParse(downC.text) ?? 0;
        final remaining = (total - dp).clamp(0, double.infinity);
        final over = dp > total + 0.005;
        // Smart supplier search: live matches on every keystroke.
        final q = supplierC.text.trim().toLowerCase();
        final matches = q.isEmpty
            ? const <MapEntry<String, ({String name, String phone, String suppliedMaterials})>>[]
            : profiles.entries
                .where((e) =>
                    e.value.name.toLowerCase().contains(q) ||
                    e.value.phone.toLowerCase().contains(q))
                .take(5)
                .toList();
        return AlertDialog(
        title: Text('إدارة المخزون — ${p.name}',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('المخزون الحالي: ${p.stockQuantity.toStringAsFixed(0)} ${p.unit}',
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
                controller: qtyC,
                decoration: const InputDecoration(
                    labelText: 'الكمية المضافة *',
                    prefixIcon: Icon(Icons.add_box_outlined, size: 18)),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ]),
            const SizedBox(height: 8),
            TextField(
                controller: costC,
                onChanged: (_) => setD(() {}),
                decoration: const InputDecoration(
                    labelText: 'إجمالي تكلفة الدفعة (ل.س) *',
                    hintText: 'المبلغ الكلي الذي كلفته هذه الكمية',
                    prefixIcon: Icon(Icons.price_change_outlined, size: 18)),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ]),
            const SizedBox(height: 8),
            TextField(
                controller: downC,
                onChanged: (_) => setD(() {}),
                decoration: const InputDecoration(
                    labelText: 'الدفعة الأولى (ل.س)',
                    hintText: '0 إذا بدون دفعة — تُسجل في ذمة المورد',
                    prefixIcon: Icon(Icons.payments_outlined, size: 18)),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ]),
            if (total > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: over
                        ? AppColors.errorBg
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border)),
                child: Column(children: [
                  Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text('إجمالي الدفعة',
                            style: GoogleFonts.cairo(fontSize: 11)),
                        Text(
                            Money.withCurrency(
                                total, AppCurrency.syp),
                            style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                      ]),
                  Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الدفعة الأولى',
                            style: GoogleFonts.cairo(fontSize: 11)),
                        Text(
                            Money.withCurrency(dp, AppCurrency.syp),
                            style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success)),
                      ]),
                  const Divider(height: 12),
                  Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text('المتبقي للمورد',
                            style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        Text(
                            Money.withCurrency(
                                remaining.toDouble(), AppCurrency.syp),
                            style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.error)),
                      ]),
                  if (over)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                          'المبلغ المدخل أكبر من المتبقي المستحق',
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error)),
                    ),
                ]),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
                controller: supplierC,
                onChanged: (_) => setD(() => autoFilled = false),
                decoration: const InputDecoration(
                    labelText: 'الاسم (المورد/المصدر) *',
                    hintText: 'ابحث باسم مورد موجود أو أدخل مورداً جديداً',
                    prefixIcon:
                        Icon(Icons.person_search_outlined, size: 18))),
            // ── Smart auto-complete suggestions ──
            if (q.isNotEmpty && matches.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final m in matches)
                      InkWell(
                        onTap: () {
                          supplierC.text = m.value.name;
                          phoneC.text = m.value.phone.trim().isEmpty
                              ? ''
                              : m.value.phone;
                          materialsC.text = m.value.suppliedMaterials;
                          setD(() => autoFilled = true);
                          // Force immediate UI refresh in the dialog state so the
                          // phone field displays the selected supplier's number.
                          setState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          child: Row(children: [
                            const Icon(
                                Icons.local_shipping_outlined,
                                size: 16,
                                color: AppColors.goldDark),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(m.value.name,
                                      style: GoogleFonts.cairo(
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.w700),
                                      overflow:
                                          TextOverflow.ellipsis),
                                  Text(
                                      m.value.suppliedMaterials
                                              .trim()
                                              .isEmpty
                                          ? m.value.phone
                                          : '${m.value.phone} • ${m.value.suppliedMaterials}',
                                      style: GoogleFonts.cairo(
                                          fontSize: 11,
                                          color: AppColors
                                              .textSecondary),
                                      overflow:
                                          TextOverflow.ellipsis),
                                ])),
                            const Icon(Icons.north_west,
                                size: 14,
                                color: AppColors.textSecondary),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (q.isNotEmpty && matches.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.person_add_outlined,
                        size: 14, color: AppColors.success),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(
                            'مورد جديد: "$q" — سيُحفظ مع هذه الدفعة',
                            style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success),
                            overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              ),
            if (autoFilled)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    'تمت تعبئة الرقم والمواد تلقائياً من سجل المورد — قابلة للتعديل',
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppColors.success,
                        fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 8),
            TextField(
                controller: phoneC,
                decoration: const InputDecoration(labelText: 'الرقم'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
            const SizedBox(height: 8),
            TextField(
                controller: materialsC,
                decoration: const InputDecoration(
                    labelText:
                        'المواد التي يبيعها هذا المورد *',
                    hintText: 'مثال: سمنت، حديد، رمل',
                    prefixIcon:
                        Icon(Icons.inventory_2_outlined, size: 18)),
                maxLines: 2),
            const SizedBox(height: 8),
            TextField(
                controller: notesC,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
                maxLines: 2),
            const SizedBox(height: 4),
            Text('إضافة المخزون تُحدِّث كمية المنتج وتُسجِّل التكلفة والذمة في مالية موردي المخزون.',
                style: GoogleFonts.cairo(
                    fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(productServiceProvider).addStock(
                      product: p,
                      quantityAdded: double.tryParse(qtyC.text) ?? 0,
                      purchaseCost: double.tryParse(costC.text) ?? 0,
                      downPayment: double.tryParse(downC.text) ?? 0,
                      supplierName: supplierC.text,
                      supplierPhone: phoneC.text,
                      suppliedMaterials: materialsC.text,
                      notes: notesC.text,
                    );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('تمت إضافة المخزون لـ ${p.name}',
                          style: GoogleFonts.cairo()),
                      backgroundColor: AppColors.success));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('$e'.replaceAll('Exception: ', ''),
                          style: GoogleFonts.cairo()),
                      backgroundColor: AppColors.error));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepNavy),
            child: Text('إضافة المخزون', style: GoogleFonts.cairo()),
          ),
        ],
        );
      }),
    );
  }

  Widget _stockLogsList(List<dynamic> logs) {
    if (logs.isEmpty) {
      return Center(
          child: Text(
              (stockQuery.isEmpty && stockDateFilter == null)
                  ? 'لا توجد حركات مخزون بعد'
                  : 'لا نتائج مطابقة للبحث',
              style: GoogleFonts.cairo(color: AppColors.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final l = logs[i];
        return GlassCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.inventory_outlined,
                        color: AppColors.success)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(l.productName as String,
                          style:
                              GoogleFonts.cairo(fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis),
                      Text(
                          '${(l.createdAt as DateTime).toString().substring(0, 16)} • ${(l.supplierName as String).isEmpty ? 'بدون مصدر' : l.supplierName}',
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ])),
                Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                        '+${(l.quantityAdded as double).toStringAsFixed(0)}',
                        style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.success,
                            fontWeight: FontWeight.w800))),
              ]),
              if ((l.notes as String).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('ملاحظات: ${l.notes}',
                      style: GoogleFonts.cairo(
                          fontSize: 11, color: AppColors.textSecondary)),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    'الإجمالي: ${Money.withCurrency((l.purchaseCost as double), AppCurrency.syp)} • الأولى: ${Money.withCurrency((l.downPayment as double), AppCurrency.syp)} • متبقي الدفعة: ${Money.withCurrency((((l.purchaseCost as double) - (l.downPayment as double)).clamp(0, double.infinity)).toDouble(), AppCurrency.syp)}${(l.supplierPhone as String).isNotEmpty ? ' • ${l.supplierPhone}' : ''}',
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.goldDark)),
              ),
            ]));
      },
    );
  }

  Widget _invoicesList(List<Invoice> invoices){
    if(invoices.isEmpty) return Center(child: Text(invoiceQuery.isEmpty ? 'لا توجد فواتير' : 'لا نتائج مطابقة للبحث', style: GoogleFonts.cairo(color: AppColors.textSecondary)));
    return ListView.separated(
      padding: const EdgeInsets.all(16), itemCount: invoices.length,
      separatorBuilder: (_,__)=> const SizedBox(height:12),
      itemBuilder: (_,i){
        final inv=invoices[i];
        return GlassCard(
            onTap: () => showInvoiceDetail(context, inv),
            child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Row(children:[
            Flexible(child: Text(inv.invoiceNumber, style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize:13))),
            _currencyBadge(inv.currency),
            if (inv.isPaymentOnly)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.deepNavy, borderRadius: BorderRadius.circular(20)),
                child: Text('دفعة', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            const Spacer(),
            Text(inv.createdAt.toString().substring(0,10), style: GoogleFonts.cairo(fontSize:11,color: AppColors.textSecondary)),
            PopupMenuButton(onSelected: (v) async {
              if (v == 'edit') {
                Navigator.push(context, MaterialPageRoute(builder:(_)=> InvoiceFormScreen(invoice: inv)));
              }
              if (v == 'delete') {
                final ok = await showDialog<bool>(context:context, builder:(_)=> AlertDialog(
                  title: Text('حذف الفاتورة؟', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
                  content: Text('سيتم إرجاع ${inv.quantity.toStringAsFixed(0)} للمخزون وحذف دين الزبون ${Money.withCurrency(inv.remainingBalance, inv.currency)} نهائياً.', style: GoogleFonts.cairo(fontSize:13)),
                  actions:[
                    TextButton(onPressed: ()=> Navigator.pop(context,false), child: Text('إلغاء', style: GoogleFonts.cairo())),
                    ElevatedButton(onPressed: ()=> Navigator.pop(context,true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: Text('حذف', style: GoogleFonts.cairo(color: Colors.white))),
                  ],
                ));
                if (ok == true) {
                  try {
                    await ref.read(invoiceServiceProvider).delete(inv);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف ${inv.invoiceNumber} وإرجاع المخزون', style: GoogleFonts.cairo()), backgroundColor: AppColors.success));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: GoogleFonts.cairo()), backgroundColor: AppColors.error));
                  }
                }
              }
            }, itemBuilder: (_)=> [
              PopupMenuItem(value:'edit', child: Text('تعديل', style: GoogleFonts.cairo())),
              PopupMenuItem(value:'delete', child: Text('حذف', style: GoogleFonts.cairo(color: AppColors.error))),
            ]),
          ]),
          const Divider(),
          if (inv.isPaymentOnly)
            Row(children:[
              Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
                Text(inv.customerName, style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                Text(inv.customerPhone, style: GoogleFonts.cairo(fontSize:11,color: AppColors.textSecondary)),
                if (inv.notes.isNotEmpty) Text(inv.notes, style: GoogleFonts.cairo(fontSize:11, color: AppColors.textSecondary)),
              ])),
              Column(crossAxisAlignment:CrossAxisAlignment.end, children:[
                Text(Money.withCurrency(inv.totalPrice, inv.currency), style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
                Text('تسوية مباشرة', style: GoogleFonts.cairo(fontSize:11,color: AppColors.success)),
              ])
            ])
          else
          Row(children:[
            Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              Text(inv.customerName, style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              Text('${inv.customerPhone} • ${inv.deliveryAddress}', style: GoogleFonts.cairo(fontSize:11,color: AppColors.textSecondary)),
              const SizedBox(height:4),
              Text('${inv.productName} x${inv.quantity} @ ${Money.withCurrency(inv.unitPrice, inv.currency)}', style: GoogleFonts.cairo(fontSize:11)),
            ])),
            Column(crossAxisAlignment:CrossAxisAlignment.end, children:[
              Text(Money.withCurrency(inv.totalPrice, inv.currency), style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
              Text('دفعة: ${Money.withCurrency(inv.downPayment, inv.currency)}', style: GoogleFonts.cairo(fontSize:11,color: AppColors.success)),
              Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:2), decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(20)), child: Text('متبقي ${Money.withCurrency(inv.remainingBalance, inv.currency)}', style: GoogleFonts.cairo(fontSize:11,color: AppColors.error, fontWeight: FontWeight.w700))),
            ])
          ])
        ]));
      },
    );
  }

  Widget _currencyBadge(AppCurrency c) => CurrencyBadge(c);
}
