import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/widgets.dart';
import '../../../core/utils/money.dart';
import '../../factory/logic/factory_providers.dart';
import '../../projects/logic/project_providers.dart';
import '../../finance/logic/finance_engine.dart';
import '../../../core/database/hive_init.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref){
    final products = ref.watch(productsProvider).value ?? [];
    final invoices = ref.watch(invoicesProvider).value ?? [];
    final projects = ref.watch(projectsProvider).value ?? [];
    final totalDebt = FinanceEngine.totalClientDebt();
    final lowStock = products.where((p)=> p.stockQuantity < 50).length;
    final pendingProcs = HiveInit.procedures.values.where((p)=> p.status.name=='pending').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          Text('مرحباً، المالك', style: GoogleFonts.cairo(fontSize:13,color:Colors.white70)),
          Text('لوحة التحكم', style: GoogleFonts.cairo(fontSize:19,fontWeight:FontWeight.w800)),
        ]),
        actions: [IconButton(onPressed: (){}, icon: const Icon(Icons.notifications_none, color: Colors.white)), const SizedBox(width:8)],
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.navyGradient)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children:[
        // Hero finance card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: AppColors.navyGradient, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
            Row(children:[
              Text('إجمالي الديون المستحقة', style: GoogleFonts.cairo(color: Colors.white70, fontSize:13)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal:10,vertical:4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Row(children:[const Icon(Icons.shield_outlined, color: Colors.white, size:14), const SizedBox(width:4), Text('محمي offline', style: GoogleFonts.cairo(color: Colors.white, fontSize:11))])),
            ]),
            const SizedBox(height:8),
            Text(Money.format(totalDebt), style: GoogleFonts.cairo(color: Colors.white, fontSize:28, fontWeight: FontWeight.w900)),
            const SizedBox(height:12),
            Row(children:[
              _miniStat(Icons.receipt_long, '${invoices.length} فاتورة'),
              const SizedBox(width:12),
              _miniStat(Icons.business, '${projects.length} مشروع'),
              const SizedBox(width:12),
              _miniStat(Icons.inventory_2_outlined, '${products.length} منتج'),
            ]),
          ]),
        ),
        const SizedBox(height:16),
        GridView.count(crossAxisCount:2, shrinkWrap:true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing:12, crossAxisSpacing:12, childAspectRatio:1.35, children:[
          FinanceSummaryCard(title:'ديون العملاء', amount: Money.format(totalDebt), icon: Icons.people_alt_outlined, color: AppColors.error, subtitle:'متبقي فواتير + اجرائيات مكتملة'),
          FinanceSummaryCard(title:'مخزون منخفض', amount:'$lowStock منتج', icon: Icons.warning_amber_rounded, color: AppColors.warning, subtitle:'أقل من 50 وحدة'),
          FinanceSummaryCard(title:'إجرائيات معلقة', amount:'$pendingProcs', icon: Icons.pending_actions, color: AppColors.goldDark, subtitle:'قيد الانتظار'),
          FinanceSummaryCard(title:'إجمالي المبيعات', amount: Money.format(invoices.fold(0.0,(s,i)=> s+i.totalPrice)), icon: Icons.trending_up, color: AppColors.success, subtitle:'كل الفواتير'),
        ]),
        const SizedBox(height:20),
        const SectionHeader(title:'آخر الفواتير'),
        const SizedBox(height:8),
        if(invoices.isEmpty) GlassCard(child: Center(child: Text('لا توجد فواتير بعد', style: GoogleFonts.cairo(color: AppColors.textSecondary)))),
        for(final inv in invoices.take(3))
          GlassCard(padding: const EdgeInsets.all(14), child: Row(children:[
            Container(width:44,height:44,decoration:BoxDecoration(color: AppColors.goldLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.receipt, color: AppColors.goldDark)),
            const SizedBox(width:12),
            Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              Text(inv.invoiceNumber, style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize:13)),
              Text('${inv.customerName} • ${inv.productName} x${inv.quantity}', style: GoogleFonts.cairo(fontSize:11,color:AppColors.textSecondary)),
            ])),
            Column(crossAxisAlignment:CrossAxisAlignment.end, children:[
              Text(Money.format(inv.totalPrice), style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize:13)),
              Text('متبقي ${Money.format(inv.remainingBalance)}', style: GoogleFonts.cairo(fontSize:11,color: AppColors.error)),
            ])
          ])),
        const SizedBox(height:16),
        const SectionHeader(title:'المشاريع النشطة'),
        const SizedBox(height:8),
        if(projects.isEmpty) GlassCard(child: Center(child: Text('لا توجد مشاريع', style: GoogleFonts.cairo(color: AppColors.textSecondary)))),
        for(final pr in projects.take(2))
          GlassCard(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
            Row(children:[
              Expanded(child: Text(pr.location, style: GoogleFonts.cairo(fontWeight: FontWeight.w800))),
              StatusBadge(label: pr.completedCost>0?'نشط':'جديد', isCompleted: pr.completedCost>0),
            ]),
            Text('${pr.clientName} • ${pr.totalArea} م²', style: GoogleFonts.cairo(fontSize:12,color: AppColors.textSecondary)),
            const SizedBox(height:8),
            LinearProgressIndicator(value: pr.totalCost==0?0: pr.completedCost/pr.totalCost, color: AppColors.gold, backgroundColor: AppColors.divider),
            const SizedBox(height:6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
              Text('الإجمالي ${Money.format(pr.totalCost)}', style: GoogleFonts.cairo(fontSize:11)),
              Text('مكتمل ${Money.format(pr.completedCost)}', style: GoogleFonts.cairo(fontSize:11,color: AppColors.success)),
            ])
          ])),
      ]),
    );
  }
  Widget _miniStat(IconData icon, String label){
    return Container(padding: const EdgeInsets.symmetric(horizontal:10,vertical:6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(20)), child: Row(children:[Icon(icon,color: Colors.white,size:14), const SizedBox(width:6), Text(label, style: GoogleFonts.cairo(color: Colors.white, fontSize:11, fontWeight: FontWeight.w600))] ));
  }
}
