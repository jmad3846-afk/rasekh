import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/widgets.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/database/hive_init.dart';
import '../../data/models/transaction.dart';
import '../../logic/finance_engine.dart';

enum LedgerFilter { all, pending, completed }

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});
  @override ConsumerState<LedgerScreen> createState()=> _S();
}
class _S extends ConsumerState<LedgerScreen> with SingleTickerProviderStateMixin {
  late TabController tab;
  final searchCtrl = TextEditingController();
  String personQuery = '';
  LedgerFilter timelineFilter = LedgerFilter.all;

  @override void initState(){ super.initState(); tab=TabController(length:4, vsync:this); }
  @override void dispose(){ tab.dispose(); searchCtrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context){
    ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('المالية والذمم', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)), bottom: TabBar(controller:tab, labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: AppColors.gold, isScrollable:true, tabs:[
        Tab(text:'العملاء'), Tab(text:'المعلمين'), Tab(text:'العمال'), Tab(text:'الموردين'),
      ])),
      body: Column(children:[
        // ── Person search (name or phone) + unified timeline ──
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
        if (personQuery.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal:16, vertical:4),
            child: Row(children:[
              _chip('الكل', LedgerFilter.all),
              const SizedBox(width:8),
              _chip('معلقة', LedgerFilter.pending),
              const SizedBox(width:8),
              _chip('مكتملة/مسددة', LedgerFilter.completed),
            ]),
          ),
        Expanded(child: TabBarView(controller:tab, children:[
          _partyTab(TransactionParty.client),
          _partyTab(TransactionParty.master),
          _partyTab(TransactionParty.worker),
          _partyTab(TransactionParty.supplier),
        ])),
      ]),
    );
  }

  Widget _chip(String label, LedgerFilter f) {
    final sel = timelineFilter == f;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.cairo(fontSize:12, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.textPrimary)),
      selected: sel,
      selectedColor: AppColors.deepNavy,
      onSelected: (_)=> setState(()=> timelineFilter = f),
    );
  }

  /// Unified statement for one person across factory + projects.
  Widget _personTimeline() {
    var all = FinanceEngine.timelineForPerson(personQuery);
    // Status toggles: pending = debit/credit (unsettled), completed = payment (settled).
    if (timelineFilter == LedgerFilter.pending) {
      all = all.where((t) => t.type != TransactionType.payment).toList();
    } else if (timelineFilter == LedgerFilter.completed) {
      all = all.where((t) => t.type == TransactionType.payment).toList();
    }
    if (all.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal:16, vertical:8),
        child: GlassCard(child: Center(child: Text('لا توجد حركات مطابقة لـ "$personQuery"', style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize:12)))),
      );
    }
    // Totals per currency for this person.
    double debtSyp = 0, debtUsd = 0, paidSyp = 0, paidUsd = 0;
    for (final t in all) {
      final isUsd = t.currency == AppCurrency.usd;
      if (t.type == TransactionType.payment) {
        if (isUsd) paidUsd += t.amount; else paidSyp += t.amount;
      } else if (t.type == TransactionType.debit || (t.party != TransactionParty.client && t.type == TransactionType.credit)) {
        if (isUsd) debtUsd += t.amount; else debtSyp += t.amount;
      }
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 320),
      margin: const EdgeInsets.symmetric(horizontal:16, vertical:8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.gold, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
            Row(children:[
              const Icon(Icons.receipt_long, size:18, color: AppColors.deepNavy),
              const SizedBox(width:6),
              Expanded(child: Text('كشف موحد: ${all.first.partyName} (${all.length} حركة)', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize:13), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height:4),
            Wrap(spacing:8, runSpacing:4, children:[
              Text('مستحق ل.س: ${Money.withCurrency(debtSyp, AppCurrency.syp)}', style: GoogleFonts.cairo(fontSize:11, color: AppColors.error, fontWeight: FontWeight.w700)),
              Text('مستحق \$: ${Money.withCurrency(debtUsd, AppCurrency.usd)}', style: GoogleFonts.cairo(fontSize:11, color: AppColors.error, fontWeight: FontWeight.w700)),
              Text('مسدد ل.س: ${Money.withCurrency(paidSyp, AppCurrency.syp)}', style: GoogleFonts.cairo(fontSize:11, color: AppColors.success, fontWeight: FontWeight.w700)),
              Text('مسدد \$: ${Money.withCurrency(paidUsd, AppCurrency.usd)}', style: GoogleFonts.cairo(fontSize:11, color: AppColors.success, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
        const Divider(height:1),
        Expanded(child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: all.length,
          separatorBuilder:(_,__)=> const Divider(height:12),
          itemBuilder:(_,i)=> _txRow(all[i]),
        )),
      ]),
    );
  }

  Widget _txRow(TransactionEntry t) {
    final isDebt = t.type == TransactionType.debit || (t.party != TransactionParty.client && t.type == TransactionType.credit);
    return Row(children:[
      Icon(t.type==TransactionType.debit? Icons.arrow_upward: t.type==TransactionType.credit? Icons.arrow_downward: Icons.check_circle, size:14, color: t.type==TransactionType.payment ? AppColors.success : (isDebt ? AppColors.error : AppColors.success)),
      const SizedBox(width:6),
      Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        Row(children:[
          Flexible(child: Text(t.source, style: GoogleFonts.cairo(fontSize:11,fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          const SizedBox(width:6),
          _currencyBadge(t.currency),
        ]),
        Text('${t.reason} • ${_partyLabel(t.party)}', style: GoogleFonts.cairo(fontSize:10,color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
      ])),
      const SizedBox(width:6),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children:[
        Text('${t.type==TransactionType.debit?'+': '-'}${Money.withCurrency(t.amount, t.currency)}', style: GoogleFonts.cairo(fontSize:11,fontWeight: FontWeight.w700, color: t.type==TransactionType.payment ? AppColors.success : AppColors.error)),
        Text(t.createdAt.toString().substring(0,10), style: GoogleFonts.cairo(fontSize:10,color: AppColors.textSecondary)),
      ]),
    ]);
  }

  String _partyLabel(TransactionParty p) {
    switch (p) {
      case TransactionParty.client: return 'عميل';
      case TransactionParty.master: return 'معلم';
      case TransactionParty.worker: return 'عامل';
      case TransactionParty.supplier: return 'مورد';
    }
  }

  Widget _currencyBadge(AppCurrency c) {
    final isUsd = c == AppCurrency.usd;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal:6, vertical:1),
      decoration: BoxDecoration(color: isUsd ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(20)),
      child: Text(isUsd ? '\$' : 'ل.س', style: GoogleFonts.cairo(fontSize:10, fontWeight: FontWeight.w800, color: isUsd ? AppColors.success : AppColors.goldDark)),
    );
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
            Container(width:44,height:44, decoration: BoxDecoration(color: party==TransactionParty.client? AppColors.errorBg: AppColors.goldLight, borderRadius: BorderRadius.circular(10)), child: Icon(party==TransactionParty.client? Icons.person : party==TransactionParty.master? Icons.engineering : party==TransactionParty.worker? Icons.groups : Icons.local_shipping, color: party==TransactionParty.client? AppColors.error: AppColors.goldDark)),
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
          SizedBox(width:double.infinity, child: OutlinedButton.icon(onPressed: ()=> _payDialog(partyId, name, party, list), icon: const Icon(Icons.payments_outlined, size:16), label: Text('تسجيل دفعة', style: GoogleFonts.cairo(fontSize:12)))),
        ]));
      },
    );
  }

  void _showDetail(String partyId, TransactionParty party, List<TransactionEntry> list){
    showModalBottomSheet(context:context, isScrollControlled:true, builder:(_)=> DraggableScrollableSheet(expand:false, initialChildSize:0.8, builder:(_,c)=> ListView.separated(controller:c, padding: const EdgeInsets.all(16), itemCount:list.length, separatorBuilder:(_,__)=> const Divider(), itemBuilder:(_,i){
      final t=list[i];
      return ListTile(title: Row(children:[Expanded(child: Text(t.source, style: GoogleFonts.cairo(fontSize:13, fontWeight: FontWeight.w700))), _currencyBadge(t.currency)]), subtitle: Text('${t.reason}\n${t.createdAt}', style: GoogleFonts.cairo(fontSize:11)), trailing: Text(Money.withCurrency(t.amount, t.currency), style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: t.type==TransactionType.debit? AppColors.error: AppColors.success)), isThreeLine:true);
    })));
  }

  void _payDialog(String partyId, String name, TransactionParty party, List<TransactionEntry> list){
    final ctrl=TextEditingController();
    AppCurrency payCur = list.isNotEmpty ? list.first.currency : AppCurrency.syp;
    final phone = list.isNotEmpty ? (list.first.partyPhone ?? '') : '';
    showDialog(context:context, builder:(_)=> StatefulBuilder(builder:(ctx, setD)=> AlertDialog(
      title: Text('تسجيل دفعة - $name', style: GoogleFonts.cairo(fontSize:15, fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children:[
        TextField(controller:ctrl, decoration: const InputDecoration(labelText:'المبلغ'), keyboardType: TextInputType.number),
        const SizedBox(height:12),
        Row(children:[
          Text('العملة:', style: GoogleFonts.cairo(fontSize:12)),
          const SizedBox(width:8),
          ChoiceChip(label: Text('ل.س', style: GoogleFonts.cairo(fontSize:12)), selected: payCur == AppCurrency.syp, onSelected:(_)=> setD(()=> payCur = AppCurrency.syp)),
          const SizedBox(width:8),
          ChoiceChip(label: Text('\$', style: GoogleFonts.cairo(fontSize:12)), selected: payCur == AppCurrency.usd, onSelected:(_)=> setD(()=> payCur = AppCurrency.usd)),
        ]),
      ]),
      actions:[
        TextButton(onPressed: ()=> Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
        ElevatedButton(onPressed: () async {
          final amt=double.tryParse(ctrl.text)??0;
          if(amt<=0) return;
          await FinanceEngine.addPayment(party:party, partyId:partyId, partyName:name, partyPhone: phone, amount: amt, source:'دفعة مسددة - $name', currency: payCur);
          if(mounted) Navigator.pop(context);
          setState((){});
        }, child: Text('تأكيد', style: GoogleFonts.cairo())),
      ],
    )));
  }
}
