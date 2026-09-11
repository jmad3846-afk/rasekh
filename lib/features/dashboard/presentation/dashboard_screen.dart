import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/widgets.dart';
import '../../../core/utils/currency.dart';
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
    // Reactive: watch transactions so debt KPIs update live.
    ref.watch(transactionsProvider);

    final debtUsd = FinanceEngine.totalClientDebt(currency: AppCurrency.usd);
    final debtSyp = FinanceEngine.totalClientDebt(currency: AppCurrency.syp);
    final salesUsd = FinanceEngine.totalSales(currency: AppCurrency.usd);
    final salesSyp = FinanceEngine.totalSales(currency: AppCurrency.syp);

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
      body: LayoutBuilder(builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 380;
        final crossCount = constraints.maxWidth >= 600 ? 4 : 2;
        return ListView(padding: const EdgeInsets.all(16), children:[
          // Hero finance card — responsive, no fixed widths.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: AppColors.navyGradient, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              Row(children:[
                Flexible(child: Text('إجمالي الديون المستحقة', style: GoogleFonts.cairo(color: Colors.white70, fontSize:13))),
                const SizedBox(width:8),
                Container(padding: const EdgeInsets.symmetric(horizontal:10,vertical:4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children:[const Icon(Icons.shield_outlined, color: Colors.white, size:14), const SizedBox(width:4), Text('محمي offline', style: GoogleFonts.cairo(color: Colors.white, fontSize:11))])),
              ]),
              const SizedBox(height:8),
              // Split hero by currency to avoid SYP+USD confusion.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(children:[
                  Text(Money.withCurrency(debtSyp, AppCurrency.syp), style: GoogleFonts.cairo(color: Colors.white, fontSize:24, fontWeight: FontWeight.w900)),
                  const SizedBox(width:12),
                  Text('+', style: GoogleFonts.cairo(color: Colors.white54, fontSize:18)),
                  const SizedBox(width:12),
                  Text(Money.withCurrency(debtUsd, AppCurrency.usd), style: GoogleFonts.cairo(color: const Color(0xFFFDE68A), fontSize:24, fontWeight: FontWeight.w900)),
                ]),
              ),
              const SizedBox(height:12),
              // Wrap stats so they never overflow on small phones.
              Wrap(spacing:8, runSpacing:8, children:[
                _miniStat(Icons.receipt_long, '${invoices.length} فاتورة'),
                _miniStat(Icons.business, '${projects.length} مشروع'),
                _miniStat(Icons.inventory_2_outlined, '${products.length} منتج'),
                _miniStat(Icons.pending_actions, '$pendingProcs معلق'),
              ]),
            ]),
          ),
          const SizedBox(height:16),
          Text('الديون والمبيعات حسب العملة', style: GoogleFonts.cairo(fontSize:15, fontWeight: FontWeight.w800)),
          const SizedBox(height:8),
          GridView.count(
            crossAxisCount: crossCount,
            shrinkWrap:true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing:12, crossAxisSpacing:12,
            childAspectRatio: isNarrow ? 1.1 : 1.25,
            children:[
              FinanceSummaryCard(title:'ديون العملاء (\$)', amount: Money.withCurrency(debtUsd, AppCurrency.usd), icon: Icons.attach_money, color: AppColors.error, subtitle:'ذمم دولار'),
              FinanceSummaryCard(title:'ديون العملاء (ل.س)', amount: Money.withCurrency(debtSyp, AppCurrency.syp), icon: Icons.people_alt_outlined, color: const Color(0xFFB45309), subtitle:'ذمم ليرة'),
              FinanceSummaryCard(title:'إجمالي المبيعات (\$)', amount: Money.withCurrency(salesUsd, AppCurrency.usd), icon: Icons.trending_up, color: AppColors.success, subtitle:'فواتير + اجرائيات \$'),
              FinanceSummaryCard(title:'إجمالي المبيعات (ل.س)', amount: Money.withCurrency(salesSyp, AppCurrency.syp), icon: Icons.show_chart, color: AppColors.deepNavy, subtitle:'فواتير + اجرائيات ل.س'),
            ],
          ),
          const SizedBox(height:12),
          GridView.count(
            crossAxisCount: crossCount,
            shrinkWrap:true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing:12, crossAxisSpacing:12,
            childAspectRatio: isNarrow ? 1.1 : 1.35,
            children:[
              FinanceSummaryCard(title:'مخزون منخفض', amount:'$lowStock منتج', icon: Icons.warning_amber_rounded, color: AppColors.warning, subtitle:'أقل من 50 وحدة'),
              FinanceSummaryCard(title:'إجرائيات معلقة', amount:'$pendingProcs', icon: Icons.pending_actions, color: AppColors.goldDark, subtitle:'قيد الانتظار'),
            ],
          ),
          const SizedBox(height:20),
          const SectionHeader(title:'آخر الفواتير'),
          const SizedBox(height:8),
          if(invoices.isEmpty) GlassCard(child: Center(child: Text('لا توجد فواتير بعد', style: GoogleFonts.cairo(color: AppColors.textSecondary)))),
          for(final inv in invoices.take(3))
            GlassCard(padding: const EdgeInsets.all(14), child: Row(children:[
              Container(width:44,height:44,decoration:BoxDecoration(color: AppColors.goldLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.receipt, color: AppColors.goldDark)),
              const SizedBox(width:12),
              Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
                Row(children:[
                  Flexible(child: Text(inv.invoiceNumber, style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize:13))),
                  const SizedBox(width:6),
                  Text(inv.currency == AppCurrency.usd ? '\$' : 'ل.س', style: GoogleFonts.cairo(fontSize:11, fontWeight: FontWeight.w800, color: inv.currency == AppCurrency.usd ? AppColors.success : AppColors.goldDark)),
                ]),
                Text('${inv.customerName} • ${inv.productName} x${inv.quantity}', style: GoogleFonts.cairo(fontSize:11,color:AppColors.textSecondary), overflow: TextOverflow.ellipsis),
              ])),
              const SizedBox(width:8),
              Column(crossAxisAlignment:CrossAxisAlignment.end, children:[
                Text(Money.withCurrency(inv.totalPrice, inv.currency), style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize:13)),
                Text('متبقي ${Money.withCurrency(inv.remainingBalance, inv.currency)}', style: GoogleFonts.cairo(fontSize:11,color: AppColors.error)),
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
                Text(pr.currency == AppCurrency.usd ? '\$ USD' : 'ل.س SYP', style: GoogleFonts.cairo(fontSize:11, fontWeight: FontWeight.w800, color: pr.currency == AppCurrency.usd ? AppColors.success : AppColors.goldDark)),
                const SizedBox(width:6),
                StatusBadge(label: pr.completedCost>0?'نشط':'جديد', isCompleted: pr.completedCost>0),
              ]),
              Text('${pr.clientName} • ${pr.totalArea} م²', style: GoogleFonts.cairo(fontSize:12,color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
              const SizedBox(height:8),
              LinearProgressIndicator(value: pr.totalCost==0?0: (pr.completedCost/pr.totalCost).clamp(0.0, 1.0), color: AppColors.gold, backgroundColor: AppColors.divider),
              const SizedBox(height:6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
                Flexible(child: Text('الإجمالي ${Money.withCurrency(pr.totalCost, pr.currency)}', style: GoogleFonts.cairo(fontSize:11), overflow: TextOverflow.ellipsis)),
                const SizedBox(width:8),
                Flexible(child: Text('مكتمل ${Money.withCurrency(pr.completedCost, pr.currency)}', style: GoogleFonts.cairo(fontSize:11,color: AppColors.success), overflow: TextOverflow.ellipsis)),
              ])
            ])),
        ]);
      }),
    );
  }
  Widget _miniStat(IconData icon, String label){
    return Container(padding: const EdgeInsets.symmetric(horizontal:10,vertical:6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children:[Icon(icon,color: Colors.white,size:14), const SizedBox(width:6), Flexible(child: Text(label, style: GoogleFonts.cairo(color: Colors.white, fontSize:11, fontWeight: FontWeight.w600)))] ));
  }
}
