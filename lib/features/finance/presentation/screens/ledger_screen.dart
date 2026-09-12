import 'package:flutter/material.dart';
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

/// Req #2 / #5 / #6: streamlined financial ledger.
class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});
  @override ConsumerState<LedgerScreen> createState()=> _S();
}
class _S extends ConsumerState<LedgerScreen> with SingleTickerProviderStateMixin {
  late TabController tab;
  final searchCtrl = TextEditingController();
  String personQuery = '';

  @override void initState(){ super.initState(); tab=TabController(length:5, vsync:this); }
  @override void dispose(){ tab.dispose(); searchCtrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context){
    ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('المالية والذمم', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)), bottom: TabBar(controller:tab, labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: AppColors.gold, isScrollable:true, tabs: const [
        Tab(text:'العملاء'), Tab(text:'المعلمين'), Tab(text:'العمال'), Tab(text:'الموردين'), Tab(text:'السائقين'),
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
          _partyTab(TransactionParty.client),
          _partyTab(TransactionParty.master),
          _partyTab(TransactionParty.worker),
          _partyTab(TransactionParty.supplier),
          _partyTab(TransactionParty.driver),
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
            // Req #6 top summary cards
            Row(children:[
              Expanded(child: _summaryCard('المتبقي للدفع', Money.format(s.remaining), AppColors.error, AppColors.errorBg, Icons.account_balance_wallet_outlined)),
              const SizedBox(width:8),
              Expanded(child: _summaryCard('مجموع المدفوع', Money.format(s.paid), AppColors.success, AppColors.successBg, Icons.check_circle_outline)),
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
    return Row(children:[
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
    ]);
  }

  String _partyLabel(TransactionParty p) {
    switch (p) {
      case TransactionParty.client: return 'عميل';
      case TransactionParty.master: return 'معلم';
      case TransactionParty.worker: return 'عامل';
      case TransactionParty.supplier: return 'مورد';
      case TransactionParty.driver: return 'سائق';
    }
  }

  Widget _partyTab(TransactionParty party){
    final txs = HiveInit.transactions.values.where((t)=> t.party==party).toList();
    // group by partyId
    final Map<String, List<TransactionEntry>> grouped={};
    for(final t in txs){ grouped.putIfAbsent(t.partyId, ()=> []).add(t); }
    if(grouped.isEmpty) return Center(child: Text('لا توجد حركات', style: GoogleFonts.cairo(color: AppColors.textSecondary)));

    return ListView.separated(
      padding: const EdgeInsets.all(16), itemCount: grouped.length,
      separatorBuilder: (_,__)=> const SizedBox(height:12),
      itemBuilder: (_,i){
        final partyId = grouped.keys.elementAt(i);
        final list = grouped[partyId]!..sort((a,b)=> b.createdAt.compareTo(a.createdAt));
        final name = list.first.partyName;
        final phone = list.first.partyPhone ?? partyId;
        // Per-currency balances (never mix SYP+USD).
        final balSyp = FinanceEngine.balanceFor(partyId, party, currency: AppCurrency.syp);
        final balUsd = FinanceEngine.balanceFor(partyId, party, currency: AppCurrency.usd);
        final hasSyp = list.any((t)=> t.currency == AppCurrency.syp);
        final hasUsd = list.any((t)=> t.currency == AppCurrency.usd);
        final isDebt = (balSyp + balUsd) > 0;
        return GlassCard(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Row(children:[
            Container(width:44,height:44, decoration: BoxDecoration(color: party==TransactionParty.client? AppColors.errorBg: AppColors.goldLight, borderRadius: BorderRadius.circular(10)), child: Icon(_partyIcon(party), color: party==TransactionParty.client? AppColors.error: AppColors.goldDark)),
            const SizedBox(width:12),
            Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              Text(name, style: GoogleFonts.cairo(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
              Text(phone, style: GoogleFonts.cairo(fontSize:11,color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
              Text('${list.length} حركة', style: GoogleFonts.cairo(fontSize:11,color: AppColors.textSecondary)),
            ])),
            Column(crossAxisAlignment:CrossAxisAlignment.end, children:[
              if (hasSyp) Text(Money.withCurrency(balSyp.abs(), AppCurrency.syp), style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize:12, color: balSyp>0? AppColors.error: AppColors.success)),
              if (hasUsd) Text(Money.withCurrency(balUsd.abs(), AppCurrency.usd), style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize:12, color: balUsd>0? AppColors.error: AppColors.success)),
              Text(isDebt? (party==TransactionParty.client?'مستحق':'له'): 'مسدد', style: GoogleFonts.cairo(fontSize:11,color: isDebt?AppColors.error:AppColors.success)),
            ])
          ]),
          const Divider(height:16),
          ...list.take(3).map((t)=> Padding(padding: const EdgeInsets.only(bottom:6), child: _txRow(t))),
          if(list.length>3) TextButton(onPressed: ()=> _showDetail(partyId, party, list), child: Text('عرض كل الحركات (${list.length})', style: GoogleFonts.cairo(fontSize:12))),
          const SizedBox(height:4),
          SizedBox(width:double.infinity, child: OutlinedButton.icon(onPressed: ()=> showPaymentDialog(context: context, party: party, partyId: partyId, partyName: name, partyPhone: phone == partyId ? null : phone, initialCurrency: list.first.currency, onSaved: ()=> setState(()=>{})), icon: const Icon(Icons.payments_outlined, size:16), label: Text('تسجيل دفعة', style: GoogleFonts.cairo(fontSize:12)))),
        ]));
      },
    );
  }

  IconData _partyIcon(TransactionParty p) {
    switch (p) {
      case TransactionParty.client: return Icons.person;
      case TransactionParty.master: return Icons.engineering;
      case TransactionParty.worker: return Icons.groups;
      case TransactionParty.supplier: return Icons.local_shipping;
      case TransactionParty.driver: return Icons.drive_eta;
    }
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
// Req #2: live dynamic currency conversion payment dialog.
// Shared entry point used by ledger, dashboard debt views, personnel.
// ─────────────────────────────────────────────────────────────

/// Record a payment with live FX conversion + audit persistence.
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
  final amountCtrl = TextEditingController();
  final rateCtrl = TextEditingController();
  final noteCtrl = TextEditingController(text: 'دفعة مسددة');
  AppCurrency payCur = initialCurrency;

  return showDialog(
    context: context,
    builder: (_) => StatefulBuilder(builder: (ctx, setD) {
      final amt = double.tryParse(amountCtrl.text) ?? 0;
      final rate = double.tryParse(rateCtrl.text);
      return AlertDialog(
        title: Text('تسجيل دفعة - $partyName',
            style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
                controller: amountCtrl,
                onChanged: (_) => setD(() {}),
                decoration: const InputDecoration(labelText: 'المبلغ *'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            Row(children: [
              Text('العملة:', style: GoogleFonts.cairo(fontSize: 12)),
              const SizedBox(width: 8),
              ChoiceChip(
                  label: Text('ل.س', style: GoogleFonts.cairo(fontSize: 12)),
                  selected: payCur == AppCurrency.syp,
                  onSelected: (_) => setD(() => payCur = AppCurrency.syp)),
              const SizedBox(width: 8),
              ChoiceChip(
                  label: Text('\$', style: GoogleFonts.cairo(fontSize: 12)),
                  selected: payCur == AppCurrency.usd,
                  onSelected: (_) => setD(() => payCur = AppCurrency.usd)),
            ]),
            const SizedBox(height: 12),
            TextField(
                controller: rateCtrl,
                onChanged: (_) => setD(() {}),
                decoration: const InputDecoration(
                    labelText: 'سعر صرف الدولار *',
                    hintText: 'مثال: 12000',
                    prefixIcon: Icon(Icons.currency_exchange, size: 18)),
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            // Req #2 live preview (both cases).
            FxPreview(amount: amt, currency: payCur, dollarRate: rate),
            const SizedBox(height: 12),
            TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'ملاحظات')),
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
                final r = double.tryParse(rateCtrl.text);
                await FinanceEngine.addPayment(
                  party: party, partyId: partyId, partyName: partyName,
                  partyPhone: partyPhone, amount: a,
                  source: 'دفعة مسددة - $partyName',
                  reason: noteCtrl.text.isEmpty ? 'دفعة مسددة' : noteCtrl.text,
                  projectId: projectId, currency: payCur, dollarRate: r,
                );
                if (context.mounted) Navigator.pop(context);
                onSaved?.call();
              },
              child: Text('تأكيد', style: GoogleFonts.cairo())),
        ],
      );
    }),
  );
}

/// Req #5: edit a recorded payment (amount, notes, date, rate) with recalc.
Future<void> showEditPaymentDialog({
  required BuildContext context,
  required TransactionEntry payment,
  VoidCallback? onSaved,
}) {
  final amountCtrl = TextEditingController(text: payment.amount.toString());
  final rateCtrl =
      TextEditingController(text: payment.dollarRate?.toString() ?? '');
  final noteCtrl = TextEditingController(text: payment.reason);
  AppCurrency payCur = payment.currency;
  DateTime date = payment.createdAt;

  return showDialog(
    context: context,
    builder: (_) => StatefulBuilder(builder: (ctx, setD) {
      final amt = double.tryParse(amountCtrl.text) ?? 0;
      final rate = double.tryParse(rateCtrl.text);
      return AlertDialog(
        title: Text('تعديل الدفعة - ${payment.partyName}',
            style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
                controller: amountCtrl,
                onChanged: (_) => setD(() {}),
                decoration: const InputDecoration(labelText: 'المبلغ *'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            Row(children: [
              Text('العملة:', style: GoogleFonts.cairo(fontSize: 12)),
              const SizedBox(width: 8),
              ChoiceChip(
                  label: Text('ل.س', style: GoogleFonts.cairo(fontSize: 12)),
                  selected: payCur == AppCurrency.syp,
                  onSelected: (_) => setD(() => payCur = AppCurrency.syp)),
              const SizedBox(width: 8),
              ChoiceChip(
                  label: Text('\$', style: GoogleFonts.cairo(fontSize: 12)),
                  selected: payCur == AppCurrency.usd,
                  onSelected: (_) => setD(() => payCur = AppCurrency.usd)),
            ]),
            const SizedBox(height: 12),
            TextField(
                controller: rateCtrl,
                onChanged: (_) => setD(() {}),
                decoration: const InputDecoration(
                    labelText: 'سعر صرف الدولار',
                    prefixIcon: Icon(Icons.currency_exchange, size: 18)),
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            FxPreview(amount: amt, currency: payCur, dollarRate: rate),
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
                await FinanceEngine.updatePayment(
                  payment: payment,
                  amount: a,
                  currency: payCur,
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
