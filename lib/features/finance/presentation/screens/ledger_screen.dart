import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/widgets.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/database/hive_init.dart';
import '../../data/models/transaction.dart';
import '../../logic/finance_engine.dart';

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});
  @override ConsumerState<LedgerScreen> createState()=> _S();
}
class _S extends ConsumerState<LedgerScreen> with SingleTickerProviderStateMixin {
  late TabController tab;
  @override void initState(){ super.initState(); tab=TabController(length:4, vsync:this); }
  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text('المالية والذمم', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)), bottom: TabBar(controller:tab, labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: AppColors.gold, isScrollable:true, tabs:[
        Tab(text:'العملاء'), Tab(text:'المعلمين'), Tab(text:'العمال'), Tab(text:'الموردين'),
      ])),
      body: TabBarView(controller:tab, children:[
        _partyTab(TransactionParty.client),
        _partyTab(TransactionParty.master),
        _partyTab(TransactionParty.worker),
        _partyTab(TransactionParty.supplier),
      ]),
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
        final list = grouped[partyId]!;
        final name = list.first.partyName;
        final balance = FinanceEngine.balanceFor(partyId, party);
        final isDebt = balance>0;
        return GlassCard(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Row(children:[
            Container(width:44,height:44, decoration: BoxDecoration(color: party==TransactionParty.client? AppColors.errorBg: AppColors.goldLight, borderRadius: BorderRadius.circular(10)), child: Icon(party==TransactionParty.client? Icons.person : party==TransactionParty.master? Icons.engineering : party==TransactionParty.worker? Icons.groups : Icons.local_shipping, color: party==TransactionParty.client? AppColors.error: AppColors.goldDark)),
            const SizedBox(width:12),
            Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              Text(name, style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
              Text(partyId, style: GoogleFonts.cairo(fontSize:11,color: AppColors.textSecondary)),
              Text('${list.length} حركة', style: GoogleFonts.cairo(fontSize:11,color: AppColors.textSecondary)),
            ])),
            Column(crossAxisAlignment:CrossAxisAlignment.end, children:[
              Text(Money.format(balance.abs()), style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: isDebt? AppColors.error: AppColors.success)),
              Text(isDebt? (party==TransactionParty.client?'مستحق':'له'): 'مسدد', style: GoogleFonts.cairo(fontSize:11,color: isDebt?AppColors.error:AppColors.success)),
            ])
          ]),
          const Divider(height:16),
          ...list.take(3).map((t)=> Padding(padding: const EdgeInsets.only(bottom:6), child: Row(children:[
            Icon(t.type==TransactionType.debit? Icons.arrow_upward: t.type==TransactionType.credit? Icons.arrow_downward: Icons.check_circle, size:14, color: t.type==TransactionType.debit? AppColors.error: AppColors.success),
            const SizedBox(width:6),
            Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              Text(t.source, style: GoogleFonts.cairo(fontSize:11,fontWeight: FontWeight.w600)),
              Text(t.reason, style: GoogleFonts.cairo(fontSize:10,color: AppColors.textSecondary)),
            ])),
            Text('${t.type==TransactionType.debit?'+': '-'}${Money.format(t.amount)}', style: GoogleFonts.cairo(fontSize:11,fontWeight: FontWeight.w700, color: t.type==TransactionType.debit? AppColors.error: AppColors.success)),
            Text(' ${t.createdAt.toString().substring(0,10)}', style: GoogleFonts.cairo(fontSize:10,color: AppColors.textSecondary)),
          ]))),
          if(list.length>3) TextButton(onPressed: ()=> _showDetail(partyId, party, list), child: Text('عرض كل الحركات (${list.length})', style: GoogleFonts.cairo(fontSize:12))),
          const SizedBox(height:4),
          SizedBox(width:double.infinity, child: OutlinedButton.icon(onPressed: ()=> _payDialog(partyId, name, party), icon: const Icon(Icons.payments_outlined, size:16), label: Text('تسجيل دفعة', style: GoogleFonts.cairo(fontSize:12)))),
        ]));
      },
    );
  }

  void _showDetail(String partyId, TransactionParty party, List<TransactionEntry> list){
    showModalBottomSheet(context:context, isScrollControlled:true, builder:(_)=> DraggableScrollableSheet(expand:false, initialChildSize:0.8, builder:(_,c)=> ListView.separated(controller:c, padding: const EdgeInsets.all(16), itemCount:list.length, separatorBuilder:(_,__)=> const Divider(), itemBuilder:(_,i){
      final t=list[i];
      return ListTile(title: Text(t.source, style: GoogleFonts.cairo(fontSize:13, fontWeight: FontWeight.w700)), subtitle: Text('${t.reason}\n${t.createdAt}', style: GoogleFonts.cairo(fontSize:11)), trailing: Text(Money.format(t.amount), style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: t.type==TransactionType.debit? AppColors.error: AppColors.success)), isThreeLine:true);
    })));
  }

  void _payDialog(String partyId, String name, TransactionParty party){
    final ctrl=TextEditingController();
    showDialog(context:context, builder:(_)=> AlertDialog(title: Text('تسجيل دفعة - $name', style: GoogleFonts.cairo()), content: TextField(controller:ctrl, decoration: const InputDecoration(labelText:'المبلغ'), keyboardType: TextInputType.number), actions:[
      TextButton(onPressed: ()=> Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo())),
      ElevatedButton(onPressed: () async {
        final amt=double.tryParse(ctrl.text)??0;
        if(amt<=0) return;
        await FinanceEngine.addPayment(party:party, partyId:partyId, partyName:name, amount: amt, source:'دفعة مسددة - $name');
        if(mounted) Navigator.pop(context);
        setState((){});
      }, child: Text('تأكيد', style: GoogleFonts.cairo())),
    ]));
  }
}
