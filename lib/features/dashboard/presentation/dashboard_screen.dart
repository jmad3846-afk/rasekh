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
import 'debt_screens.dart';
import 'personnel_debts.dart';
import '../../projects/presentation/screens/project_detail.dart';

/// Req #3: dashboard split into Factory (top) + Contracting (bottom).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref){
    final products = ref.watch(productsProvider).value ?? [];
    final invoices = ref.watch(invoicesProvider).value ?? [];
    final projects = ref.watch(projectsProvider).value ?? [];
    ref.watch(transactionsProvider);

    final debtUsd = FinanceEngine.totalClientDebt(currency: AppCurrency.usd);
    final debtSyp = FinanceEngine.totalClientDebt(currency: AppCurrency.syp);
    final payUsd = FinanceEngine.totalPayableDebt(currency: AppCurrency.usd);
    final paySyp = FinanceEngine.totalPayableDebt(currency: AppCurrency.syp);
    final lowStock = products.where((p)=> p.isLowStock).toList();
    final unpaidProjects = FinanceEngine.projectsWithUnpaidPersonnel();

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
        // Hero finance card.
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
            Wrap(spacing:8, runSpacing:8, children:[
              _miniStat(Icons.receipt_long, '${invoices.length} فاتورة'),
              _miniStat(Icons.business, '${projects.length} مشروع'),
              _miniStat(Icons.inventory_2_outlined, '${products.length} منتج'),
              _miniStat(Icons.pending_actions, '${unpaidProjects.length} مشروع معلق الدفع'),
            ]),
          ]),
        ),
        const SizedBox(height: 20),

        // ── A. Factory section (top) ──
        _sectionTitle('🏭 المعمل'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12, crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            _kpi(context,
              title: 'ديون مستحقة لنا',
              amount: '${Money.withCurrency(debtSyp, AppCurrency.syp)}\n${Money.withCurrency(debtUsd, AppCurrency.usd)}',
              icon: Icons.trending_up, color: AppColors.error,
              onTap: ()=> Navigator.push(context, MaterialPageRoute(builder:(_)=> const DebtBreakdownScreen(receivable: true)))),
            _kpi(context,
              title: 'ديون علينا للآخرين',
              amount: '${Money.withCurrency(paySyp, AppCurrency.syp)}\n${Money.withCurrency(payUsd, AppCurrency.usd)}',
              icon: Icons.payments_outlined, color: const Color(0xFFB45309),
              onTap: ()=> Navigator.push(context, MaterialPageRoute(builder:(_)=> const DebtBreakdownScreen(receivable: false)))),
            _kpi(context,
              title: 'المنتجات ذات المخزون المنخفض',
              amount: '${lowStock.length} منتج',
              icon: Icons.warning_amber_rounded, color: AppColors.warning,
              onTap: ()=> Navigator.push(context, MaterialPageRoute(builder:(_)=> const LowStockScreen()))),
          ],
        ),
        const SizedBox(height: 20),

        // ── B. Contracting section (bottom) ──
        _sectionTitle('🏗️ التعهدات'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12, crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            _kpi(context,
              title: 'عدد الأشخاص الواجب الدفع لهم',
              amount: '${_unpaidPeopleCount()} شخص • ${unpaidProjects.length} مشروع',
              icon: Icons.groups_outlined, color: AppColors.deepNavy,
              onTap: ()=> Navigator.push(context, MaterialPageRoute(builder:(_)=> const UnpaidPersonnelScreen()))),
          ],
        ),
        const SizedBox(height: 12),
        // Req #3B: quick material navigation button.
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: ()=> _pickProjectForMaterials(context, projects),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: const Icon(Icons.inventory_2_outlined),
            label: Text('المواد اللازمة لمشروع (انتقال سريع)', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 20),
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
      ]),
    );
  }

  int _unpaidPeopleCount() {
    int n = 0;
    for (final pid in FinanceEngine.projectsWithUnpaidPersonnel()) {
      n += FinanceEngine.personnelBalancesForProject(pid)
          .values.where((b)=> b.remaining > 0.005).length;
    }
    return n;
  }

  void _pickProjectForMaterials(BuildContext context, List projects) {
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا توجد مشاريع', style: GoogleFonts.cairo())));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('اختر المشروع', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: double.maxFinite, height: 300,
          child: ListView.separated(
            itemCount: projects.length,
            separatorBuilder: (_,__)=> const Divider(height: 8),
            itemBuilder: (_, i) {
              final p = projects[i];
              return ListTile(
                title: Text(p.location, style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                subtitle: Text(p.clientName, style: GoogleFonts.cairo(fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ProjectDetailScreen(project: p, initialTab: 0)));
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t, style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w900));
  Widget _miniStat(IconData icon, String label){
    return Container(padding: const EdgeInsets.symmetric(horizontal:10,vertical:6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children:[Icon(icon,color: Colors.white,size:14), const SizedBox(width:6), Flexible(child: Text(label, style: GoogleFonts.cairo(color: Colors.white, fontSize:11, fontWeight: FontWeight.w600)))] ));
  }

  Widget _kpi(BuildContext context, {required String title, required String amount, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GlassCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Row(children:[
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon,color:color,size:20)),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
        ]),
        const SizedBox(height: 10),
        Text(title, style: GoogleFonts.cairo(fontSize:12,color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(amount, style: GoogleFonts.cairo(fontSize:14,fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      ]),
    );
  }
}
