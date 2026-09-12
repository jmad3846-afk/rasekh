import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../factory/data/models/product.dart';
import '../../../factory/logic/factory_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/finance_widgets.dart';
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
  late AppCurrency currency;

  @override void initState(){
    super.initState();
    name=TextEditingController(text: widget.product?.name??'');
    category=TextEditingController(text: widget.product?.category??'');
    price=TextEditingController(text: widget.product != null ? widget.product!.unitPrice.toString() : '');
    stock=TextEditingController(text: widget.product != null ? widget.product!.stockQuantity.toString() : '');
    unit=TextEditingController(text: widget.product?.unit??'قطعة');
    safety=TextEditingController(text: widget.product != null ? widget.product!.safetyStock.toString() : '50');
    currency = widget.product?.currency ?? AppCurrency.syp;
  }

  @override void dispose() {
    name.dispose(); category.dispose(); price.dispose();
    stock.dispose(); unit.dispose(); safety.dispose();
    super.dispose();
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
          CurrencyBadge(currency),
        ]),
        const SizedBox(height:16),
        Text('عملة المنتج * (إلزامي)', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize:13)),
        const SizedBox(height:8),
        CurrencySelector(value: currency, onChanged: (c)=> setState(()=> currency = c)),
        const SizedBox(height:12),
        TextFormField(controller:name, decoration: const InputDecoration(labelText:'اسم المنتج *', hintText:'مثال: سمنت، بلوك'), validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:12),
        TextFormField(controller:category, decoration: const InputDecoration(labelText:'الفئة *', hintText:'سمنت / حديد / رمل'), validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child: TextFormField(controller:price, decoration: InputDecoration(labelText:'سعر الوحدة (${currency.symbol}) *'), keyboardType: TextInputType.number, onChanged:(_)=> setState(()=>{}), validator:(v)=> v!.isEmpty?'مطلوب':null)),
          const SizedBox(width:12),
          Expanded(child: TextFormField(controller:stock, decoration: const InputDecoration(labelText:'الكمية *'), keyboardType: TextInputType.number, validator:(v)=> v!.isEmpty?'مطلوب':null)),
        ]),
        const SizedBox(height:8),
        if (amt > 0)
          Text('السعر: ${Money.withCurrency(amt, currency)}',
              style: GoogleFonts.cairo(fontSize:13, fontWeight: FontWeight.w800, color: AppColors.deepNavy)),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child: TextFormField(controller:unit, decoration: const InputDecoration(labelText:'الوحدة', hintText:'طن، قطعة، م3'))),
          const SizedBox(width:12),
          Expanded(child: TextFormField(controller:safety, decoration: const InputDecoration(labelText:'حد المخزون الأدنى'), keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height:20),
        SizedBox(width:double.infinity, child: ElevatedButton(onPressed: () async {
          if(!_form.currentState!.validate()) return;
          final p = widget.product ?? Product(name:name.text, category:category.text, unitPrice: double.parse(price.text), stockQuantity: double.parse(stock.text), unit: unit.text, currency: currency, safetyStock: double.tryParse(safety.text) ?? 50);
          if(isEdit){
            p.name=name.text; p.category=category.text; p.unitPrice=double.parse(price.text);
            p.stockQuantity=double.parse(stock.text); p.unit=unit.text;
            p.currency=currency; p.safetyStock=double.tryParse(safety.text) ?? 50;
            await p.save();
          }
          else { await ref.read(productServiceProvider).add(p); }
          if(mounted) Navigator.pop(context);
        }, child: Text(isEdit?'حفظ التعديل':'إضافة المنتج'))),
      ])))),
    );
  }
}
