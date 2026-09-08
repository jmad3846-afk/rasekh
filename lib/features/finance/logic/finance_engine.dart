import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../core/database/hive_init.dart';
import '../data/models/transaction.dart';
import '../../factory/data/models/invoice.dart';
import '../../projects/data/models/procedure.dart';
import '../../projects/data/models/project.dart';

class FinanceEngine {
  static Box<TransactionEntry> get _box => HiveInit.transactions;
  static Future<void> onInvoiceCreated(Invoice inv) async {
    if (inv.remainingBalance > 0) {
      await _add(TransactionEntry(partyId: inv.customerId, partyName: inv.customerName, party: TransactionParty.client, type: TransactionType.debit, amount: inv.remainingBalance, source: 'فاتورة ${inv.invoiceNumber} - المتبقي', reason: 'شراء ${inv.productName} x${inv.quantity}', relatedId: inv.id));
    }
  }
  static Future<void> onProcedureAdded(Procedure p, Project project) async {
    project.totalCost += p.totalCost;
    if (p.status == ProcedureStatus.completed) project.completedCost += p.totalCost;
    await project.save();
    if (p.status == ProcedureStatus.completed) await _postCompletedProcedure(p, project);
  }
  static Future<void> onProcedureStatusChanged(Procedure p, Project project, ProcedureStatus oldStatus) async {
    if (oldStatus == ProcedureStatus.pending && p.status == ProcedureStatus.completed) { project.completedCost += p.totalCost; await project.save(); await _postCompletedProcedure(p, project); }
    else if (oldStatus == ProcedureStatus.completed && p.status == ProcedureStatus.pending) { project.completedCost -= p.totalCost; await project.save(); await _reverseCompletedProcedure(p, project); }
  }
  static Future<void> onProcedureDeleted(Procedure p, Project project) async {
    project.totalCost -= p.totalCost;
    if (p.status == ProcedureStatus.completed) { project.completedCost -= p.totalCost; await _reverseCompletedProcedure(p, project); }
    await project.save();
  }
  static Future<void> _postCompletedProcedure(Procedure p, Project project) async {
    final base='اجرائية ${p.title} - مشروع ${project.location}';
    await _add(TransactionEntry(partyId: project.clientId, partyName: project.clientName, party: TransactionParty.client, type: TransactionType.debit, amount: p.totalCost, source: base, reason: 'تكلفة اجرائية مكتملة', relatedId: p.id, projectId: project.id));
    await _add(TransactionEntry(partyId: p.masterPhone, partyName: p.masterName, party: TransactionParty.master, type: TransactionType.credit, amount: p.masterWage, source: base, reason: 'أجرة المعلم ${p.masterName}', relatedId: p.id, projectId: project.id));
    for(final w in p.workers) await _add(TransactionEntry(partyId: w.id, partyName: w.name, party: TransactionParty.worker, type: TransactionType.credit, amount: w.cost, source: base, reason: 'أجرة عامل ${w.name}', relatedId: p.id, projectId: project.id));
    await _add(TransactionEntry(partyId: p.supplier.phone, partyName: p.supplier.name, party: TransactionParty.supplier, type: TransactionType.credit, amount: p.supplier.totalCost, source: base, reason: 'مواد: ${p.supplier.materials}', relatedId: p.id, projectId: project.id));
  }
  static Future<void> _reverseCompletedProcedure(Procedure p, Project project) async {
    final base='عكس اجرائية ${p.title} - ${project.location}';
    await _add(TransactionEntry(partyId: project.clientId, partyName: project.clientName, party: TransactionParty.client, type: TransactionType.credit, amount: p.totalCost, source: base, reason: 'إلغاء/إرجاع اجرائية مكتملة', relatedId: p.id, projectId: project.id));
  }
  static Future<void> addPayment({required TransactionParty party, required String partyId, required String partyName, required double amount, required String source, String? projectId, String? relatedId}) async {
    await _add(TransactionEntry(partyId: partyId, partyName: partyName, party: party, type: TransactionType.payment, amount: amount, source: source, reason: 'دفعة مسددة', relatedId: relatedId, projectId: projectId));
  }
  static Future<void> _add(TransactionEntry t) async => await _box.put(t.id, t);
  static double balanceFor(String partyId, TransactionParty party) {
    final txs=_box.values.where((e)=> e.partyId==partyId && e.party==party); double bal=0;
    for(final t in txs){ if(party==TransactionParty.client){ if(t.type==TransactionType.debit) bal+=t.amount; if(t.type==TransactionType.credit||t.type==TransactionType.payment) bal-=t.amount; } else { if(t.type==TransactionType.credit) bal+=t.amount; if(t.type==TransactionType.payment) bal-=t.amount; } }
    return bal;
  }
  static List<TransactionEntry> ledgerFor(String partyId, TransactionParty party)=> _box.values.where((e)=> e.partyId==partyId && e.party==party).toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt));
  static double totalClientDebt(){ double sum=0; for(final t in _box.values.where((e)=> e.party==TransactionParty.client)){ if(t.type==TransactionType.debit) sum+=t.amount; if(t.type==TransactionType.credit||t.type==TransactionType.payment) sum-=t.amount; } return sum; }
}
final transactionsProvider = StreamProvider<List<TransactionEntry>>((ref) async* { final box=HiveInit.transactions; yield box.values.toList(); yield* box.watch().map((_)=> box.values.toList()); });
final clientBalanceProvider = Provider.family<double,String>((ref,customerId){ ref.watch(transactionsProvider); return FinanceEngine.balanceFor(customerId, TransactionParty.client); });
