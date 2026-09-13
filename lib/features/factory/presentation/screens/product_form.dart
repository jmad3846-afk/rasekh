import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../factory/data/models/product.dart';
import '../../../factory/logic/factory_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/hive_init.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/money.dart';

class ProductFormSheet extends ConsumerStatefulWidget {
  final Product? product;
  const ProductFormSheet({super.key, this.product});
  @override ConsumerState<ProductFormSheet> createState()=> _S();
}
class _S extends ConsumerState<ProductFormSheet> {
  final _form=GlobalKey<FormState>();
  late TextEditingController name, category, price, stock, unit, safety;
  // Single-currency: fixed SYP.
  final AppCurrency currency = AppCurrency.syp;

  @override void initState(){
    super.initState();
    name=TextEditingController(text: widget.product?.name??'');
    category=TextEditingController(text: widget.product?.category??'');
    price=TextEditingController(text: widget.product != null ? widget.product!.unitPrice.toString() : '');
    stock=TextEditingController(text: widget.product != null ? widget.product!.stockQuantity.toString() : '');
    unit=TextEditingController(text: widget.product?.unit??'قطعة');
    safety=TextEditingController(text: widget.product != null ? widget.product!.safetyStock.toString() : '50');
  }

  @override void dispose() {
    name.dispose(); category.dispose(); price.dispose();
    stock.dispose(); unit.dispose(); safety.dispose();
    super.dispose();
  }

  bool _isDuplicate(String v) {
    final s = v.trim().toLowerCase();
    if (s.isEmpty) return false;
    return HiveInit.products.values.any((e) =>
        e.name.trim().toLowerCase() == s &&
        (widget.product == null || e.id != widget.product!.id));
  }

  @override Widget build(BuildContext context){
    final isEdit=widget.product!=null;
    final amt = double.tryParse(price.text) ?? 0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Form(key:_form, child: SingleChildScrollView(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        Center(child: Container(width:40,height:4,decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height:16),
        Row(children:[
          Expanded(child: Text(isEdit?'تعديل المنتج':'منتج جديد', style: GoogleFonts.cairo(fontSize:18,fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(20)),
            child: Text('ل.س', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.goldDark)),
          ),
        ]),
        const SizedBox(height:8),
        Text('العملة الأساسية: ل.س (ثابتة)',
            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height:12),
        TextFormField(
          controller:name,
          decoration: const InputDecoration(labelText:'اسم المنتج *', hintText:'مثال: سمنت، بلوك'),
          validator:(v) {
            if (v == null || v.trim().isEmpty) return 'مطلوب';
            if (_isDuplicate(v)) {
              return 'هذا المنتج موجود مسبقاً، يرجى التعديل على مخزونه فقط';
            }
            return null;
          },
          onChanged: (_) => setState(() {}),
        ),
        if (_isDuplicate(name.text))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('هذا المنتج موجود مسبقاً، يرجى التعديل على مخزونه فقط',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        const SizedBox(height:12),
        TextFormField(controller:category, decoration: const InputDecoration(labelText:'الفئة *', hintText:'سمنت / حديد / رمل'), validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child: TextFormField(controller:price, decoration: const InputDecoration(labelText:'سعر الوحدة (ل.س) *'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))], onChanged:(_)=> setState(()=>{}), validator:(v)=> v!.isEmpty?'مطلوب':null)),
          const SizedBox(width:12),
          Expanded(child: TextFormField(controller:stock, decoration: const InputDecoration(labelText:'الكمية *'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))], validator:(v)=> v!.isEmpty?'مطلوب':null)),
        ]),
        const SizedBox(height:8),
        if (amt > 0)
          Text('السعر: ${Money.withCurrency(amt, currency)}',
              style: GoogleFonts.cairo(fontSize:13, fontWeight: FontWeight.w800, color: AppColors.deepNavy)),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child: TextFormField(controller:unit, decoration: const InputDecoration(labelText:'الوحدة', hintText:'طن، قطعة، م3'))),
          const SizedBox(width:12),
          Expanded(child: TextFormField(controller:safety, decoration: const InputDecoration(labelText:'حد المخزون الأدنى'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))])),
        ]),
        const SizedBox(height:20),
        SizedBox(width:double.infinity, child: ElevatedButton(onPressed: () async {
          if(!_form.currentState!.validate()) return;
          if (!isEdit && _isDuplicate(name.text)) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text('تنبيه', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
                content: Text('هذا المنتج موجود مسبقاً، يرجى التعديل على مخزونه فقط',
                    style: GoogleFonts.cairo()),
                actions: [
                  TextButton(onPressed: ()=> Navigator.pop(context), child: Text('حسناً', style: GoogleFonts.cairo())),
                ],
              ),
            );
            return;
          }
          try {
            final p = widget.product ?? Product(name:name.text.trim(), category:category.text, unitPrice: double.parse(price.text), stockQuantity: double.parse(stock.text), unit: unit.text, currency: AppCurrency.syp, safetyStock: double.tryParse(safety.text) ?? 50);
            if(isEdit){
              final oldPrice = widget.product!.unitPrice;
              p.name=name.text.trim(); p.category=category.text; p.unitPrice=double.parse(price.text);
              p.stockQuantity=double.parse(stock.text); p.unit=unit.text;
              p.currency=AppCurrency.syp; p.safetyStock=double.tryParse(safety.text) ?? 50;
              await ref.read(productServiceProvider).update(p, oldUnitPrice: oldPrice);
            }
            else { await ref.read(productServiceProvider).add(p); }
            if(mounted) Navigator.pop(context);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('$e'.replaceAll('Exception: ', ''),
                      style: GoogleFonts.cairo()),
                  backgroundColor: AppColors.error));
            }
          }
        }, child: Text(isEdit?'حفظ التعديل':'إضافة المنتج'))),
      ])))),
    );
  }
}
