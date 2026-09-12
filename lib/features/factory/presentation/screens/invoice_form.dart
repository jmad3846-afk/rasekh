import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/finance_widgets.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/database/hive_init.dart';
import '../../logic/factory_providers.dart';
import '../../data/models/invoice.dart';
import '../../data/models/product.dart';

/// Req #7/#8/#9: dual-type invoices, client auto-fill, inline item removal.
class InvoiceFormScreen extends ConsumerStatefulWidget {
  final Invoice? invoice; // null = create
  const InvoiceFormScreen({super.key, this.invoice});
  @override ConsumerState<InvoiceFormScreen> createState()=> _S();
}
class _S extends ConsumerState<InvoiceFormScreen> {
  final _form=GlobalKey<FormState>();
  late TextEditingController name, phone, address, qty, down, notes, payAmount;
  Product? selected;
  AppCurrency currency = AppCurrency.syp;
  InvoiceType invType = InvoiceType.standard;
  List<InvoiceItem> lines = [];
  bool saving = false;

  bool get isEdit => widget.invoice != null;

  double get total => lines.fold(0.0, (s, e) => s + e.lineTotal);
  double get remaining => total - (double.tryParse(down.text) ?? 0);

  @override void initState() {
    super.initState();
    final inv = widget.invoice;
    name = TextEditingController(text: inv?.customerName ?? '');
    phone = TextEditingController(text: inv?.customerPhone ?? '');
    address = TextEditingController(text: inv?.deliveryAddress ?? '');
    qty = TextEditingController(text: '1');
    down = TextEditingController(text: inv != null && !inv.isPaymentOnly ? inv.downPayment.toString() : '');
    notes = TextEditingController(text: inv?.notes ?? '');
    payAmount = TextEditingController(text: inv != null && inv.isPaymentOnly ? inv.totalPrice.toString() : '');
    currency = inv?.currency ?? AppCurrency.syp;
    invType = inv?.type ?? InvoiceType.standard;
    if (inv != null && inv.items.isNotEmpty) {
      lines = inv.items.map((e)=> InvoiceItem(
        productId: e.productId, productName: e.productName,
        quantity: e.quantity, unitPrice: e.unitPrice, unit: e.unit)).toList();
    }
  }

  @override void dispose() {
    name.dispose(); phone.dispose(); address.dispose();
    qty.dispose(); down.dispose(); notes.dispose(); payAmount.dispose();
    super.dispose();
  }

  List<Product> _matchProducts(List<Product> all, String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return all.take(5).toList();
    return all.where((p)=> p.name.toLowerCase().contains(s) || p.category.toLowerCase().contains(s)).take(5).toList();
  }

  @override Widget build(BuildContext context){
    final products = ref.watch(productsProvider).value ?? [];
    final customers = HiveInit.customers.values.toList();
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'تعديل الفاتورة ${widget.invoice!.invoiceNumber}' : 'فاتورة جديدة', style: GoogleFonts.cairo(fontWeight: FontWeight.w800))),
      body: Form(key:_form, child: ListView(padding: const EdgeInsets.all(16), children:[
        // ── Req #9: type selector ──
        Text('نوع الفاتورة *', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children:[
          Expanded(child: _typeOption(InvoiceType.standard, 'فاتورة عادية', 'منتجات + حسابات')),
          const SizedBox(width: 12),
          Expanded(child: _typeOption(InvoiceType.paymentOnly, 'فاتورة دفعة', 'تسوية مالية فقط')),
        ]),
        const SizedBox(height: 16),
        Text('عملة الفاتورة *', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        CurrencySelector(value: currency, onChanged: (c)=> setState(()=> currency = c)),
        const SizedBox(height: 16),
        Text('بيانات الزبون', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        // ── Req #7: smart client auto-fill ──
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
            // Keep external controller in sync.
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
        TextFormField(controller:phone, decoration: const InputDecoration(labelText:'رقم الهاتف *', prefixIcon: Icon(Icons.phone_outlined)), keyboardType: TextInputType.phone, validator:(v)=> v!.isEmpty?'مطلوب':null),
        if (invType == InvoiceType.standard) ...[
          const SizedBox(height:12),
          TextFormField(controller:address, decoration: const InputDecoration(labelText:'عنوان التوصيل *', prefixIcon: Icon(Icons.location_on_outlined)), validator:(v)=> v!.isEmpty?'مطلوب':null),
        ],
        const SizedBox(height: 12),
        TextFormField(controller:notes, decoration: const InputDecoration(labelText:'ملاحظات', prefixIcon: Icon(Icons.note_outlined)), maxLines: 2),
        const SizedBox(height: 20),

        if (invType == InvoiceType.paymentOnly) ...[
          // ── Payment-only: amount only, no products ──
          Text('مبلغ الدفعة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextFormField(controller:payAmount, decoration: InputDecoration(labelText:'المبلغ (${currency.symbol}) *'), keyboardType: TextInputType.number,
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
          // ── Standard: multi-item draft with inline removal (Req #8) ──
          Text('المنتجات', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children:[
            Expanded(
              flex: 3,
              child: Autocomplete<Product>(
                optionsBuilder: (v) => _matchProducts(products, v.text),
                displayStringForOption: (p)=> p.name,
                onSelected: (p)=> setState(()=> selected = p),
                fieldViewBuilder: (ctx, ctrl, focus, onSubmit) => TextFormField(
                  controller: ctrl, focusNode: focus,
                  decoration: const InputDecoration(labelText: 'ابحث عن منتج *', prefixIcon: Icon(Icons.inventory_2_outlined), isDense: true),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(controller:qty, decoration: const InputDecoration(labelText: 'الكمية', isDense: true), keyboardType: TextInputType.number),
            ),
            IconButton(
              tooltip: 'إضافة للمسودة',
              onPressed: () {
                if (selected == null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('اختر منتجاً أولاً', style: GoogleFonts.cairo())));
                  return;
                }
                final q = double.tryParse(qty.text) ?? 0;
                if (q <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('أدخل كمية صحيحة', style: GoogleFonts.cairo())));
                  return;
                }
                setState(()=> lines.add(InvoiceItem(
                  productId: selected!.id, productName: selected!.name,
                  quantity: q, unitPrice: selected!.unitPrice, unit: selected!.unit)));
                qty.text = '1';
              },
              icon: const Icon(Icons.add_circle, color: AppColors.deepNavy, size: 28),
            ),
          ]),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${selected!.name} • ${Money.withCurrency(selected!.unitPrice, selected!.currency)}/${selected!.unit} • متوفر ${selected!.stockQuantity.toStringAsFixed(0)}',
                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary)),
            ),
          const SizedBox(height: 12),
          // Draft list with corner delete icon (Req #8).
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
          TextFormField(controller:down, decoration: const InputDecoration(labelText:'الدفعة الأولى'), keyboardType: TextInputType.number, onChanged:(_)=> setState(()=>{}),
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
            Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[Text('الدفعة', style: GoogleFonts.cairo(color: Colors.white70)), Text(Money.withCurrency(double.tryParse(down.text) ?? 0, currency), style: GoogleFonts.cairo(color: AppColors.success, fontWeight: FontWeight.w700))]),
            const SizedBox(height:4),
            Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[Text('المتبقي (دين)', style: GoogleFonts.cairo(color: Colors.white70)), Flexible(child: Text(Money.withCurrency(remaining, currency), style: GoogleFonts.cairo(color: AppColors.error, fontWeight: FontWeight.w800)))]),
          ])),
        ],
        const SizedBox(height: 24),
        SizedBox(width:double.infinity, child: ElevatedButton(onPressed: saving ? null : () async {
          if(!_form.currentState!.validate()) return;
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
