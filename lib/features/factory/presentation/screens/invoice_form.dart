import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/money.dart';
import '../../logic/factory_providers.dart';
import '../../data/models/invoice.dart';
import '../../data/models/product.dart';

class InvoiceFormScreen extends ConsumerStatefulWidget {
  final Invoice? invoice; // null = create
  const InvoiceFormScreen({super.key, this.invoice});
  @override ConsumerState<InvoiceFormScreen> createState()=> _S();
}
class _S extends ConsumerState<InvoiceFormScreen> {
  final _form=GlobalKey<FormState>();
  late TextEditingController name, phone, address, qty, down;
  Product? selected;
  AppCurrency currency = AppCurrency.syp;
  bool saving = false;

  bool get isEdit => widget.invoice != null;

  double get total => selected==null ? 0 : (double.tryParse(qty.text)??0)*selected!.unitPrice;
  double get remaining => total - (double.tryParse(down.text)??0);

  @override void initState() {
    super.initState();
    final inv = widget.invoice;
    name = TextEditingController(text: inv?.customerName ?? '');
    phone = TextEditingController(text: inv?.customerPhone ?? '');
    address = TextEditingController(text: inv?.deliveryAddress ?? '');
    qty = TextEditingController(text: inv != null ? inv.quantity.toString() : '1');
    down = TextEditingController(text: inv != null ? inv.downPayment.toString() : '');
    currency = inv?.currency ?? AppCurrency.syp;
  }

  @override Widget build(BuildContext context){
    final products = ref.watch(productsProvider).value ?? [];
    // Pre-select product in edit mode once.
    if (isEdit && selected == null && products.isNotEmpty) {
      try {
        selected = products.firstWhere((p) => p.id == widget.invoice!.productId);
      } catch (_) {
        selected = null;
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'تعديل الفاتورة ${widget.invoice!.invoiceNumber}' : 'فاتورة جديدة', style: GoogleFonts.cairo(fontWeight: FontWeight.w800))),
      body: Form(key:_form, child: ListView(padding: const EdgeInsets.all(16), children:[
        Text('عملة الفاتورة *', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        const SizedBox(height:8),
        Row(children:[
          Expanded(child: _currencyOption(AppCurrency.syp)),
          const SizedBox(width:12),
          Expanded(child: _currencyOption(AppCurrency.usd)),
        ]),
        const SizedBox(height:16),
        Text('بيانات الزبون', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        const SizedBox(height:8),
        TextFormField(controller:name, decoration: const InputDecoration(labelText:'اسم الزبون *', prefixIcon: Icon(Icons.person_outline)), validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:12),
        TextFormField(controller:phone, decoration: const InputDecoration(labelText:'رقم الهاتف *', prefixIcon: Icon(Icons.phone_outlined)), keyboardType: TextInputType.phone, validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:12),
        TextFormField(controller:address, decoration: const InputDecoration(labelText:'عنوان التوصيل *', prefixIcon: Icon(Icons.location_on_outlined)), validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:20),
        Text('المنتج والكمية', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        const SizedBox(height:8),
        DropdownButtonFormField<Product>(value:selected, decoration: const InputDecoration(labelText:'اختر المنتج *', prefixIcon: Icon(Icons.inventory_2_outlined)), items: products.map((p)=> DropdownMenuItem(value:p, child: Text('${p.name} - ${Money.format(p.unitPrice)} (متوفر ${p.stockQuantity.toStringAsFixed(0)})', style: GoogleFonts.cairo(fontSize:13)))).toList(), onChanged:(v)=> setState(()=> selected=v), validator:(v)=> v==null?'اختر منتج':null),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child: TextFormField(controller:qty, decoration: const InputDecoration(labelText:'الكمية *'), keyboardType: TextInputType.number, onChanged:(_)=> setState(()=>{}), validator:(v)=> v!.isEmpty?'مطلوب':null)),
          const SizedBox(width:12),
          Expanded(child: TextFormField(controller:down, decoration: const InputDecoration(labelText:'الدفعة الأولى *'), keyboardType: TextInputType.number, onChanged:(_)=> setState(()=>{}), validator:(v){
            if(v==null||v.isEmpty) return 'مطلوبة';
            if(double.tryParse(v)==null||double.parse(v)<=0) return '>0 مطلوب';
            if(double.parse(v) > total) return 'أكبر من الإجمالي';
            return null;
          })),
        ]),
        const SizedBox(height:16),
        if(selected!=null) Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(16)), child: Column(children:[
          Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[Text('الإجمالي', style: GoogleFonts.cairo(color: Colors.white70)), Flexible(child: Text(Money.withCurrency(total, currency), style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w800)))]),
          const Divider(color: Colors.white24),
          Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[Text('الدفعة', style: GoogleFonts.cairo(color: Colors.white70)), Text(Money.withCurrency(double.tryParse(down.text)??0, currency), style: GoogleFonts.cairo(color: AppColors.success, fontWeight: FontWeight.w700))]),
          const SizedBox(height:4),
          Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[Text('المتبقي (دين)', style: GoogleFonts.cairo(color: Colors.white70)), Flexible(child: Text(Money.withCurrency(remaining, currency), style: GoogleFonts.cairo(color: AppColors.error, fontWeight: FontWeight.w800)))]),
          const SizedBox(height:8),
          Text(isEdit ? 'سيتم تعديل المخزون بالفرق وتحديث ذمة الزبون مرة واحدة' : 'سيتم خصم الكمية من المخزون وإضافة المتبقي لمالية الزبون تلقائياً', style: GoogleFonts.cairo(color: Colors.white54, fontSize:11)),
        ])),
        const SizedBox(height:24),
        SizedBox(width:double.infinity, child: ElevatedButton(onPressed: saving ? null : () async {
          if(!_form.currentState!.validate()) return;
          if(selected==null) return;
          setState(()=> saving = true);
          try{
            if (isEdit) {
              await ref.read(invoiceServiceProvider).update(
                inv: widget.invoice!,
                customerName: name.text, customerPhone: phone.text, deliveryAddress: address.text,
                product: selected!, quantity: double.parse(qty.text), downPayment: double.parse(down.text),
                currency: currency,
              );
              if(mounted){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ التعديل وتحديث المخزون والمالية', style: GoogleFonts.cairo()), backgroundColor: AppColors.success)); Navigator.pop(context); }
            } else {
              await ref.read(invoiceServiceProvider).create(customerName:name.text, customerPhone:phone.text, deliveryAddress:address.text, product:selected!, quantity: double.parse(qty.text), downPayment: double.parse(down.text), currency: currency);
              if(mounted){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إنشاء الفاتورة بنجاح', style: GoogleFonts.cairo()), backgroundColor: AppColors.success)); Navigator.pop(context); }
            }
          }catch(e){
            if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e', style: GoogleFonts.cairo()), backgroundColor: AppColors.error));
          } finally {
            if (mounted) setState(()=> saving = false);
          }
        }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.white), child: Text(saving ? 'جاري الحفظ...' : (isEdit ? 'حفظ التعديل' : 'إنشاء الفاتورة - خصم تلقائي من المخزون')))),
      ])),
    );
  }

  Widget _currencyOption(AppCurrency c) {
    final sel = currency == c;
    final isUsd = c == AppCurrency.usd;
    return InkWell(
      onTap: ()=> setState(()=> currency = c),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical:10),
        decoration: BoxDecoration(
          color: sel ? (isUsd ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7)) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? (isUsd ? AppColors.success : AppColors.goldDark) : AppColors.border, width: sel ? 2 : 1),
        ),
        child: Column(children:[
          Text(isUsd ? '\$ USD' : 'ل.س SYP', style: GoogleFonts.cairo(fontSize:14, fontWeight: FontWeight.w800, color: isUsd ? AppColors.success : AppColors.goldDark)),
        ]),
      ),
    );
  }
}
