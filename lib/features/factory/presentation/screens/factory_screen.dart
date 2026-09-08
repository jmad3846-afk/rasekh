import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/widgets.dart';
import '../../../../core/utils/money.dart';
import '../../logic/factory_providers.dart';
import '../../data/models/product.dart';
import 'product_form.dart';
import 'invoice_form.dart';

class FactoryScreen extends ConsumerStatefulWidget {
  const FactoryScreen({super.key});
  @override ConsumerState<FactoryScreen> createState()=> _State();
}
class _State extends ConsumerState<FactoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override void initState(){ super.initState(); _tab=TabController(length:2, vsync:this); }
  @override Widget build(BuildContext context){
    final productsAsync = ref.watch(productsProvider);
    final invoicesAsync = ref.watch(invoicesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('قسم المعمل', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        bottom: TabBar(controller:_tab, labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: AppColors.gold, tabs:[
          Tab(text:'المنتجات', icon: Icon(Icons.inventory_2)),
          Tab(text:'الفواتير', icon: Icon(Icons.receipt_long)),
        ]),
      ),
      body: TabBarView(controller:_tab, children:[
        // PRODUCTS TAB
        productsAsync.when(
          data:(products)=> _productsList(products),
          loading: ()=> const Center(child: CircularProgressIndicator()),
          error:(e,s)=> Center(child: Text('$e')),
        ),
        invoicesAsync.when(
          data:(invoices)=> _invoicesList(invoices),
          loading: ()=> const Center(child: CircularProgressIndicator()),
          error:(e,s)=> Center(child: Text('$e')),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold, foregroundColor: Colors.white,
        onPressed: ()=> _tab.index==0
            ? showModalBottomSheet(context:context, isScrollControlled:true, builder:(_)=> const ProductFormSheet())
            : Navigator.push(context, MaterialPageRoute(builder:(_)=> const InvoiceFormScreen())),
        icon: const Icon(Icons.add), label: Text(_tab.index==0?'منتج جديد':'فاتورة جديدة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _productsList(List<Product> products){
    if(products.isEmpty) return Center(child: Column(mainAxisAlignment:MainAxisAlignment.center, children:[Icon(Icons.inventory_2_outlined,size:64,color: Colors.grey[300]), const SizedBox(height:12), Text('لا توجد منتجات', style: GoogleFonts.cairo(color: AppColors.textSecondary))]));
    return ListView.separated(
      padding: const EdgeInsets.all(16), itemCount: products.length,
      separatorBuilder: (_,__)=> const SizedBox(height:12),
      itemBuilder: (_,i){
        final p=products[i];
        final low = p.stockQuantity < 50;
        return GlassCard(child: Row(children:[
          Container(width:56,height:56,decoration:BoxDecoration(color: low?AppColors.errorBg:AppColors.goldLight, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.category, color: low?AppColors.error:AppColors.goldDark)),
          const SizedBox(width:12),
          Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
            Text(p.name, style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
            Text('${p.category} • ${Money.format(p.unitPrice)}/${p.unit}', style: GoogleFonts.cairo(fontSize:11,color: AppColors.textSecondary)),
            const SizedBox(height:4),
            Row(children:[
              Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:2), decoration: BoxDecoration(color: low?AppColors.errorBg:AppColors.successBg, borderRadius: BorderRadius.circular(20)), child: Text('${p.stockQuantity.toStringAsFixed(0)} متوفر', style: GoogleFonts.cairo(fontSize:11,color: low?AppColors.error:AppColors.success, fontWeight: FontWeight.w700))),
            ])
          ])),
          PopupMenuButton(onSelected: (v) async {
            if(v=='edit') showModalBottomSheet(context:context, isScrollControlled:true, builder:(_)=> ProductFormSheet(product:p));
            if(v=='delete'){ await ref.read(productServiceProvider).delete(p); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف ${p.name}', style: GoogleFonts.cairo()))); }
          }, itemBuilder: (_)=> [
            PopupMenuItem(value:'edit', child: Text('تعديل', style: GoogleFonts.cairo())),
            PopupMenuItem(value:'delete', child: Text('حذف', style: GoogleFonts.cairo(color: AppColors.error))),
          ]),
        ]));
      },
    );
  }

  Widget _invoicesList(invoices){
    if(invoices.isEmpty) return Center(child: Text('لا توجد فواتير', style: GoogleFonts.cairo(color: AppColors.textSecondary)));
    return ListView.separated(
      padding: const EdgeInsets.all(16), itemCount: invoices.length,
      separatorBuilder: (_,__)=> const SizedBox(height:12),
      itemBuilder: (_,i){
        final inv=invoices[i];
        return GlassCard(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Row(children:[
            Text(inv.invoiceNumber, style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize:13)),
            const Spacer(),
            Text(inv.createdAt.toString().substring(0,10), style: GoogleFonts.cairo(fontSize:11,color: AppColors.textSecondary)),
          ]),
          const Divider(),
          Row(children:[
            Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              Text(inv.customerName, style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              Text('${inv.customerPhone} • ${inv.deliveryAddress}', style: GoogleFonts.cairo(fontSize:11,color: AppColors.textSecondary)),
              const SizedBox(height:4),
              Text('${inv.productName} x${inv.quantity} @ ${Money.format(inv.unitPrice)}', style: GoogleFonts.cairo(fontSize:11)),
            ])),
            Column(crossAxisAlignment:CrossAxisAlignment.end, children:[
              Text(Money.format(inv.totalPrice), style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
              Text('دفعة: ${Money.format(inv.downPayment)}', style: GoogleFonts.cairo(fontSize:11,color: AppColors.success)),
              Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:2), decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(20)), child: Text('متبقي ${Money.format(inv.remainingBalance)}', style: GoogleFonts.cairo(fontSize:11,color: AppColors.error, fontWeight: FontWeight.w700))),
            ])
          ])
        ]));
      },
    );
  }
}
