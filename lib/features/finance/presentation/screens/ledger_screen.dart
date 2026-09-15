import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/widgets.dart';
import '../../../../core/theme/finance_widgets.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/database/hive_init.dart';
import '../../data/models/transaction.dart';
import '../../logic/finance_engine.dart';
import '../../../factory/presentation/screens/inventory_suppliers_screen.dart';
import '../../../projects/data/models/project.dart';


/// Req #2 / #5 / #6 + Sprint 2026-09 Task 3: strictly separated finance.
/// Tab 0 = Client/Factory ONLY (factory invoices, no project link).
/// Tab 1 = Project/Contracting (project list -> 4-role workspace).
/// Tab 2 = Inventory Suppliers (موردو مخزون المعمل, factory scope only).
/// Tab 3 = Project Owners (أصحاب التعهدات, open owner-fund ledger).
class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});
  @override ConsumerState<LedgerScreen> createState()=> _S();
}
class _S extends ConsumerState<LedgerScreen> with SingleTickerProviderStateMixin {
  late TabController tab;
  final searchCtrl = TextEditingController();
  String personQuery = '';

  @override void initState(){ super.initState(); tab=TabController(length:4, vsync:this); }
  @override void dispose(){ tab.dispose(); searchCtrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context){
    ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('المالية والذمم', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)), bottom: TabBar(controller:tab, labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: AppColors.gold, isScrollable:true, tabs: const [
        Tab(text:'مالية المعمل والعملاء', icon: Icon(Icons.factory_outlined, size: 18)),
        Tab(text:'مالية التعهدات', icon: Icon(Icons.business_outlined, size: 18)),
        Tab(text:'موردو المخزون', icon: Icon(Icons.local_shipping_outlined, size: 18)),
        Tab(text:'أصحاب التعهدات', icon: Icon(Icons.account_balance_wallet_outlined, size: 18)),
      ])),
      body: Column(children:[
        // ── Unified person search (Req #6, no filter chips) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16,12,16,4),
          child: TextField(
            controller: searchCtrl,
            onChanged: (v)=> setState(()=> personQuery = v),
            decoration: InputDecoration(
              hintText: 'بحث عن شخص بالاسم أو الهاتف (كل السجلات)...',
              hintStyle: GoogleFonts.cairo(fontSize:12, color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.person_search, size:20),
              suffixIcon: searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size:18), onPressed:(){ searchCtrl.clear(); setState(()=> personQuery = ''); }) : null,
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
        ),
        if (personQuery.trim().isNotEmpty) _personTimeline(),
        Expanded(child: TabBarView(controller:tab, children:[
          _factoryClientsTab(),
          _contractingProjectsTab(),
          const InventorySuppliersTab(),
          _projectOwnersTab(),
        ])),
      ]),
    );
  }

  /// Req #6: unified profile — full history + 2 summary cards + pay button.
  Widget _personTimeline() {
    final all = FinanceEngine.timelineForPerson(personQuery);
    if (all.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal:16, vertical:8),
        child: GlassCard(child: Center(child: Text('لا توجد حركات مطابقة لـ "$personQuery"', style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize:12)))),
      );
    }
    final s = FinanceEngine.personSummary(all);
    final first = all.first;
    // Infer party for payment action (majority).
    final counts = <TransactionParty,int>{};
    for (final t in all) { counts[t.party] = (counts[t.party] ?? 0) + 1; }
    final dominant = counts.entries.reduce((a,b)=> a.value>=b.value?a:b).key;

    return Container(
      constraints: const BoxConstraints(maxHeight: 380),
      margin: const EdgeInsets.symmetric(horizontal:16, vertical:8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.gold, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
            Row(children:[
              const Icon(Icons.receipt_long, size:18, color: AppColors.deepNavy),
              const SizedBox(width:6),
              Expanded(child: Text('كشف موحد: ${first.partyName} (${all.length} حركة)', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize:13), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height:8),
            // Req #6 top summary cards — strictly ل.س
            Row(children:[
              Expanded(child: _summaryCard('المتبقي للدفع', Money.withCurrency(s.remaining, AppCurrency.syp), AppColors.error, AppColors.errorBg, Icons.account_balance_wallet_outlined)),
              const SizedBox(width:8),
              Expanded(child: _summaryCard('مجموع المدفوع', Money.withCurrency(s.paid, AppCurrency.syp), AppColors.success, AppColors.successBg, Icons.check_circle_outline)),
            ]),
            const SizedBox(height:8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: ()=> showPaymentDialog(
                  context: context,
                  party: dominant,
                  partyId: first.partyId,
                  partyName: first.partyName,
                  partyPhone: first.partyPhone,
                  projectId: first.projectId,
                  initialCurrency: first.currency,
                  onSaved: ()=> setState(()=>{}),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepNavy, foregroundColor: Colors.white),
                icon: const Icon(Icons.payments_outlined, size:16),
                label: Text('دفع دفعة / تسوية', style: GoogleFonts.cairo(fontSize:12, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
        const Divider(height:1),
        Expanded(child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: all.length,
          separatorBuilder:(_,__)=> const Divider(height:12),
          itemBuilder:(_,i)=> _txRow(all[i], showActions: true),
        )),
      ]),
    );
  }

  Widget _summaryCard(String label, String value, Color fg, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Row(children:[Icon(icon, size:14, color: fg), const SizedBox(width:4),
          Flexible(child: Text(label, style: GoogleFonts.cairo(fontSize:11, color: fg, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis))]),
        Text(value, style: GoogleFonts.cairo(fontSize:14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      ]),
    );
  }

  Widget _txRow(TransactionEntry t, {bool showActions = false}) {
    final isDebt = t.type == TransactionType.debit || (t.party != TransactionParty.client && t.type == TransactionType.credit);
    return InkWell(
      onTap: () => showTransactionDetail(context, t),
      borderRadius: BorderRadius.circular(8),
      child: Row(children:[
      Icon(t.type==TransactionType.debit? Icons.arrow_upward: t.type==TransactionType.credit? Icons.arrow_downward: Icons.check_circle, size:14, color: t.type==TransactionType.payment ? AppColors.success : (isDebt ? AppColors.error : AppColors.success)),
      const SizedBox(width:6),
      Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        Row(children:[
          Flexible(child: Text(t.source, style: GoogleFonts.cairo(fontSize:11,fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          const SizedBox(width:6),
          CurrencyBadge(t.currency),
        ]),
        Text('${t.reason} • ${_partyLabel(t.party)}', style: GoogleFonts.cairo(fontSize:10,color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
        if (t.dollarRate != null && t.convertedAmount != null)
          Text('سعر ${t.dollarRate!.toStringAsFixed(0)} • معادل ${Money.withCurrency(t.convertedAmount!, t.secondaryCurrency)}',
              style: GoogleFonts.cairo(fontSize:10, color: AppColors.goldDark)),
      ])),
      const SizedBox(width:6),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children:[
        Text('${t.type==TransactionType.debit?'+': '-'}${Money.withCurrency(t.amount, t.currency)}', style: GoogleFonts.cairo(fontSize:11,fontWeight: FontWeight.w700, color: t.type==TransactionType.payment ? AppColors.success : AppColors.error)),
        Text(t.createdAt.toString().substring(0,10), style: GoogleFonts.cairo(fontSize:10,color: AppColors.textSecondary)),
        if (showActions && t.isPayment)
          Row(mainAxisSize: MainAxisSize.min, children:[
            IconButton(
              tooltip: 'تعديل الدفعة',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size:16, color: AppColors.deepNavy),
              onPressed: ()=> showEditPaymentDialog(context: context, payment: t, onSaved: ()=> setState(()=>{})),
            ),
            IconButton(
              tooltip: 'حذف الدفعة',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, size:16, color: AppColors.error),
              onPressed: () async {
                final ok = await confirmDelete(context, title: 'حذف الدفعة؟',
                    message: 'هل أنت متأكد من حذف دفعة ${Money.withCurrency(t.amount, t.currency)}؟ سيتحدث الرصيد تلقائياً.');
                if (ok) {
                  await FinanceEngine.deletePayment(t);
                  setState(()=>{});
                }
              },
            ),
          ]),
      ]),
    ]));
  }

  String _partyLabel(TransactionParty p) {
    switch (p) {
      case TransactionParty.client: return 'عميل';
      case TransactionParty.master: return 'معلم';
      case TransactionParty.worker: return 'عامل';
      case TransactionParty.supplier: return 'مورد';
      case TransactionParty.driver: return 'سائق';
      case TransactionParty.owner: return 'صاحب تعهد';
    }
  }

  Widget _projectOwnersTab() {
    final allProjects = HiveInit.projects.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final filteredProjects = allProjects.where((p) {
      if (personQuery.trim().isEmpty) return true;
      final q = personQuery.trim().toLowerCase();
      return p.ownerName.toLowerCase().contains(q) ||
          p.clientName.toLowerCase().contains(q) ||
          p.location.toLowerCase().contains(q) ||
          p.ownerPhone.toLowerCase().contains(q);
    }).toList();

    if (allProjects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                'لا توجد مشاريع مضافة بعد',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'عند إضافة أي مشروع جديد، سيظهر صاحب التعهد تلقائياً هنا لمتابعة السحوبات والمصروفات.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredProjects.isEmpty) {
      return Center(
        child: Text(
          'لا يوجد صاحب تعهد مطابق للبحث "$personQuery"',
          style: GoogleFonts.cairo(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filteredProjects.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) {
        final project = filteredProjects[i];
        final fin = FinanceEngine.getProjectOwnerFinancials(project);
        return _buildProjectOwnerCard(fin);
      },
    );
  }

  Widget _buildProjectOwnerCard(ProjectOwnerFinancials fin) {
    final isDeficit = fin.isDeficit;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Owner Name & Project Name
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDeficit ? AppColors.errorBg : AppColors.goldLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_pin_outlined,
                  color: isDeficit ? AppColors.error : AppColors.goldDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            fin.ownerName,
                            style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            'ل.س',
                            style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.goldDark),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'مشروع: ${fin.projectLocation} • ${fin.ownerPhone}',
                      style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Metric Badges: Drawn, Expenses, Net Balance
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border.withOpacity(0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المسحوبات',
                        style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          Money.withCurrency(fin.drawnFunds, AppCurrency.syp),
                          style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.deepNavy),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border.withOpacity(0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المصروفات والإجرائيات',
                        style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          Money.withCurrency(fin.disbursedExpenses, AppCurrency.syp),
                          style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Net Floating Balance Card (Surplus / Deficit)
          InkWell(
            onTap: () => _showOwnerDeficitAuditModal(context, fin),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDeficit ? AppColors.errorBg : AppColors.successBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDeficit ? AppColors.error.withOpacity(0.3) : AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    isDeficit ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                    size: 18,
                    color: isDeficit ? AppColors.error : AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDeficit ? 'نقص رصيد (تم الدفع من الخزينة)' : 'زيادة رصيد (فائض في الخزينة)',
                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: isDeficit ? AppColors.error : AppColors.success),
                        ),
                        Text(
                          isDeficit
                              ? 'عجز بقيمة ${Money.withCurrency(fin.deficitAmount, AppCurrency.syp)} — اضغط لعرض التفاصيل'
                              : 'فائض بقيمة ${Money.withCurrency(fin.surplusAmount, AppCurrency.syp)}',
                          style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w900, color: isDeficit ? AppColors.error : AppColors.success),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: isDeficit ? AppColors.error : AppColors.success,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Control Action Buttons
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () => _showDrawOwnerFundsModal(context, fin.project),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_card, size: 18),
                  label: Text(
                    'سحب رصيد من صاحب التعهد',
                    style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () => _showOwnerDeficitAuditModal(context, fin),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: AppColors.deepNavy),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.deepNavy),
                  label: Text(
                    'كشف الإجرائيات',
                    style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.deepNavy),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDrawOwnerFundsModal(BuildContext context, Project project, {double? initialAmount}) {
    final amountCtrl = TextEditingController(
      text: initialAmount != null && initialAmount > 0 ? initialAmount.toStringAsFixed(0) : '',
    );
    final notesCtrl = TextEditingController(text: 'سحب رصيد نقدي لصالح خزانة المشروع');
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setD) {
          final amt = double.tryParse(amountCtrl.text) ?? 0.0;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: AppColors.goldDark, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'سحب رصيد من صاحب التعهد',
                    style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.goldLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'صاحب التعهد: ${project.ownerName.trim().isNotEmpty ? project.ownerName : project.clientName}',
                          style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.deepNavy),
                        ),
                        Text(
                          'المشروع: ${project.location}',
                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ملاحظة هامة: هذا المبلغ يضاف إلى سيولة المشروع (المسحوبات) ولا يلغي ديون العمال أو الموردين تلقائياً.',
                          style: GoogleFonts.cairo(fontSize: 10, color: AppColors.goldDark, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    onChanged: (_) => setD(() {}),
                    decoration: InputDecoration(
                      labelText: 'المبلغ المسحوب (ل.س) *',
                      labelStyle: GoogleFonts.cairo(fontSize: 12),
                      prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  if (amt > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'المبلغ بالإملاء: ${Money.withCurrency(amt, AppCurrency.syp)}',
                        style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'بيان / ملاحظات الدفعة',
                      labelStyle: GoogleFonts.cairo(fontSize: 12),
                      prefixIcon: const Icon(Icons.note_alt_outlined, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2040),
                      );
                      if (picked != null) setD(() => selectedDate = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'تاريخ الاستلام',
                        labelStyle: GoogleFonts.cairo(fontSize: 12),
                        prefixIcon: const Icon(Icons.calendar_today, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        selectedDate.toString().substring(0, 10),
                        style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: GoogleFonts.cairo()),
              ),
              ElevatedButton(
                onPressed: amt <= 0
                    ? null
                    : () async {
                        await FinanceEngine.drawOwnerFunds(
                          project,
                          amt,
                          reason: notesCtrl.text,
                          date: selectedDate,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        setState(() {});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'تم تسجيل سحب ${Money.withCurrency(amt, AppCurrency.syp)} من صاحب التعهد بنجاح',
                                style: GoogleFonts.cairo(),
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                child: Text(
                  'تأكيد السحب',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showOwnerDeficitAuditModal(BuildContext context, ProjectOwnerFinancials fin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 12),

              // Title & Owner info
              Row(
                children: [
                  const Icon(Icons.assignment_outlined, color: AppColors.deepNavy, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'كشف التدقيق المالي ومصروفات المشروع',
                          style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'صاحب التعهد: ${fin.ownerName} • مشروع ${fin.projectLocation}',
                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Summary banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: fin.isDeficit ? AppColors.errorBg : AppColors.successBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: fin.isDeficit ? AppColors.error.withOpacity(0.3) : AppColors.success.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إجمالي المسحوبات: ${Money.withCurrency(fin.drawnFunds, AppCurrency.syp)}',
                            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'إجمالي المصروفات: ${Money.withCurrency(fin.disbursedExpenses, AppCurrency.syp)}',
                            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          fin.isDeficit ? 'نقص الرصيد المطلوب' : 'الفائض الحقيقي',
                          style: GoogleFonts.cairo(fontSize: 10, color: fin.isDeficit ? AppColors.error : AppColors.success, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          fin.isDeficit
                              ? '-${Money.withCurrency(fin.deficitAmount, AppCurrency.syp)}'
                              : '+${Money.withCurrency(fin.surplusAmount, AppCurrency.syp)}',
                          style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900, color: fin.isDeficit ? AppColors.error : AppColors.success),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'بيان الإجرائيات والمواد المسجلة على المشروع (${fin.auditItems.length})',
                style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),

              // Itemized Audit List
              Expanded(
                child: fin.auditItems.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد إجرائيات أو مصروفات مسجلة على هذا المشروع بعد.',
                          style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        itemCount: fin.auditItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 12),
                        itemBuilder: (_, i) {
                          final item = fin.auditItems[i];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.goldLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.category,
                                  style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.goldDark),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800),
                                    ),
                                    if (item.details != null && item.details!.isNotEmpty)
                                      Text(
                                        item.details!,
                                        style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    Text(
                                      item.date.toString().substring(0, 10),
                                      style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                Money.withCurrency(item.amount, AppCurrency.syp),
                                style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.error),
                              ),
                            ],
                          );
                        },
                      ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showDrawOwnerFundsModal(
                      context,
                      fin.project,
                      initialAmount: fin.isDeficit ? fin.deficitAmount : null,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.add_card, color: Colors.white),
                  label: Text(
                    fin.isDeficit ? 'سحب رصيد الآن لتغطية العجز (${Money.withCurrency(fin.deficitAmount, AppCurrency.syp)})' : 'سحب رصيد إضافي من صاحب التعهد',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sprint 2026-09 Task 3.1: factory-only clients (no project link).
  Widget _factoryClientsTab() {
    final txs = FinanceEngine.factoryClientLedger();
    final Map<String, List<TransactionEntry>> grouped = {};
    for (final t in txs) {
      grouped.putIfAbsent(t.partyId, () => []).add(t);
    }
    if (grouped.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                  'لا توجد ديون معمل/عملاء — فواتير المصنع فقط تظهر هنا',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(color: AppColors.textSecondary))));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final partyId = grouped.keys.elementAt(i);
        final list = grouped[partyId]!
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final name = list.first.partyName;
        final phone = list.first.partyPhone ?? partyId;
        final bal = FinanceEngine.scopedRemaining(
            partyId: partyId, party: TransactionParty.client);
        final paid =
            list.where((t) => t.type == TransactionType.payment).fold(0.0, (s, e) => s + e.amount);
        final isDebt = bal > 0.005;
        return GlassCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: AppColors.errorBg,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.person, color: AppColors.error)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(name,
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis),
                      Text(phone,
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis),
                      Text('${list.length} حركة • معمل فقط',
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ])),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Money.withCurrency(bal.abs(), AppCurrency.syp),
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: bal > 0
                                  ? AppColors.error
                                  : AppColors.success)),
                      Text(isDebt ? 'مستحق' : 'مسدد',
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: isDebt
                                  ? AppColors.error
                                  : AppColors.success)),
                    ])
              ]),
              const Divider(height: 16),
              ...list
                  .take(3)
                  .map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _txRow(t))),
              if (list.length > 3)
                TextButton(
                    onPressed: () => _showDetail(
                        partyId, TransactionParty.client, list),
                    child: Text('عرض كل الحركات (${list.length})',
                        style: GoogleFonts.cairo(fontSize: 12))),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                    child: Text(
                        'مدفوع ${Money.withCurrency(paid, AppCurrency.syp)}',
                        style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: AppColors.textSecondary))),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                      onPressed: () => showPaymentDialog(
                          context: context,
                          party: TransactionParty.client,
                          partyId: partyId,
                          partyName: name,
                          partyPhone: phone == partyId ? null : phone,
                          projectId: null,
                          initialCurrency: AppCurrency.syp,
                          onSaved: () => setState(() {})),
                      icon: const Icon(Icons.payments_outlined, size: 16),
                      label: Text('تسجيل دفعة',
                          style: GoogleFonts.cairo(fontSize: 12))),
                ),
              ]),
            ]));
      },
    );
  }

  /// Sprint 2026-09 Task 3.2: contracting project list -> workspace.
  Widget _contractingProjectsTab() {
    final projects = HiveInit.projects.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (projects.isEmpty) {
      return Center(
          child: Text('لا توجد مشاريع بعد',
              style: GoogleFonts.cairo(color: AppColors.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: projects.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final pr = projects[i];
        final balances =
            FinanceEngine.personnelBalancesForProject(pr.id);
        final pending = balances.values
            .where((b) => b.remaining > 0.005)
            .toList();
        final totalPending =
            pending.fold(0.0, (s, b) => s + b.remaining);
        final totalPaid =
            balances.values.fold(0.0, (s, b) => s + b.paid);
        return GlassCard(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ProjectFinanceWorkspace(projectId: pr.id))),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: AppColors.goldLight,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.business,
                          color: AppColors.goldDark)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                        Text(pr.location,
                            style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis),
                        Text(
                            '${pr.clientName} • ${pending.length} شخص معلق • مدفوع ${Money.withCurrency(totalPaid, AppCurrency.syp)}',
                            style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ])),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: AppColors.textSecondary),
                ]),
                const SizedBox(height: 6),
                Text(
                    'المتبقي ${Money.withCurrency(totalPending, AppCurrency.syp)}',
                    style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: totalPending > 0
                            ? AppColors.error
                            : AppColors.success)),
                Text('اضغط لفتح مساحة المشروع (عمال • معلمين • موردين • سائقين)',
                    style: GoogleFonts.cairo(
                        fontSize: 10, color: AppColors.goldDark)),
              ]),
        );
      },
    );
  }

  void _showDetail(String partyId, TransactionParty party, List<TransactionEntry> list){
    showModalBottomSheet(context:context, isScrollControlled:true, builder:(_)=> DraggableScrollableSheet(expand:false, initialChildSize:0.8, builder:(_,c)=> ListView.separated(controller:c, padding: const EdgeInsets.all(16), itemCount:list.length, separatorBuilder:(_,__)=> const Divider(), itemBuilder:(_,i){
      final t=list[i];
      return ListTile(
        title: Row(children:[Expanded(child: Text(t.source, style: GoogleFonts.cairo(fontSize:13, fontWeight: FontWeight.w700))), CurrencyBadge(t.currency)]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          Text('${t.reason}\n${t.createdAt}', style: GoogleFonts.cairo(fontSize:11)),
          if (t.dollarRate != null && t.convertedAmount != null)
            Text('سعر ${t.dollarRate!.toStringAsFixed(0)} • معادل ${Money.withCurrency(t.convertedAmount!, t.secondaryCurrency)}',
                style: GoogleFonts.cairo(fontSize:11, color: AppColors.goldDark, fontWeight: FontWeight.w700)),
        ]),
        trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children:[
          Text(Money.withCurrency(t.amount, t.currency), style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: t.type==TransactionType.debit? AppColors.error: AppColors.success)),
          if (t.isPayment)
            Row(mainAxisSize: MainAxisSize.min, children:[
              IconButton(tooltip: 'تعديل', visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size:16, color: AppColors.deepNavy),
                onPressed: () async {
                  Navigator.pop(context);
                  await showEditPaymentDialog(context: context, payment: t, onSaved: ()=> setState(()=>{}));
                }),
              IconButton(tooltip: 'حذف', visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size:16, color: AppColors.error),
                onPressed: () async {
                  final ok = await confirmDelete(context, title: 'حذف الدفعة؟',
                      message: 'هل أنت متأكد من حذف دفعة ${Money.withCurrency(t.amount, t.currency)}؟');
                  if (ok) {
                    Navigator.pop(context);
                    await FinanceEngine.deletePayment(t);
                    setState(()=>{});
                  }
                }),
            ]),
        ]),
        isThreeLine:true,
      );
    })));
  }
}

// ─────────────────────────────────────────────────────────────
// Sprint 2026-09 Task 3.3: dedicated per-project financial workspace
// with 4 structured sub-tabs (workers/masters/suppliers/drivers).
// ─────────────────────────────────────────────────────────────
class ProjectFinanceWorkspace extends ConsumerStatefulWidget {
  final String projectId;
  const ProjectFinanceWorkspace({super.key, required this.projectId});
  @override
  ConsumerState<ProjectFinanceWorkspace> createState() => _W();
}

class _W extends ConsumerState<ProjectFinanceWorkspace>
    with SingleTickerProviderStateMixin {
  late TabController tab;
  @override
  void initState() {
    super.initState();
    tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(transactionsProvider);
    final project = HiveInit.projects.get(widget.projectId);
    final title = project?.location ?? 'مساحة المشروع';
    return Scaffold(
      appBar: AppBar(
        title: Text('مالية $title',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15)),
        bottom: TabBar(
            controller: tab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: AppColors.gold,
            isScrollable: true,
            tabs: const [
              Tab(text: 'العمال', icon: Icon(Icons.groups, size: 18)),
              Tab(text: 'المعلمين', icon: Icon(Icons.engineering, size: 18)),
              Tab(text: 'الموردين', icon: Icon(Icons.local_shipping, size: 18)),
              Tab(text: 'السائقين', icon: Icon(Icons.drive_eta, size: 18)),
            ]),
      ),
      body: TabBarView(controller: tab, children: [
        _roleTab(TransactionParty.worker, 'عامل'),
        _roleTab(TransactionParty.master, 'معلم'),
        _roleTab(TransactionParty.supplier, 'مورد'),
        _roleTab(TransactionParty.driver, 'سائق'),
      ]),
    );
  }

  Widget _roleTab(TransactionParty party, String label) {
    final balances =
        FinanceEngine.personnelBalancesForProject(widget.projectId);
    final entries = balances.entries
        .where((e) => e.value.party == party)
        .toList()
      ..sort((a, b) => b.value.remaining.compareTo(a.value.remaining));
    if (entries.isEmpty) {
      return Center(
          child: Text('لا يوجد $label في هذا المشروع',
              style: GoogleFonts.cairo(color: AppColors.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final key = entries[i].key;
        final b = entries[i].value;
        final parts = key.split('|');
        final pid =
            parts.length > 1 ? parts.sublist(1).join('|') : key;
        final txs = HiveInit.transactions.values
            .where((t) =>
                t.projectId == widget.projectId &&
                t.party == party &&
                t.partyId == pid)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final isSettled = b.remaining <= 0.005;
        return GlassCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Expanded(
                    child: Text(b.name,
                        style:
                            GoogleFonts.cairo(fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: isSettled
                          ? AppColors.successBg
                          : AppColors.errorBg,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(isSettled ? 'خالص' : 'متبقي',
                      style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isSettled
                              ? AppColors.success
                              : AppColors.error)),
                ),
              ]),
              Text('${b.phone} • $label • ${txs.length} حركة',
                  style: GoogleFonts.cairo(
                      fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                    child: Text(
                        'متبقي ${Money.withCurrency(b.remaining, AppCurrency.syp)}',
                        style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isSettled
                                ? AppColors.success
                                : AppColors.error))),
                Expanded(
                    child: Text(
                        'مدفوع ${Money.withCurrency(b.paid, AppCurrency.syp)}',
                        style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                        textAlign: TextAlign.end)),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showPaymentDialog(
                    context: context,
                    party: party,
                    partyId: pid,
                    partyName: b.name,
                    partyPhone:
                        b.phone == pid ? null : b.phone,
                    projectId: widget.projectId,
                    initialCurrency: AppCurrency.syp,
                    onSaved: () => setState(() {}),
                  ),
                  icon:
                      const Icon(Icons.payments_outlined, size: 16),
                  label: Text('دفع دفعة / قبض',
                      style: GoogleFonts.cairo(fontSize: 12)),
                ),
              ),
              if (txs.isNotEmpty) ...[
                const Divider(height: 16),
                ...txs.take(3).map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Expanded(
                            child: Text(t.source,
                                style: GoogleFonts.cairo(fontSize: 11),
                                overflow: TextOverflow.ellipsis)),
                        Text(
                            '${t.type == TransactionType.payment ? '-' : '+'}${Money.withCurrency(t.amount, AppCurrency.syp)}',
                            style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: t.type ==
                                        TransactionType.payment
                                    ? AppColors.success
                                    : AppColors.error)),
                      ]),
                    )),
                if (txs.length > 3)
                  Text('${txs.length - 3} حركات أخرى...',
                      style: GoogleFonts.cairo(
                          fontSize: 10,
                          color: AppColors.textSecondary)),
              ],
            ]));
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Single-currency SYP payment engine with dynamic USD calculator.
// Shared entry point used by ledger, dashboard debt views, personnel.
// Final ledger ALWAYS logs ل.س.
// ─────────────────────────────────────────────────────────────

enum PayMode { syp, usd }

/// Record a payment: mode ل.س (direct) or دولار (USD amount × rate → ل.س).
Future<void> showPaymentDialog({
  required BuildContext context,
  required TransactionParty party,
  required String partyId,
  required String partyName,
  String? partyPhone,
  String? projectId,
  AppCurrency initialCurrency = AppCurrency.syp,
  VoidCallback? onSaved,
}) {
  final sypCtrl = TextEditingController();
  final usdCtrl = TextEditingController();
  final rateCtrl = TextEditingController();
  final noteCtrl = TextEditingController(text: 'دفعة مسددة');
  PayMode mode = PayMode.syp;
  String? errorMsg;

  return showDialog(
    context: context,
    builder: (_) => StatefulBuilder(builder: (ctx, setD) {
      final sypAmt = double.tryParse(sypCtrl.text) ?? 0;
      final usdAmt = double.tryParse(usdCtrl.text) ?? 0;
      final rate = double.tryParse(rateCtrl.text) ?? 0;
      final converted = (usdAmt > 0 && rate > 0) ? usdAmt * rate : 0.0;
      final effectiveSyp = mode == PayMode.syp ? sypAmt : converted;
      // Sprint 2026-09 Task 4: live remaining for overpayment guard.
      final remaining = FinanceEngine.scopedRemaining(
          partyId: partyId, party: party, projectId: projectId);
      final overLimit = effectiveSyp > remaining + 0.005;
      return AlertDialog(
        title: Text('تسجيل دفعة - $partyName',
            style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('المبلغ المتبقي المستحق',
                        style: GoogleFonts.cairo(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    Flexible(
                        child: Text(
                            Money.withCurrency(
                                remaining, AppCurrency.syp),
                            style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: remaining > 0
                                    ? AppColors.error
                                    : AppColors.success))),
                  ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Text('طريقة الدفع:', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              ChoiceChip(
                  label: Text('ل.س', style: GoogleFonts.cairo(fontSize: 12)),
                  selected: mode == PayMode.syp,
                  onSelected: (_) => setD(() => mode = PayMode.syp)),
              const SizedBox(width: 8),
              ChoiceChip(
                  label: Text('دولار', style: GoogleFonts.cairo(fontSize: 12)),
                  selected: mode == PayMode.usd,
                  onSelected: (_) => setD(() => mode = PayMode.usd)),
            ]),
            const SizedBox(height: 12),
            if (mode == PayMode.syp) ...[
              TextField(
                  controller: sypCtrl,
                  onChanged: (_) => setD(() {}),
                  decoration: const InputDecoration(
                      labelText: 'المبلغ بالليرة (ل.س) *',
                      prefixIcon: Icon(Icons.payments_outlined, size: 18)),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(10)),
                child: Text('سيُسجَّل في الدفتر: ${Money.withCurrency(sypAmt, AppCurrency.syp)}',
                    style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.deepNavy)),
              ),
            ] else ...[
              TextField(
                  controller: usdCtrl,
                  onChanged: (_) => setD(() {}),
                  decoration: const InputDecoration(
                      labelText: 'المبلغ بالدولار *',
                      prefixIcon: Icon(Icons.attach_money, size: 18)),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
              const SizedBox(height: 8),
              TextField(
                  controller: rateCtrl,
                  onChanged: (_) => setD(() {}),
                  decoration: const InputDecoration(
                      labelText: 'قيمة الدولار اليوم (ل.س) *',
                      hintText: 'مثال: 12000',
                      prefixIcon: Icon(Icons.currency_exchange, size: 18)),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.goldLight, borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(usdAmt > 0 && rate > 0
                      ? '${usdAmt.toStringAsFixed(2)} \$ × ${rate.toStringAsFixed(0)}'
                      : 'أدخل المبلغ وسعر الصرف لعرض المعادل',
                      style: GoogleFonts.cairo(fontSize: 11, color: AppColors.goldDark)),
                  Text('الإجمالي بالليرة: ${Money.withCurrency(converted, AppCurrency.syp)}',
                      style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.deepNavy)),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'ملاحظات')),
            if (overLimit && effectiveSyp > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(
                            'المبلغ المدخل أكبر من المتبقي المستحق',
                            style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error))),
                  ]),
                ),
              ),
            if (errorMsg != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(errorMsg!,
                            style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error))),
                  ]),
                ),
              ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
              onPressed: () async {
                if (effectiveSyp <= 0) return;
                // Sprint 2026-09 Task 4: block overpayment.
                if (effectiveSyp > remaining + 0.005) {
                  setD(() => errorMsg =
                      'المبلغ المدخل أكبر من المتبقي المستحق');
                  return;
                }
                if (mode == PayMode.usd) {
                  if (usdAmt <= 0 || rate <= 0) return;
                  await FinanceEngine.addPayment(
                    party: party, partyId: partyId, partyName: partyName,
                    partyPhone: partyPhone, amount: converted,
                    source: 'دفعة مسددة - $partyName (${usdAmt.toStringAsFixed(2)}\$ بسعر ${rate.toStringAsFixed(0)})',
                    reason: noteCtrl.text.isEmpty ? 'دفعة مسددة' : noteCtrl.text,
                    projectId: projectId, currency: AppCurrency.syp,
                    dollarRate: rate,
                  );
                } else {
                  await FinanceEngine.addPayment(
                    party: party, partyId: partyId, partyName: partyName,
                    partyPhone: partyPhone, amount: sypAmt,
                    source: 'دفعة مسددة - $partyName',
                    reason: noteCtrl.text.isEmpty ? 'دفعة مسددة' : noteCtrl.text,
                    projectId: projectId, currency: AppCurrency.syp,
                  );
                }
                if (context.mounted) Navigator.pop(context);
                onSaved?.call();
              },
              child: Text('تأكيد (${Money.withCurrency(effectiveSyp, AppCurrency.syp)})', style: GoogleFonts.cairo())),
        ],
      );
    }),
  );
}

/// Edit a recorded payment (SYP ledger; optional FX audit fields).
Future<void> showEditPaymentDialog({
  required BuildContext context,
  required TransactionEntry payment,
  VoidCallback? onSaved,
}) {
  final amountCtrl = TextEditingController(text: payment.amount.toString());
  final rateCtrl =
      TextEditingController(text: payment.dollarRate?.toString() ?? '');
  final noteCtrl = TextEditingController(text: payment.reason);
  DateTime date = payment.createdAt;
  String? errorMsg;

  return showDialog(
    context: context,
    builder: (_) => StatefulBuilder(builder: (ctx, setD) {
      final curAmt = double.tryParse(amountCtrl.text) ?? 0;
      // Sprint 2026-09 Task 4: max allowed = current remaining + old amount.
      final remaining = FinanceEngine.scopedRemaining(
          partyId: payment.partyId,
          party: payment.party,
          projectId: payment.projectId);
      final maxAllowed = remaining + payment.amount;
      final over = curAmt > maxAllowed + 0.005;
      return AlertDialog(
        title: Text('تعديل الدفعة - ${payment.partyName}',
            style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الحد الأقصى المسموح',
                        style: GoogleFonts.cairo(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    Flexible(
                        child: Text(
                            Money.withCurrency(
                                maxAllowed, AppCurrency.syp),
                            style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepNavy))),
                  ]),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: amountCtrl,
                onChanged: (_) => setD(() {}),
                decoration: const InputDecoration(labelText: 'المبلغ (ل.س) *'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
            if (over && curAmt > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('المبلغ المدخل أكبر من المتبقي المستحق',
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error)),
              ),
            if (errorMsg != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(errorMsg!,
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error)),
              ),
            const SizedBox(height: 12),
            TextField(
                controller: rateCtrl,
                onChanged: (_) => setD(() {}),
                decoration: const InputDecoration(
                    labelText: 'سعر صرف الدولار (اختياري للتوثيق)',
                    prefixIcon: Icon(Icons.currency_exchange, size: 18)),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
            const SizedBox(height: 12),
            TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'ملاحظات')),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2040));
                if (picked != null) setD(() => date = picked);
              },
              child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'تاريخ الدفعة'),
                  child: Text(date.toString().substring(0, 10),
                      style: GoogleFonts.cairo(fontSize: 13))),
            ),
            const SizedBox(height: 8),
            Text('التعديل يحدّث الرصيد المتبقي تلقائياً بدون قيود يتيمة.',
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
                final a = double.tryParse(amountCtrl.text) ?? 0;
                if (a <= 0) return;
                // Sprint 2026-09 Task 4: block overpayment on edit.
                final rem = FinanceEngine.scopedRemaining(
                    partyId: payment.partyId,
                    party: payment.party,
                    projectId: payment.projectId);
                if (a > rem + payment.amount + 0.005) {
                  setD(() => errorMsg =
                      'المبلغ المدخل أكبر من المتبقي المستحق');
                  return;
                }
                await FinanceEngine.updatePayment(
                  payment: payment,
                  amount: a,
                  currency: AppCurrency.syp,
                  reason: noteCtrl.text,
                  date: date,
                  dollarRate: double.tryParse(rateCtrl.text),
                );
                if (context.mounted) Navigator.pop(context);
                onSaved?.call();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepNavy),
              child: Text('حفظ التعديل', style: GoogleFonts.cairo())),
        ],
      );
    }),
  );
}

// ─────────────────────────────────────────────────────────────
// Detailed financial record modal (Task 7): item lines + totals +
// remaining + down payment preview for factory invoices.
// ─────────────────────────────────────────────────────────────

/// Opens a detailed view for ANY ledger row. If [t.relatedId] matches a
/// factory invoice, shows full invoice breakdown; otherwise shows the
/// transaction audit detail.
Future<void> showTransactionDetail(BuildContext context, TransactionEntry t) {
  InvoiceMatch? match;
  try {
    final inv = HiveInit.invoices.get(t.relatedId ?? '__none__');
    if (inv != null) match = InvoiceMatch(inv.id, inv.invoiceNumber);
  } catch (_) {}
  if (match != null) {
    final inv = HiveInit.invoices.get(match.id);
    if (inv != null) return showInvoiceDetail(context, inv);
  }
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('تفاصيل الحركة',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15)),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _detailRow('الشخص', t.partyName),
          _detailRow('الهاتف', t.partyPhone ?? t.partyId),
          _detailRow('المصدر', t.source),
          _detailRow('البيان', t.reason),
          _detailRow('النوع',
              t.type == TransactionType.debit ? 'دين (لنا)' : t.type == TransactionType.credit ? 'مستحق (علينا)' : 'دفعة مسددة'),
          _detailRow('المبلغ', Money.withCurrency(t.amount, AppCurrency.syp)),
          _detailRow('التاريخ', t.createdAt.toString().substring(0, 16)),
          _detailRow('العملة', 'ل.س (ثابتة)'),
          if (t.dollarRate != null)
            _detailRow('سعر الدولار يوم الدفع', t.dollarRate!.toStringAsFixed(0)),
          if (t.convertedAmount != null)
            _detailRow('المعادل بالدولار',
                Money.withCurrency(t.convertedAmount!, AppCurrency.usd)),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo())),
      ],
    ),
  );
}

class InvoiceMatch {
  final String id;
  final String number;
  InvoiceMatch(this.id, this.number);
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          width: 110,
          child: Text(label,
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary))),
      Expanded(
          child: Text(value,
              style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700))),
    ]),
  );
}

/// Full invoice statement: every item line + totals + down payment + remaining.
Future<void> showInvoiceDetail(BuildContext context, dynamic inv) {
  final items = (inv.effectiveItems as List);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (_, c) => ListView(
        controller: c,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: Text('فاتورة ${inv.invoiceNumber}',
                    style: GoogleFonts.cairo(
                        fontSize: 17, fontWeight: FontWeight.w900))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('ل.س',
                  style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.goldDark)),
            ),
          ]),
          Text('${inv.customerName} • ${inv.customerPhone}',
              style: GoogleFonts.cairo(
                  fontSize: 12, color: AppColors.textSecondary)),
          if ((inv.deliveryAddress as String).isNotEmpty)
            Text(inv.deliveryAddress as String,
                style: GoogleFonts.cairo(
                    fontSize: 12, color: AppColors.textSecondary)),
          const Divider(height: 24),
          Text('الأصناف (${items.length})',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text('فاتورة دفعة مالية — بدون أصناف.',
                style: GoogleFonts.cairo(
                    fontSize: 12, color: AppColors.textSecondary)),
          for (final it in items)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border)),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(it.productName as String,
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(
                          '${(it.quantity as double).toStringAsFixed(0)} ${it.unit} × ${Money.withCurrency((it.unitPrice as double), AppCurrency.syp)}',
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ])),
                Text(
                    Money.withCurrency(
                        (it.quantity as double) * (it.unitPrice as double),
                        AppCurrency.syp),
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
              ]),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.navyCard,
                borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              _darkRow('الإجمالي', Money.withCurrency((inv.totalPrice as double), AppCurrency.syp)),
              const Divider(color: Colors.white24),
              _darkRow('الدفعة الأولى',
                  Money.withCurrency((inv.downPayment as double), AppCurrency.syp),
                  valueColor: AppColors.success),
              const SizedBox(height: 4),
              _darkRow('المتبقي (دين)',
                  Money.withCurrency((inv.remainingBalance as double), AppCurrency.syp),
                  valueColor: AppColors.error),
            ]),
          ),
          if ((inv.notes as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('ملاحظات: ${inv.notes}',
                style: GoogleFonts.cairo(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 8),
          Text('التاريخ: ${(inv.createdAt as DateTime).toString().substring(0, 16)}',
              style: GoogleFonts.cairo(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    ),
  );
}

Widget _darkRow(String label, String value, {Color valueColor = Colors.white}) {
  return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12)),
    Flexible(
        child: Text(value,
            style: GoogleFonts.cairo(
                color: valueColor, fontWeight: FontWeight.w800, fontSize: 14))),
  ]);
}
