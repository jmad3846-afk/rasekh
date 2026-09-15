import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../core/database/hive_init.dart';
import '../../../core/utils/currency.dart';
import '../data/models/transaction.dart';
import '../../factory/data/models/invoice.dart';
import '../../factory/data/models/stock_log.dart';
import '../../projects/data/models/procedure.dart';
import '../../projects/data/models/project.dart';
import '../../projects/data/models/site_procedure.dart';
import '../../projects/data/models/site_materials.dart';

/// Idempotent financial ledger engine with multi-currency support.
///
/// Key guarantees:
/// - Every post first clears existing entries with the same [relatedId],
///   so double-taps / rebuilds / re-saves can never triple amounts.
/// - Each party is posted EXACTLY once per procedure/invoice.
/// - Reversals delete original entries (no dangling master/worker/supplier credits).
class ProjectAuditItem {
  final String id;
  final String title;
  final String category; // 'إجرائية ورشة' | 'إجرائية موقع' | 'مواد لازمة' | 'مصروف نقدي'
  final DateTime date;
  final double amount;
  final String? details;
  final String? supplierName;

  ProjectAuditItem({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.amount,
    this.details,
    this.supplierName,
  });
}

class ProjectOwnerFinancials {
  final Project project;
  final String ownerName;
  final String ownerPhone;
  final String projectLocation;
  final double drawnFunds;
  final double disbursedExpenses;
  final List<ProjectAuditItem> auditItems;

  ProjectOwnerFinancials({
    required this.project,
    required this.ownerName,
    required this.ownerPhone,
    required this.projectLocation,
    required this.drawnFunds,
    required this.disbursedExpenses,
    required this.auditItems,
  });

  double get netBalance => drawnFunds - disbursedExpenses;
  bool get isSurplus => netBalance >= 0;
  bool get isDeficit => netBalance < 0;
  double get deficitAmount => netBalance < 0 ? netBalance.abs() : 0.0;
  double get surplusAmount => netBalance > 0 ? netBalance : 0.0;
}

class FinanceEngine {
  static Box<TransactionEntry> get _box => HiveInit.transactions;

  static String projectOwnerPartyId(Project project) {
    return project.ownerPhone.trim().isEmpty ? 'owner-${project.id}' : project.ownerPhone.trim();
  }

  static Future<void> ensureProjectOwnerRecord(Project project) async {
    final partyId = projectOwnerPartyId(project);
    final existing = _box.values.where((e) =>
        e.projectId == project.id &&
        e.party == TransactionParty.owner &&
        e.partyId == partyId).toList();
    if (existing.isNotEmpty) {
      return;
    }
    await _add(TransactionEntry(
      partyId: partyId,
      partyName: project.ownerName.trim().isEmpty ? project.clientName : project.ownerName,
      partyPhone: project.ownerPhone.trim().isEmpty ? project.clientPhone : project.ownerPhone,
      party: TransactionParty.owner,
      type: TransactionType.credit,
      amount: 0,
      source: 'Project Owner Anchor ${project.id}',
      reason: 'صاحب التعهد • ${project.location}',
      projectId: project.id,
      currency: project.currency,
    ));
  }

  static Future<void> drawOwnerFunds(
    Project project,
    double amount, {
    String? reason,
    DateTime? date,
  }) async {
    if (amount <= 0.005) return;
    final partyId = projectOwnerPartyId(project);
    await _add(TransactionEntry(
      partyId: partyId,
      partyName: project.ownerName.trim().isEmpty ? project.clientName : project.ownerName,
      partyPhone: project.ownerPhone.trim().isEmpty ? project.clientPhone : project.ownerPhone,
      party: TransactionParty.owner,
      type: TransactionType.credit,
      amount: amount,
      source: 'سحب رصيد من صاحب التعهد - ${project.location}',
      reason: reason != null && reason.trim().isNotEmpty
          ? reason.trim()
          : 'سحب رصيد نقدي لصالح خزانة المشروع',
      projectId: project.id,
      currency: project.currency,
      createdAt: date,
    ));
  }

  static Future<void> recordOwnerExpense(Project project, double amount, {required String source, required String reason, String? relatedId}) async {
    if (amount <= 0.005) return;
    final partyId = projectOwnerPartyId(project);
    await _add(TransactionEntry(
      partyId: partyId,
      partyName: project.ownerName.trim().isEmpty ? project.clientName : project.ownerName,
      partyPhone: project.ownerPhone.trim().isEmpty ? project.clientPhone : project.ownerPhone,
      party: TransactionParty.owner,
      type: TransactionType.payment,
      amount: amount,
      source: source,
      reason: reason,
      relatedId: relatedId,
      projectId: project.id,
      currency: project.currency,
    ));
  }

  static ProjectOwnerFinancials getProjectOwnerFinancials(Project project) {
    double drawnFunds = 0;
    for (final t in _box.values) {
      if (t.projectId == project.id && t.party == TransactionParty.owner && t.type == TransactionType.credit) {
        drawnFunds += t.amount;
      }
    }

    final auditItems = <ProjectAuditItem>[];

    // Workshop procedures
    try {
      final procedures = HiveInit.procedures.values
          .where((p) => p.projectId == project.id && p.status == ProcedureStatus.completed);
      for (final p in procedures) {
        final detailsList = <String>[];
        if (p.masterWage > 0) detailsList.add('أجرة معلم (${p.masterName}): ${p.masterWage}');
        if (p.workers.isNotEmpty) {
          final wSum = p.workers.fold(0.0, (s, w) => s + w.cost);
          detailsList.add('أجور عمال (${p.workers.length}): $wSum');
        }
        if (p.supplier.totalCost > 0) {
          detailsList.add('تكلفة مواد (${p.supplier.name}): ${p.supplier.totalCost}');
        }
        auditItems.add(ProjectAuditItem(
          id: p.id,
          title: p.title,
          category: 'إجرائية ورشة',
          date: p.date,
          amount: p.totalCost,
          details: detailsList.isEmpty ? null : detailsList.join(' • '),
          supplierName: p.supplier.name.isNotEmpty ? p.supplier.name : null,
        ));
      }
    } catch (_) {}

    // Site procedures
    try {
      final siteProcs = HiveInit.siteProcedures.values
          .where((p) => p.projectId == project.id);
      for (final sp in siteProcs) {
        if (sp.kind == SiteProcedureKind.cashExpense) {
          auditItems.add(ProjectAuditItem(
            id: sp.id,
            title: sp.description.isNotEmpty ? sp.description : 'مصروف نقدي',
            category: 'مصروف نقدي',
            date: sp.date,
            amount: sp.totalCost,
            details: sp.notes.isNotEmpty ? sp.notes : null,
          ));
          continue;
        }
        final detailsList = <String>[];
        if (sp.kind == SiteProcedureKind.worker && sp.workerWage > 0) {
          detailsList.add('أجرة عامل (${sp.workerName}): ${sp.workerWage}');
        }
        if (sp.kind == SiteProcedureKind.master && sp.baseWage > 0) {
          detailsList.add('أجرة معلم (${sp.masterName}): ${sp.baseWage}');
        }
        if (sp.needVehicle && sp.driverWage > 0) {
          detailsList.add('أجرة نقل (${sp.driverName.isEmpty ? "سائق" : sp.driverName}): ${sp.driverWage}');
        }
        auditItems.add(ProjectAuditItem(
          id: sp.id,
          title: sp.description.isNotEmpty ? sp.description : (sp.personName.isNotEmpty ? sp.personName : 'إجرائية موقع'),
          category: 'إجرائية موقع',
          date: sp.date,
          amount: sp.totalCost,
          details: detailsList.isEmpty ? null : detailsList.join(' • '),
        ));
      }
    } catch (_) {}

    // Required Materials
    try {
      final materials = HiveInit.requiredMaterials.values
          .where((m) => m.projectId == project.id);
      for (final m in materials) {
        if (m.totalValue <= 0) continue;
        auditItems.add(ProjectAuditItem(
          id: m.id,
          title: '${m.name} (${m.quantity} ${m.unit})',
          category: 'مواد لازمة',
          date: m.createdAt,
          amount: m.totalValue,
          details: 'مورد: ${m.supplierName.isEmpty ? "غير محدد" : m.supplierName}${m.downPayment > 0 ? " • دفعة أولى: ${m.downPayment}" : ""}',
          supplierName: m.supplierName.isNotEmpty ? m.supplierName : null,
        ));
      }
    } catch (_) {}

    // Manual direct owner expense transactions (if any)
    for (final t in _box.values) {
      if (t.projectId == project.id && t.party == TransactionParty.owner && t.type == TransactionType.payment) {
        final alreadyInAudit = auditItems.any((item) => item.id == t.relatedId);
        if (!alreadyInAudit) {
          auditItems.add(ProjectAuditItem(
            id: t.id,
            title: t.reason.isNotEmpty ? t.reason : t.source,
            category: 'مصروف نقدي',
            date: t.createdAt,
            amount: t.amount,
            details: t.source,
          ));
        }
      }
    }

    auditItems.sort((a, b) => b.date.compareTo(a.date));

    final disbursedExpenses = auditItems.fold(0.0, (s, item) => s + item.amount);

    return ProjectOwnerFinancials(
      project: project,
      ownerName: project.ownerName.trim().isNotEmpty ? project.ownerName : project.clientName,
      ownerPhone: project.ownerPhone.trim().isNotEmpty ? project.ownerPhone : project.clientPhone,
      projectLocation: project.location,
      drawnFunds: drawnFunds,
      disbursedExpenses: disbursedExpenses,
      auditItems: auditItems,
    );
  }

  static double projectOwnerFloatingBalance(Project project) {
    return getProjectOwnerFinancials(project).netBalance;
  }

  static double projectOwnerFloatingBalanceFor(String projectId) {
    final pr = HiveInit.projects.get(projectId);
    if (pr != null) return getProjectOwnerFinancials(pr).netBalance;
    return 0.0;
  }

  static List<TransactionEntry> projectOwnerDeficitAudit(Project project) {
    return projectOwnerDeficitAuditFor(project.id);
  }

  static List<TransactionEntry> projectOwnerDeficitAuditFor(String projectId) {
    return _box.values
        .where((t) => t.projectId == projectId && t.party == TransactionParty.owner && t.type == TransactionType.payment)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

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
    }    await recordOwnerExpense(project, p.totalCost, source: 'Procedure ${p.title}', reason: 'نفقات اجراء ${p.title}');  }

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
    double? dollarRate,
    String reason = 'دفعة مسددة',
    DateTime? date,
  }) async {
    double? converted;
    if (dollarRate != null && dollarRate > 0) {
      converted = CurrencyConverter.convert(
          amount: amount, from: currency, dollarRate: dollarRate);
    }
    await _add(TransactionEntry(
      partyId: partyId,
      partyName: partyName,
      partyPhone: partyPhone,
      party: party,
      type: TransactionType.payment,
      amount: amount,
      source: source,
      reason: reason,
      relatedId: relatedId,
      projectId: projectId,
      currency: currency,
      dollarRate: dollarRate,
      convertedAmount: converted,
      createdAt: date,
    ));
  }

  /// Req #5: full payment editing — adjusts amount, notes, date, rate.
  /// Net remaining balances are derived live from the ledger, so no
  /// orphaned records are created; we simply update the row in place.
  static Future<void> updatePayment({
    required TransactionEntry payment,
    required double amount,
    required AppCurrency currency,
    String? reason,
    String? source,
    DateTime? date,
    double? dollarRate,
  }) async {
    assert(payment.type == TransactionType.payment);
    payment.amount = amount;
    payment.currency = currency;
    if (reason != null) payment.reason = reason;
    if (source != null) payment.source = source;
    if (date != null) payment.createdAt = date;
    payment.dollarRate = dollarRate;
    payment.recalcConversion();
    await payment.save();
  }

  static Future<void> deletePayment(TransactionEntry payment) async {
    await payment.delete();
  }

  static Future<void> _add(TransactionEntry t) async =>
      await _box.put(t.id, t);

  /// Required for the stock-management search UI.
  static bool matchesStockLogQuery(StockLog log, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return log.productName.toLowerCase().contains(q)
        || log.supplierName.toLowerCase().contains(q)
        || log.supplierPhone.toLowerCase().contains(q)
        || log.suppliedMaterials.toLowerCase().contains(q);
  }

  // ── Site procedures (Req #11) ───────────────────────────────
  /// Posts a site procedure: client debit + worker/master credit + driver credit.
  /// Idempotent via [clearRelatedTransactions].
  static Future<void> onSiteProcedureAdded(SiteProcedure p, Project project) async {
    p.currency = project.currency;
    p.recalc();
    await clearRelatedTransactions(p.id);
    project.totalCost += p.totalCost;
    project.completedCost += p.totalCost;
    await project.save();
    final base = 'يومية ${p.description.isEmpty ? p.personName : p.description} - ${project.location}';
    final cur = p.currency;
    await _add(TransactionEntry(
      partyId: project.clientId, partyName: project.clientName,
      partyPhone: project.clientPhone, party: TransactionParty.client,
      type: TransactionType.debit, amount: p.totalCost,
      source: base, reason: 'تكلفة إجرائية موقع',
      relatedId: p.id, projectId: project.id, currency: cur,
    ));
    if (p.kind == SiteProcedureKind.cashExpense) {
      final base = 'مصروف نقدي ${p.description} - ${project.location}';
      final cur = p.currency;
      await _add(TransactionEntry(
        partyId: project.clientId, partyName: project.clientName,
        partyPhone: project.clientPhone, party: TransactionParty.client,
        type: TransactionType.debit, amount: p.totalCost,
        source: base, reason: 'مصروف نقدي',
        relatedId: p.id, projectId: project.id, currency: cur,
      ));
      await recordOwnerExpense(project, p.totalCost, source: base, reason: p.description.isNotEmpty ? p.description : 'مصروف نقدي', relatedId: p.id);
      return;
    }
    if (p.kind == SiteProcedureKind.worker) {
      await _add(TransactionEntry(
        partyId: p.workerId.isEmpty ? 'worker-${p.id}' : p.workerId,
        partyName: p.workerName, party: TransactionParty.worker,
        type: TransactionType.credit, amount: p.workerWage,
        source: base, reason: 'أجرة عامل ${p.workerName}',
        relatedId: p.id, projectId: project.id, currency: cur,
      ));
    } else {
      await _add(TransactionEntry(
        partyId: p.masterId.isEmpty ? 'master-${p.id}' : p.masterId,
        partyName: p.masterName, party: TransactionParty.master,
        type: TransactionType.credit, amount: p.baseWage,
        source: base, reason: p.contractType == MasterContractType.daily
            ? 'يومية معلم ${p.masterName}' : 'مقطوع معلم ${p.masterName}: ${p.description}',
        relatedId: p.id, projectId: project.id, currency: cur,
      ));
    }
    if (p.needVehicle && p.driverWage > 0) {
      await _add(TransactionEntry(
        partyId: p.driverId.isEmpty ? 'driver-${p.id}' : p.driverId,
        partyName: p.driverName.isEmpty ? 'سائق' : p.driverName,
        party: TransactionParty.driver,
        type: TransactionType.credit, amount: p.driverWage,
        source: base, reason: 'أجرة نقل${p.transportNotes.isEmpty ? '' : ': ${p.transportNotes}'}',
        relatedId: p.id, projectId: project.id, currency: cur,
      ));
    }
    await recordOwnerExpense(project, p.totalCost, source: base, reason: 'تكلفة إجرائية موقع: ${p.description.isEmpty ? p.personName : p.description}', relatedId: p.id);
  }

  static Future<void> onSiteProcedureDeleted(SiteProcedure p, Project project) async {
    project.totalCost -= p.totalCost;
    project.completedCost -= p.totalCost;
    await project.save();
    await clearRelatedTransactions(p.id);
  }

  /// Sprint 2026-09 Task 2: edit flow for daily-log procedures.
  /// Reverts old project totals + deletes ALL old ledger rows, then re-posts
  /// exactly once with new values. No duplicates, no orphans.
  static Future<void> onSiteProcedureUpdated({
    required SiteProcedure updated,
    required double oldTotal,
    required Project project,
  }) async {
    updated.currency = project.currency;
    updated.recalc();
    project.totalCost -= oldTotal;
    project.completedCost -= oldTotal;
    await clearRelatedTransactions(updated.id);
    project.totalCost += updated.totalCost;
    project.completedCost += updated.totalCost;
    await project.save();
    await updated.save();
    // Re-post exactly once (same posting logic as add).
    final base =
        'يومية ${updated.description.isEmpty ? updated.personName : updated.description} - ${project.location}';
    final cur = updated.currency;
    if (updated.kind == SiteProcedureKind.cashExpense) {
      await _add(TransactionEntry(
        partyId: project.clientId, partyName: project.clientName,
        partyPhone: project.clientPhone, party: TransactionParty.client,
        type: TransactionType.debit, amount: updated.totalCost,
        source: base, reason: 'مصروف نقدي',
        relatedId: updated.id, projectId: project.id, currency: cur,
      ));
      await recordOwnerExpense(project, updated.totalCost, source: base, reason: updated.description.isNotEmpty ? updated.description : 'مصروف نقدي', relatedId: updated.id);
      return;
    }
    await _add(TransactionEntry(
      partyId: project.clientId, partyName: project.clientName,
      partyPhone: project.clientPhone, party: TransactionParty.client,
      type: TransactionType.debit, amount: updated.totalCost,
      source: base, reason: 'تكلفة إجرائية موقع',
      relatedId: updated.id, projectId: project.id, currency: cur,
    ));
    if (updated.kind == SiteProcedureKind.worker) {
      await _add(TransactionEntry(
        partyId: updated.workerId.isEmpty ? 'worker-${updated.id}' : updated.workerId,
        partyName: updated.workerName, party: TransactionParty.worker,
        type: TransactionType.credit, amount: updated.workerWage,
        source: base, reason: 'أجرة عامل ${updated.workerName}',
        relatedId: updated.id, projectId: project.id, currency: cur,
      ));
    } else {
      await _add(TransactionEntry(
        partyId: updated.masterId.isEmpty ? 'master-${updated.id}' : updated.masterId,
        partyName: updated.masterName, party: TransactionParty.master,
        type: TransactionType.credit, amount: updated.baseWage,
        source: base, reason: updated.contractType == MasterContractType.daily
            ? 'يومية معلم ${updated.masterName}' : 'مقطوع معلم ${updated.masterName}: ${updated.description}',
        relatedId: updated.id, projectId: project.id, currency: cur,
      ));
    }
    if (updated.needVehicle && updated.driverWage > 0) {
      await _add(TransactionEntry(
        partyId: updated.driverId.isEmpty ? 'driver-${updated.id}' : updated.driverId,
        partyName: updated.driverName.isEmpty ? 'سائق' : updated.driverName,
        party: TransactionParty.driver,
        type: TransactionType.credit, amount: updated.driverWage,
        source: base, reason: 'أجرة نقل${updated.transportNotes.isEmpty ? '' : ': ${updated.transportNotes}'}',
        relatedId: updated.id, projectId: project.id, currency: cur,
      ));
    }
    await recordOwnerExpense(project, updated.totalCost, source: base, reason: 'تكلفة إجرائية موقع: ${updated.description.isEmpty ? updated.personName : updated.description}', relatedId: updated.id);
  }

  // ── Required materials dual finance (Task 3) ──────────────
  /// Rule 1 (Receivable/لنا): material total -> project owner debt (client debit).
  /// Rule 2 (Payable/علينا): same total -> supplier credit (we owe supplier).
  /// Rule 3 (Sprint 2026-09 Task 6): initial down payment -> supplier PAYMENT
  ///   entry linked to the same material/project (reduces supplier remaining).
  /// Single SYP currency. Idempotent via [clearRelatedTransactions].
  static Future<void> onRequiredMaterialAdded(
      RequiredMaterial m, Project project) async {
    await clearRelatedTransactions(m.id);
    final total = m.totalValue;
    if (total <= 0) return;
    const cur = AppCurrency.syp;
    final base = 'مواد لازمة ${m.name} - مشروع ${project.location}';
    await _add(TransactionEntry(
      partyId: project.clientId,
      partyName: project.clientName,
      partyPhone: project.clientPhone,
      party: TransactionParty.client,
      type: TransactionType.debit,
      amount: total,
      source: base,
      reason: 'تكلفة مواد لازمة (${m.quantity} ${m.unit})',
      relatedId: m.id,
      projectId: project.id,
      currency: cur,
    ));
    await _add(TransactionEntry(
      partyId: m.supplierPhone.isEmpty ? 'supplier-${m.supplierId}' : m.supplierPhone,
      partyName: m.supplierName.isEmpty ? 'مورد' : m.supplierName,
      partyPhone: m.supplierPhone.isEmpty ? null : m.supplierPhone,
      party: TransactionParty.supplier,
      type: TransactionType.credit,
      amount: total,
      source: base,
      reason: 'مستحق للمورد ${m.supplierName} عن ${m.name}',
      relatedId: m.id,
      projectId: project.id,
      currency: cur,
    ));
    // Down payment: clamp to [0, total] to respect overpayment guard.
    final dp = m.downPayment.clamp(0, total).toDouble();
    if (dp > 0.005) {
      await _add(TransactionEntry(
        partyId: m.supplierPhone.isEmpty ? 'supplier-${m.supplierId}' : m.supplierPhone,
        partyName: m.supplierName.isEmpty ? 'مورد' : m.supplierName,
        partyPhone: m.supplierPhone.isEmpty ? null : m.supplierPhone,
        party: TransactionParty.supplier,
        type: TransactionType.payment,
        amount: dp,
        source: 'دفعة أولى للمورد ${m.supplierName} - ${m.name}',
        reason: 'دفعة أولى عن مواد لازمة (${m.name})',
        relatedId: m.id,
        projectId: project.id,
        currency: cur,
      ));
    }
    await recordOwnerExpense(project, total, source: base, reason: 'تكلفة المواد اللازمة ${m.name}', relatedId: m.id);
  }

  static Future<void> onRequiredMaterialUpdated(
      RequiredMaterial m, Project project) async {
    // Re-post exactly once (clear + add).
    await onRequiredMaterialAdded(m, project);
  }

  static Future<void> onRequiredMaterialDeleted(RequiredMaterial m) async {
    await clearRelatedTransactions(m.id);
  }

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

  /// Unified timeline for a person across factory + project personnel parties.
  /// Matches by name, phone, or id (case-insensitive).
  ///
  /// STRICT EXCLUSION — Project Owners (أصحاب التعهدات) must NEVER appear:
  ///
  ///   Rule 1 — Direct block: any entry with party == owner is skipped.
  ///
  ///   Rule 2 — Indirect block: project owners also appear as "client" rows
  ///   (procedure/material debits) because the owner IS the project client.
  ///   These rows always carry a non-null projectId.  Factory invoice rows
  ///   (the only legitimate "client" rows) have projectId == null.
  ///   Therefore client rows where projectId != null are also excluded.
  ///
  /// Allowed parties in search results:
  ///   • client  (projectId == null) — Factory Clients (عملاء المعمل والفواتير)
  ///   • supplier — Inventory/Project Suppliers (موردو المخزون والتعهدات)
  ///   • worker   — Project Workers (عمال التعهدات)
  ///   • master   — Project Masters (معلمو التعهدات)
  ///   • driver   — Project Drivers (سائقو التعهدات)
  static List<TransactionEntry> timelineForPerson(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final list = _box.values.where((e) {
      // Rule 1 — direct block: owner party is never searchable.
      if (e.party == TransactionParty.owner) return false;
      // Rule 2 — indirect block: project-linked client rows belong to the
      // project owner acting as debtor, not to a factory client.
      if (e.party == TransactionParty.client && e.projectId != null) return false;
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

  /// Strict factory-only receivable KPI: unpaid client invoice debt,
  /// excluding any project-linked client debit rows.
  static double factoryReceivableDebt({AppCurrency? currency}) {
    double sum = 0;
    for (final t in factoryClientLedger()) {
      if (currency != null && t.currency != currency) continue;
      if (t.type == TransactionType.debit) sum += t.amount;
      if (t.type == TransactionType.credit || t.type == TransactionType.payment) sum -= t.amount;
    }
    return sum;
  }

  /// Strict factory-only payable KPI: inventory supplier debt from restock.
  static double factoryPayableDebt({AppCurrency? currency}) {
    double sum = 0;
    for (final t in inventorySupplierLedger()) {
      if (currency != null && t.currency != currency) continue;
      if (t.type == TransactionType.credit) sum += t.amount;
      if (t.type == TransactionType.payment) sum -= t.amount;
    }
    return sum;
  }

  /// Req #3A: payable debts — what WE owe suppliers/masters/workers/drivers.
  static double totalPayableDebt({AppCurrency? currency}) {
    double sum = 0;
    for (final t in _box.values.where((e) =>
        (e.party == TransactionParty.supplier ||
            e.party == TransactionParty.master ||
            e.party == TransactionParty.worker ||
            e.party == TransactionParty.driver) &&
        (currency == null || e.currency == currency))) {
      if (t.type == TransactionType.credit) sum += t.amount;
      if (t.type == TransactionType.payment) sum -= t.amount;
    }
    return sum;
  }

  /// Per-person net remaining + total paid (Req #6 top summary cards).
  /// [isClient]: clients owe us (debit - payment); personnel we owe them
  /// (credit - payment). Returns (remaining, paid).
  static ({double remaining, double paid}) personSummary(
      List<TransactionEntry> timeline) {
    double debt = 0, paid = 0;
    for (final t in timeline) {
      if (t.type == TransactionType.payment) {
        paid += t.amount;
      } else if (t.type == TransactionType.debit ||
          (t.party != TransactionParty.client &&
              t.type == TransactionType.credit)) {
        debt += t.amount;
      }
    }
    return (remaining: (debt - paid), paid: paid);
  }

  /// Req #3B: projects containing personnel with pending (credit > payment) balances.
  static List<String> projectsWithUnpaidPersonnel() {
    final Map<String, double> netByProjectPerson = {};
    for (final t in _box.values) {
      if (t.party == TransactionParty.client) continue;
      if (t.projectId == null || t.projectId!.isEmpty) continue;
      final key = '${t.projectId}|${t.party}|${t.partyId}';
      final cur = netByProjectPerson[key] ?? 0;
      if (t.type == TransactionType.credit) {
        netByProjectPerson[key] = cur + t.amount;
      } else if (t.type == TransactionType.payment) {
        netByProjectPerson[key] = cur - t.amount;
      }
    }
    final projects = <String>{};
    netByProjectPerson.forEach((k, v) {
      if (v > 0.005) projects.add(k.split('|').first);
    });
    return projects.toList();
  }

  /// Personnel balances inside one project: key = party|partyId.
  static Map<String, ({String name, String phone, TransactionParty party, double remaining, double paid})>
      personnelBalancesForProject(String projectId) {
    final Map<String, List<TransactionEntry>> grouped = {};
    for (final t in _box.values) {
      if (t.party == TransactionParty.client) continue;
      if (t.projectId != projectId) continue;
      final key = '${t.party.index}|${t.partyId}';
      grouped.putIfAbsent(key, () => []).add(t);
    }
    final out = <String, ({String name, String phone, TransactionParty party, double remaining, double paid})>{};
    grouped.forEach((key, list) {
      final first = list.first;
      final s = personSummary(list);
      out[key] = (
        name: first.partyName,
        phone: first.partyPhone ?? first.partyId,
        party: first.party,
        remaining: s.remaining,
        paid: s.paid,
      );
    });
    return out;
  }

  /// Sprint 2026-09 Task 4: remaining dues for overpayment guard.
  /// If [projectId] is provided, scope to that project only; otherwise global.
  /// Clients: debit - payment. Personnel: credit - payment.
  static double scopedRemaining({
    required String partyId,
    required TransactionParty party,
    String? projectId,
    AppCurrency currency = AppCurrency.syp,
  }) {
    double debt = 0, paid = 0;
    for (final t in _box.values) {
      if (t.partyId != partyId || t.party != party) continue;
      if (t.currency != currency) continue;
      if (projectId != null && projectId.isNotEmpty && t.projectId != projectId) {
        continue;
      }
      if (t.type == TransactionType.payment) {
        paid += t.amount;
      } else if (t.type == TransactionType.debit ||
          (party != TransactionParty.client && t.type == TransactionType.credit)) {
        debt += t.amount;
      }
    }
    return debt - paid;
  }

  /// Sprint 2026-09 Task 3: factory-only client ledger (no project link).
  static List<TransactionEntry> factoryClientLedger() {
    final list = _box.values
        .where((e) =>
            e.party == TransactionParty.client &&
            (e.projectId == null || e.projectId!.isEmpty))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static double factoryClientDebt() {
    double sum = 0;
    for (final t in factoryClientLedger()) {
      if (t.type == TransactionType.debit) sum += t.amount;
      if (t.type == TransactionType.credit ||
          t.type == TransactionType.payment) sum -= t.amount;
    }
    return sum;
  }

  // ── Inventory stock batches (Sprint 2026-09: موردو مخزون المعمل) ──
  /// Posts a restock batch: supplier CREDIT = batch total (we owe),
  /// plus supplier PAYMENT = down payment (already paid).
  /// Factory scope (projectId = null) so it stays isolated from
  /// contracting supplier ledgers. Idempotent via [clearRelatedTransactions].
  static Future<void> onStockBatchAdded(StockLog log) async {
    await clearRelatedTransactions(log.id);
    final total = log.purchaseCost;
    if (total <= 0) return;
    const cur = AppCurrency.syp;
    final partyId = log.supplierPhone.trim().isEmpty
        ? 'stock-${log.supplierName.trim()}'
        : log.supplierPhone.trim();
    final name =
        log.supplierName.trim().isEmpty ? 'مورد مخزون' : log.supplierName.trim();
    final base = 'مخزون معمل ${log.productName} (+${log.quantityAdded.toStringAsFixed(0)})';
    await _add(TransactionEntry(
      partyId: partyId,
      partyName: name,
      partyPhone: log.supplierPhone.trim().isEmpty ? null : log.supplierPhone.trim(),
      party: TransactionParty.supplier,
      type: TransactionType.credit,
      amount: total,
      source: base,
      reason: 'تكلفة دفعة مخزون (${log.productName})',
      relatedId: log.id,
      projectId: null,
      currency: cur,
    ));
    final dp = log.downPayment.clamp(0, total).toDouble();
    if (dp > 0.005) {
      await _add(TransactionEntry(
        partyId: partyId,
        partyName: name,
        partyPhone: log.supplierPhone.trim().isEmpty ? null : log.supplierPhone.trim(),
        party: TransactionParty.supplier,
        type: TransactionType.payment,
        amount: dp,
        source: 'دفعة أولى مخزون - $name (${log.productName})',
        reason: 'دفعة أولى عن دفعة مخزون (${log.productName})',
        relatedId: log.id,
        projectId: null,
        currency: cur,
      ));
    }
  }

  /// Factory-scope supplier ledger: inventory suppliers ONLY
  /// (project-linked contracting suppliers are excluded).
  static List<TransactionEntry> inventorySupplierLedger() {
    final list = _box.values
        .where((e) =>
            e.party == TransactionParty.supplier &&
            (e.projectId == null || e.projectId!.isEmpty))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Supplier identity profiles for the restock auto-complete.
  /// Key = ledger partyId (phone, or 'stock-{name}' when phoneless).
  /// [suppliedMaterials] = latest non-empty value recorded on any batch.
  /// Suppliers known only from payments (no batch yet) still appear
  /// with empty materials so they remain selectable.
  static Map<String, ({String name, String phone, String suppliedMaterials})>
      inventorySupplierProfiles() {
    final out = <String, ({String name, String phone, String suppliedMaterials})>{};
    // Base identities from the ledger (covers payment-only suppliers too).
    for (final t in inventorySupplierLedger()) {
      out.putIfAbsent(
        t.partyId,
        () => (
          name: t.partyName,
          phone: t.partyPhone ?? t.partyId,
          suppliedMaterials: '',
        ),
      );
    }
    // Enrich with latest batch details from stock logs.
    final logs = HiveInit.stockLogs.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final l in logs) {
      final key = l.supplierPhone.trim().isEmpty
          ? 'stock-${l.supplierName.trim()}'
          : l.supplierPhone.trim();
      if (key == 'stock-' || key.isEmpty) continue;
      final prev = out[key];
      final mats = l.suppliedMaterials.trim().isEmpty
          ? (prev?.suppliedMaterials ?? '')
          : l.suppliedMaterials.trim();
      out[key] = (
        name: l.supplierName.trim().isEmpty
            ? (prev?.name ?? 'مورد مخزون')
            : l.supplierName.trim(),
        phone: l.supplierPhone.trim().isEmpty
            ? (prev?.phone ?? key)
            : l.supplierPhone.trim(),
        suppliedMaterials: mats,
      );
    }
    return out;
  }

  /// Per-supplier totals inside the inventory ledger.
  static Map<String, ({String name, String phone, double totalCost, double paid, double remaining, int moves})>
      inventorySupplierBalances() {
    final Map<String, List<TransactionEntry>> grouped = {};
    for (final t in inventorySupplierLedger()) {
      grouped.putIfAbsent(t.partyId, () => []).add(t);
    }
    final out = <String, ({String name, String phone, double totalCost, double paid, double remaining, int moves})>{};
    grouped.forEach((partyId, list) {
      double cost = 0, paid = 0;
      for (final t in list) {
        if (t.type == TransactionType.credit) cost += t.amount;
        if (t.type == TransactionType.payment) paid += t.amount;
      }
      final first = list.first;
      out[partyId] = (
        name: first.partyName,
        phone: first.partyPhone ?? partyId,
        totalCost: cost,
        paid: paid,
        remaining: cost - paid,
        moves: list.length,
      );
    });
    return out;
  }

  /// Inventory-scoped remaining for ONE supplier (overpayment guard).
  static double inventorySupplierRemaining(String partyId) {
    double cost = 0, paid = 0;
    for (final t in _box.values) {
      if (t.party != TransactionParty.supplier || t.partyId != partyId) {
        continue;
      }
      if (t.projectId != null && t.projectId!.isNotEmpty) continue;
      if (t.currency != AppCurrency.syp) continue;
      if (t.type == TransactionType.credit) cost += t.amount;
      if (t.type == TransactionType.payment) paid += t.amount;
    }
    return cost - paid;
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
