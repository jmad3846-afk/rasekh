import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../core/database/hive_init.dart';
import '../../../core/utils/currency.dart';
import '../data/models/transaction.dart';
import '../../factory/data/models/invoice.dart';
import '../../projects/data/models/procedure.dart';
import '../../projects/data/models/project.dart';

/// Idempotent financial ledger engine with multi-currency support.
///
/// Key guarantees:
/// - Every post first clears existing entries with the same [relatedId],
///   so double-taps / rebuilds / re-saves can never triple amounts.
/// - Each party is posted EXACTLY once per procedure/invoice.
/// - Reversals delete original entries (no dangling master/worker/supplier credits).
class FinanceEngine {
  static Box<TransactionEntry> get _box => HiveInit.transactions;

  /// Delete ALL ledger rows linked to [relatedId] (procedureId / invoiceId).
  static Future<void> clearRelatedTransactions(String relatedId) async {
    final keys = _box.values
        .where((e) => e.relatedId == relatedId)
        .map((e) => e.key)
        .toList();
    for (final k in keys) {
      await _box.delete(k);
    }
  }

  // ── Invoices ──────────────────────────────────────────────
  static Future<void> onInvoiceCreated(Invoice inv) async {
    // Idempotent: wipe any stale rows for this invoice first.
    await clearRelatedTransactions(inv.id);
    if (inv.remainingBalance > 0) {
      await _add(TransactionEntry(
        partyId: inv.customerId,
        partyName: inv.customerName,
        partyPhone: inv.customerPhone,
        party: TransactionParty.client,
        type: TransactionType.debit,
        amount: inv.remainingBalance,
        source: 'فاتورة ${inv.invoiceNumber} - المتبقي',
        reason: 'شراء ${inv.productName} x${inv.quantity}',
        relatedId: inv.id,
        currency: inv.currency,
      ));
    }
  }

  static Future<void> onInvoiceUpdated(Invoice inv) async {
    // Same as create: clear + re-post exact remaining once.
    await onInvoiceCreated(inv);
  }

  static Future<void> onInvoiceDeleted(Invoice inv) async {
    // Full reversal: remove debt rows. No write-off payment.
    await clearRelatedTransactions(inv.id);
  }

  // ── Procedures ────────────────────────────────────────────
  static AppCurrency _projectCurrency(Project project) => project.currency;

  static Future<void> onProcedureAdded(Procedure p, Project project) async {
    // Inherit project currency strictly.
    p.currency = _projectCurrency(project);
    p.recalc();
    // Idempotent guard: never post twice for same procedure.
    await clearRelatedTransactions(p.id);
    project.totalCost += p.totalCost;
    if (p.status == ProcedureStatus.completed) {
      project.completedCost += p.totalCost;
    }
    await project.save();
    if (p.status == ProcedureStatus.completed) {
      await _postCompletedProcedure(p, project);
    }
  }

  static Future<void> onProcedureStatusChanged(
      Procedure p, Project project, ProcedureStatus oldStatus) async {
    if (oldStatus == newStatusOf(p)) return;
    if (oldStatus == ProcedureStatus.pending &&
        p.status == ProcedureStatus.completed) {
      project.completedCost += p.totalCost;
      await project.save();
      // Idempotent re-post (clears first inside).
      await clearRelatedTransactions(p.id);
      await _postCompletedProcedure(p, project);
    } else if (oldStatus == ProcedureStatus.completed &&
        p.status == ProcedureStatus.pending) {
      project.completedCost -= p.totalCost;
      await project.save();
      // Full reversal: delete posted rows.
      await clearRelatedTransactions(p.id);
    }
  }

  static ProcedureStatus newStatusOf(Procedure p) => p.status;

  /// Edit flow: revert old totals + delete old ledger rows, then apply new
  /// values exactly once. No orphans, no duplicates.
  static Future<void> onProcedureUpdated({
    required Procedure updated,
    required double oldTotal,
    required ProcedureStatus oldStatus,
    required Project project,
  }) async {
    updated.currency = _projectCurrency(project);
    updated.recalc();
    // 1. Revert old project totals.
    project.totalCost -= oldTotal;
    if (oldStatus == ProcedureStatus.completed) {
      project.completedCost -= oldTotal;
    }
    // 2. Delete ALL old ledger rows for this procedure.
    await clearRelatedTransactions(updated.id);
    // 3. Apply new totals.
    project.totalCost += updated.totalCost;
    if (updated.status == ProcedureStatus.completed) {
      project.completedCost += updated.totalCost;
    }
    await project.save();
    await updated.save();
    // 4. Re-post exactly once if completed.
    if (updated.status == ProcedureStatus.completed) {
      await _postCompletedProcedure(updated, project);
    }
  }

  static Future<void> onProcedureDeleted(Procedure p, Project project) async {
    project.totalCost -= p.totalCost;
    if (p.status == ProcedureStatus.completed) {
      project.completedCost -= p.totalCost;
      // Full reversal across ALL parties (not just client).
      await clearRelatedTransactions(p.id);
    }
    await project.save();
  }

  /// Posts EXACTLY: 1x client debit, 1x master credit, 1x per worker, 1x supplier.
  /// Caller must have cleared related transactions first (or rely on guard below).
  static Future<void> _postCompletedProcedure(
      Procedure p, Project project) async {
    // Double-guard against triple-posting: if rows already exist, skip.
    final existing =
        _box.values.where((e) => e.relatedId == p.id).toList();
    if (existing.isNotEmpty) {
      await clearRelatedTransactions(p.id);
    }
    final cur = p.currency;
    final base = 'اجرائية ${p.title} - مشروع ${project.location}';
    // 1. Client debit — exactly p.totalCost once.
    await _add(TransactionEntry(
      partyId: project.clientId,
      partyName: project.clientName,
      partyPhone: project.clientPhone,
      party: TransactionParty.client,
      type: TransactionType.debit,
      amount: p.totalCost,
      source: base,
      reason: 'تكلفة اجرائية مكتملة',
      relatedId: p.id,
      projectId: project.id,
      currency: cur,
    ));
    // 2. Master credit — exactly masterWage once.
    await _add(TransactionEntry(
      partyId: p.masterPhone.isEmpty ? 'master-${p.id}' : p.masterPhone,
      partyName: p.masterName,
      partyPhone: p.masterPhone,
      party: TransactionParty.master,
      type: TransactionType.credit,
      amount: p.masterWage,
      source: base,
      reason: 'أجرة المعلم ${p.masterName}',
      relatedId: p.id,
      projectId: project.id,
      currency: cur,
    ));
    // 3. Each worker — exactly once.
    for (final w in p.workers) {
      await _add(TransactionEntry(
        partyId: w.id,
        partyName: w.name,
        partyPhone: w.phone,
        party: TransactionParty.worker,
        type: TransactionType.credit,
        amount: w.cost,
        source: base,
        reason: 'أجرة عامل ${w.name}',
        relatedId: p.id,
        projectId: project.id,
        currency: cur,
      ));
    }
    // 4. Supplier — exactly totalCost once.
    await _add(TransactionEntry(
      partyId: p.supplier.phone.isEmpty ? 'supplier-${p.id}' : p.supplier.phone,
      partyName: p.supplier.name,
      partyPhone: p.supplier.phone,
      party: TransactionParty.supplier,
      type: TransactionType.credit,
      amount: p.supplier.totalCost,
      source: base,
      reason: 'مواد: ${p.supplier.materials}',
      relatedId: p.id,
      projectId: project.id,
      currency: cur,
    ));
  }

  static Future<void> addPayment({
    required TransactionParty party,
    required String partyId,
    required String partyName,
    required double amount,
    required String source,
    String? partyPhone,
    String? projectId,
    String? relatedId,
    AppCurrency currency = AppCurrency.syp,
  }) async {
    await _add(TransactionEntry(
      partyId: partyId,
      partyName: partyName,
      partyPhone: partyPhone,
      party: party,
      type: TransactionType.payment,
      amount: amount,
      source: source,
      reason: 'دفعة مسددة',
      relatedId: relatedId,
      projectId: projectId,
      currency: currency,
    ));
  }

  static Future<void> _add(TransactionEntry t) async =>
      await _box.put(t.id, t);

  // ── Balances (currency-aware) ─────────────────────────────
  static double balanceFor(String partyId, TransactionParty party,
      {AppCurrency? currency}) {
    final txs = _box.values.where((e) =>
        e.partyId == partyId &&
        e.party == party &&
        (currency == null || e.currency == currency));
    double bal = 0;
    for (final t in txs) {
      if (party == TransactionParty.client) {
        if (t.type == TransactionType.debit) bal += t.amount;
        if (t.type == TransactionType.credit ||
            t.type == TransactionType.payment) bal -= t.amount;
      } else {
        if (t.type == TransactionType.credit) bal += t.amount;
        if (t.type == TransactionType.payment) bal -= t.amount;
      }
    }
    return bal;
  }

  static List<TransactionEntry> ledgerFor(String partyId, TransactionParty party,
      {AppCurrency? currency}) {
    final list = _box.values
        .where((e) =>
            e.partyId == partyId &&
            e.party == party &&
            (currency == null || e.currency == currency))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Unified timeline for a person across ALL parties (factory + projects).
  /// Matches by name, phone, or id (case-insensitive).
  static List<TransactionEntry> timelineForPerson(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final list = _box.values.where((e) {
      return e.partyName.toLowerCase().contains(q) ||
          (e.partyPhone ?? '').toLowerCase().contains(q) ||
          e.partyId.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static double totalClientDebt({AppCurrency? currency}) {
    double sum = 0;
    for (final t in _box.values.where((e) =>
        e.party == TransactionParty.client &&
        (currency == null || e.currency == currency))) {
      if (t.type == TransactionType.debit) sum += t.amount;
      if (t.type == TransactionType.credit ||
          t.type == TransactionType.payment) sum -= t.amount;
    }
    return sum;
  }

  static double totalSales({AppCurrency? currency}) {
    double sum = 0;
    for (final t in _box.values.where((e) =>
        e.party == TransactionParty.client &&
        e.type == TransactionType.debit &&
        (currency == null || e.currency == currency))) {
      sum += t.amount;
    }
    // Include fully-paid invoice totals (no remaining => no debit row).
    // Fall back to invoice box for true gross sales per currency.
    try {
      final invBox = HiveInit.invoices;
      double gross = 0;
      for (final inv in invBox.values) {
        if (currency == null || inv.currency == currency) {
          gross += inv.totalPrice;
        }
      }
      // Gross sales = max(debit-sum, invoice gross) to avoid double count:
      // debits only cover remaining balances, so gross is authoritative.
      if (gross > sum) return gross;
    } catch (_) {}
    return sum;
  }
}

final transactionsProvider =
    StreamProvider<List<TransactionEntry>>((ref) async* {
  final box = HiveInit.transactions;
  yield box.values.toList();
  yield* box.watch().map((_) => box.values.toList());
});
final clientBalanceProvider =
    Provider.family<double, String>((ref, customerId) {
  ref.watch(transactionsProvider);
  return FinanceEngine.balanceFor(customerId, TransactionParty.client);
});
