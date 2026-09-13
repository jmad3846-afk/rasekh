import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/database/hive_init.dart';
import '../../logic/factory_providers.dart';
import '../../data/models/invoice.dart';
import '../../data/models/product.dart';

/// Standard + payment-only invoices — single SYP currency, stock guard,
/// per-invoice custom pricing (catalog price is pre-filled but editable).
class InvoiceFormScreen extends ConsumerStatefulWidget {
  final Invoice? invoice; // null = create
  const InvoiceFormScreen({super.key, this.invoice});
  @override ConsumerState<InvoiceFormScreen> createState()=> _S();
}
class _S extends ConsumerState<InvoiceFormScreen> {
  final _form=GlobalKey<FormState>();
  late TextEditingController name, phone, address, qty, priceCtrl, down, notes, payAmount;
  Product? selected;
  // Single-currency architecture: entire app is SYP.
  final AppCurrency currency = AppCurrency.syp;
  InvoiceType invType = InvoiceType.standard;
  List<InvoiceItem> lines = [];
  bool saving = false;

  bool get isEdit => widget.invoice != null;

  double get total => lines.fold(0.0, (s, e) => s + e.lineTotal);
  double get remaining => total - (double.tryParse(down.text) ?? 0);

  /// Stock available for currently selected product (edit-aware: add back
  /// old reserved qty so editing doesn't falsely reject).
  double _availableFor(Product p) {
    double oldReserved = 0;
    if (isEdit) {
      for (final o in widget.invoice!.effectiveItems) {
        if (o.productId == p.id) oldReserved += o.quantity;
      }
    }
    return p.stockQuantity + oldReserved;
  }

  String? get qtyStockError {
    if (selected == null) return null;
    final q = double.tryParse(qty.text) ?? 0;
    if (q <= 0) return null;
    if (q > _availableFor(selected!)) return 'الكمية غير كافية';
    return null;
  }

  @override void initState() {
    super.initState();
    final inv = widget.invoice;
    name = TextEditingController(text: inv?.customerName ?? '');
    phone = TextEditingController(text: inv?.customerPhone ?? '');
    address = TextEditingController(text: inv?.deliveryAddress ?? '');
    qty = TextEditingController(text: '1');
    priceCtrl = TextEditingController(text: '');
    down = TextEditingController(text: inv != null && !inv.isPaymentOnly ? inv.downPayment.toString() : '');
    notes = TextEditingController(text: inv?.notes ?? '');
    payAmount = TextEditingController(text: inv != null && inv.isPaymentOnly ? inv.totalPrice.toString() : '');
    invType = inv?.type ?? InvoiceType.standard;
    if (inv != null && inv.items.isNotEmpty) {
      lines = inv.items.map((e)=> InvoiceItem(
        productId: e.productId, productName: e.productName,
        quantity: e.quantity, unitPrice: e.unitPrice, unit: e.unit)).toList();
    }
  }

  @override void dispose() {
    name.dispose(); phone.dispose(); address.dispose();
    qty.dispose(); priceCtrl.dispose(); down.dispose(); notes.dispose(); payAmount.dispose();
    super.dispose();
  }

  List<Product> _matchProducts(List<Product> all, String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return all.take(5).toList();
    return all.where((p)=> p.name.toLowerCase().contains(s) || p.category.toLowerCase().contains(s)).take(5).toList();
  }

  void _onProductSelected(Product p) {
    setState(() {
      selected = p;
      // Pre-fill catalog price, editable per-invoice (does NOT touch catalog).
      priceCtrl.text = p.unitPrice.toString();
    });
  }

  void _addLine() {
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('اختر منتجاً أولاً', style: GoogleFonts.cairo())));
      return;
    }
    final q = double.tryParse(qty.text) ?? 0;
    if (q <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('أدخل كمية صحيحة', style: GoogleFonts.cairo())));
      return;
    }
    // Stock guard: reject immediately.
    if (q > _availableFor(selected!)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('الكمية غير كافية — متوفر ${_availableFor(selected!).toStringAsFixed(0)} فقط',
              style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error));
      setState(() {});
      return;
    }
    final customPrice = double.tryParse(priceCtrl.text) ?? selected!.unitPrice;
    if (customPrice < 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('السعر غير صالح', style: GoogleFonts.cairo())));
      return;
    }
    setState(()=> lines.add(InvoiceItem(
      productId: selected!.id, productName: selected!.name,
      quantity: q, unitPrice: customPrice, unit: selected!.unit)));
    qty.text = '1';
  }

  @override Widget build(BuildContext context){
    final products = ref.watch(productsProvider).value ?? [];
    final customers = HiveInit.customers.values.toList();
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'تعديل الفاتورة ${widget.invoice!.invoiceNumber}' : 'فاتورة جديدة', style: GoogleFonts.cairo(fontWeight: FontWeight.w800))),
      body: Form(key:_form, child: ListView(padding: const EdgeInsets.all(16), children:[
        // ── Type selector ──
        Text('نوع الفاتورة *', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children:[
          Expanded(child: _typeOption(InvoiceType.standard, 'فاتورة عادية', 'منتجات + حسابات')),
          const SizedBox(width: 12),
          Expanded(child: _typeOption(InvoiceType.paymentOnly, 'فاتورة دفعة', 'تسوية مالية فقط')),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(children:[
            const Icon(Icons.currency_exchange, size: 18, color: AppColors.goldDark),
            const SizedBox(width: 8),
            Text('العملة الأساسية: ل.س (ليرة سورية) — ثابتة لكل التطبيق',
                style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.goldDark)),
          ]),
        ),
        const SizedBox(height: 16),
        Text('بيانات الزبون', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: name.text),
          optionsBuilder: (v) {
            final q = v.text.trim().toLowerCase();
            if (q.isEmpty) return const Iterable<String>.empty();
            final names = customers.map((c)=> c.name).toSet().toList();
            return names.where((n)=> n.toLowerCase().contains(q)).take(5);
          },
          onSelected: (sel) {
            try {
              final c = customers.firstWhere((e)=> e.name == sel);
              setState(() {
                name.text = c.name;
                phone.text = c.phone;
                if (c.address != null && c.address!.isNotEmpty) address.text = c.address!;
              });
            } catch (_) {
              setState(()=> name.text = sel);
            }
          },
          fieldViewBuilder: (ctx, ctrl, focus, onSubmit) {
            if (ctrl.text != name.text && focus.hasFocus == false) {}
            return TextFormField(
              controller: ctrl,
              focusNode: focus,
              decoration: const InputDecoration(labelText: 'اسم الزبون * (بحث تلقائي)', prefixIcon: Icon(Icons.person_search_outlined)),
              validator: (v)=> (v == null || v.isEmpty) ? 'مطلوب' : null,
              onChanged: (v)=> name.text = v,
            );
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: phone,
          decoration: const InputDecoration(labelText:'رقم الهاتف *', prefixIcon: Icon(Icons.phone_outlined)),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator:(v)=> v!.isEmpty?'مطلوب':null),
        if (invType == InvoiceType.standard) ...[
          const SizedBox(height:12),
          TextFormField(controller:address, decoration: const InputDecoration(labelText:'عنوان التوصيل *', prefixIcon: Icon(Icons.location_on_outlined)), validator:(v)=> v!.isEmpty?'مطلوب':null),
        ],
        const SizedBox(height: 12),
        TextFormField(controller:notes, decoration: const InputDecoration(labelText:'ملاحظات', prefixIcon: Icon(Icons.note_outlined)), maxLines: 2),
        const SizedBox(height: 20),

        if (invType == InvoiceType.paymentOnly) ...[
          Text('مبلغ الدفعة (ل.س)', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextFormField(controller:payAmount, decoration: const InputDecoration(labelText:'المبلغ (ل.س) *'), keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onChanged:(_)=> setState(()=>{}),
            validator:(v){
              if(v==null||v.isEmpty) return 'مطلوب';
              if(double.tryParse(v)==null||double.parse(v)<=0) return '>0 مطلوب';
              return null;
            }),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(16)), child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:[Text('مبلغ التسوية', style: GoogleFonts.cairo(color: Colors.white70)),
              Flexible(child: Text(Money.withCurrency(double.tryParse(payAmount.text) ?? 0, currency), style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w800)))])),
        ] else ...[
          Text('المنتجات', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children:[
            Expanded(
              flex: 3,
              child: Autocomplete<Product>(
                optionsBuilder: (v) => _matchProducts(products, v.text),
                displayStringForOption: (p)=> p.name,
                onSelected: _onProductSelected,
                fieldViewBuilder: (ctx, ctrl, focus, onSubmit) => TextFormField(
                  controller: ctrl, focusNode: focus,
                  decoration: const InputDecoration(labelText: 'ابحث عن منتج *', prefixIcon: Icon(Icons.inventory_2_outlined), isDense: true),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: qty,
                decoration: InputDecoration(
                  labelText: 'الكمية',
                  isDense: true,
                  errorText: qtyStockError,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                onChanged: (_) => setState(() {}),
              ),
            ),
            IconButton(
              tooltip: 'إضافة للمسودة',
              onPressed: _addLine,
              icon: const Icon(Icons.add_circle, color: AppColors.deepNavy, size: 28),
            ),
          ]),
          if (selected != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${selected!.name} • سعر الكتالوج ${Money.withCurrency(selected!.unitPrice, AppCurrency.syp)}/${selected!.unit} • متوفر ${_availableFor(selected!).toStringAsFixed(0)}',
                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 8),
            // Per-invoice custom price (editable, invoice-scoped only).
            TextFormField(
              controller: priceCtrl,
              decoration: const InputDecoration(
                labelText: 'سعر الوحدة في هذه الفاتورة (ل.س) * — قابل للتعديل (خصم/سعر خاص)',
                prefixIcon: Icon(Icons.price_change_outlined),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              validator: (v) {
                if (v == null || v.isEmpty) return 'مطلوب';
                final p = double.tryParse(v);
                if (p == null || p < 0) return 'غير صالح';
                return null;
              },
            ),
          ],
          const SizedBox(height: 12),
          if (lines.isEmpty)
            Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Center(child: Text('لا توجد أصناف بعد — ابحث وأضف منتجات', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary)))),
          for (int i = 0; i < lines.length; i++)
            Stack(children:[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Row(children:[
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                    Text(lines[i].productName, style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('${lines[i].quantity.toStringAsFixed(0)} ${lines[i].unit} × ${Money.withCurrency(lines[i].unitPrice, currency)}',
                        style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary)),
                  ])),
                  Text(Money.withCurrency(lines[i].lineTotal, currency),
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(width: 28),
                ]),
              ),
              Positioned(
                top: 0, left: 0,
                child: IconButton(
                  tooltip: 'إزالة من المسودة',
                  visualDensity: VisualDensity.compact,
                  icon: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: AppColors.errorBg, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 14, color: AppColors.error),
                  ),
                  onPressed: ()=> setState(()=> lines.removeAt(i)),
                ),
              ),
            ]),
          const SizedBox(height: 12),
          TextFormField(controller:down, decoration: const InputDecoration(labelText:'الدفعة الأولى (ل.س)'), keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onChanged:(_)=> setState(()=>{}),
            validator:(v){
              if(v==null||v.isEmpty) return null;
              final d = double.tryParse(v);
              if(d==null||d<0) return 'غير صالح';
              if(d > total) return 'أكبر من الإجمالي';
              return null;
            }),
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(16)), child: Column(children:[
            Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[Text('الإجمالي (${lines.length} صنف)', style: GoogleFonts.cairo(color: Colors.white70)), Flexible(child: Text(Money.withCurrency(total, currency), style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w800)))]),
            const Divider(color: Colors.white24),
            Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[Text('الدفعة الأولى', style: GoogleFonts.cairo(color: Colors.white70)), Text(Money.withCurrency(double.tryParse(down.text) ?? 0, currency), style: GoogleFonts.cairo(color: AppColors.success, fontWeight: FontWeight.w700))]),
            const SizedBox(height:4),
            Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[Text('المتبقي (دين)', style: GoogleFonts.cairo(color: Colors.white70)), Flexible(child: Text(Money.withCurrency(remaining, currency), style: GoogleFonts.cairo(color: AppColors.error, fontWeight: FontWeight.w800)))]),
          ])),
        ],
        const SizedBox(height: 24),
        SizedBox(width:double.infinity, child: ElevatedButton(onPressed: saving ? null : () async {
          if(!_form.currentState!.validate()) return;
          // Final stock guard before save (all lines).
          if (invType == InvoiceType.standard) {
            for (final l in lines) {
              Product? prod;
              try { prod = products.firstWhere((p)=> p.id == l.productId); } catch (_) { prod = null; }
              prod ??= HiveInit.products.get(l.productId);
              if (prod == null) {
                if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('منتج غير موجود: ${l.productName}', style: GoogleFonts.cairo()), backgroundColor: AppColors.error));
                return;
              }
              double oldReserved = 0;
              if (isEdit) {
                for (final o in widget.invoice!.effectiveItems) {
                  if (o.productId == l.productId) oldReserved += o.quantity;
                }
              }
              if (l.quantity > prod.stockQuantity + oldReserved) {
                if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الكمية غير كافية لـ ${l.productName}', style: GoogleFonts.cairo()), backgroundColor: AppColors.error));
                return;
              }
            }
          }
          setState(()=> saving = true);
          try{
            if (invType == InvoiceType.paymentOnly) {
              final amt = double.parse(payAmount.text);
              if (isEdit) {
                await ref.read(invoiceServiceProvider).updateStandard(
                  inv: widget.invoice!, customerName: name.text, customerPhone: phone.text,
                  deliveryAddress: address.text, lines: const [], downPayment: 0,
                  currency: currency, notes: notes.text);
              } else {
                await ref.read(invoiceServiceProvider).createPaymentOnly(
                  customerName: name.text, customerPhone: phone.text,
                  amount: amt, currency: currency, notes: notes.text);
              }
              if(mounted){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ فاتورة الدفعة', style: GoogleFonts.cairo()), backgroundColor: AppColors.success)); Navigator.pop(context); }
            } else {
              if(lines.isEmpty) {
                if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('أضف صنفاً واحداً على الأقل', style: GoogleFonts.cairo()), backgroundColor: AppColors.error));
                return;
              }
              final dp = double.tryParse(down.text) ?? 0;
              if (isEdit) {
                await ref.read(invoiceServiceProvider).updateStandard(
                  inv: widget.invoice!, customerName: name.text, customerPhone: phone.text,
                  deliveryAddress: address.text, lines: lines, downPayment: dp,
                  currency: currency, notes: notes.text);
              } else {
                await ref.read(invoiceServiceProvider).createStandard(
                  customerName: name.text, customerPhone: phone.text,
                  deliveryAddress: address.text, lines: lines, downPayment: dp,
                  currency: currency, notes: notes.text);
              }
              if(mounted){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'تم حفظ التعديل' : 'تم إنشاء الفاتورة بنجاح', style: GoogleFonts.cairo()), backgroundColor: AppColors.success)); Navigator.pop(context); }
            }
          }catch(e){
            if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e', style: GoogleFonts.cairo()), backgroundColor: AppColors.error));
          } finally {
            if (mounted) setState(()=> saving = false);
          }
        }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.white),
            child: Text(saving ? 'جاري الحفظ...' : (isEdit ? 'حفظ التعديل' : (invType == InvoiceType.paymentOnly ? 'حفظ فاتورة الدفعة' : 'إنشاء الفاتورة - خصم تلقائي من المخزون'))))),
      ])),
    );
  }

  Widget _typeOption(InvoiceType t, String title, String sub) {
    final sel = invType == t;
    return InkWell(
      onTap: ()=> setState(()=> invType = t),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.deepNavy : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? AppColors.deepNavy : AppColors.border, width: sel ? 2 : 1),
        ),
        child: Column(children:[
          Text(title, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800, color: sel ? Colors.white : AppColors.textPrimary)),
          Text(sub, style: GoogleFonts.cairo(fontSize: 11, color: sel ? Colors.white70 : AppColors.textSecondary)),
        ]),
      ),
    );
  }
}
