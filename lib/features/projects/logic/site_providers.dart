import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/hive_init.dart';
import '../data/models/site_materials.dart';
import '../data/models/site_procedure.dart';
import '../../finance/logic/finance_engine.dart';

final requiredMaterialsProvider =
    StreamProvider.family<List<RequiredMaterial>, String>((ref, projectId) async* {
  final box = HiveInit.requiredMaterials;
  List<RequiredMaterial> getList() => box.values
      .where((m) => m.projectId == projectId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  yield getList();
  yield* box.watch().map((_) => getList());
});

final dailyLogsProvider =
    StreamProvider.family<List<DailyLog>, String>((ref, projectId) async* {
  final box = HiveInit.dailyLogs;
  List<DailyLog> getList() => box.values
      .where((d) => d.projectId == projectId)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  yield getList();
  yield* box.watch().map((_) => getList());
});

final siteProceduresProvider =
    StreamProvider.family<List<SiteProcedure>, String>((ref, dailyLogId) async* {
  final box = HiveInit.siteProcedures;
  List<SiteProcedure> getList() => box.values
      .where((p) => p.dailyLogId == dailyLogId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  yield getList();
  yield* box.watch().map((_) => getList());
});

/// All site procedures of a project (across daily logs).
final projectSiteProceduresProvider =
    Provider.family<List<SiteProcedure>, String>((ref, projectId) {
  ref.watch(dailyLogsProvider(projectId));
  final all = HiveInit.siteProcedures.values
      .where((p) => p.projectId == projectId)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return all;
});

class SiteService {
  // ── Required materials (supplier mandatory + dual finance) ──
  Future<RequiredMaterial> addMaterial({
    required String projectId,
    required String name,
    String category = '',
    required double quantity,
    String unit = 'قطعة',
    double unitPrice = 0,
    required String supplierId,
    required String supplierName,
    required String supplierPhone,
    double downPayment = 0,
  }) async {
    if (name.trim().isEmpty) throw Exception('اسم المادة مطلوب');
    if (quantity <= 0) throw Exception('الكمية مطلوبة');
    if (supplierId.trim().isEmpty || supplierName.trim().isEmpty) {
      throw Exception('اختيار المورد إلزامي');
    }
    final total = quantity * unitPrice;
    if (downPayment < 0 || downPayment > total) {
      throw Exception('الدفعة الأولى يجب أن تكون بين 0 وإجمالي المادة');
    }
    final m = RequiredMaterial(
      projectId: projectId, name: name.trim(), category: category.trim(),
      quantity: quantity, unit: unit, unitPrice: unitPrice,
      supplierId: supplierId.trim(),
      supplierName: supplierName.trim(),
      supplierPhone: supplierPhone.trim(),
      downPayment: downPayment,
    );
    await HiveInit.requiredMaterials.put(m.id, m);
    final project = HiveInit.projects.get(projectId);
    if (project != null) {
      await FinanceEngine.onRequiredMaterialAdded(m, project);
    }
    return m;
  }

  Future<void> updateMaterial(RequiredMaterial m,
      {String? name, String? category, double? quantity, String? unit, double? unitPrice,
       String? supplierId, String? supplierName, String? supplierPhone, double? downPayment}) async {
    if (name != null) m.name = name;
    if (category != null) m.category = category;
    if (quantity != null) m.quantity = quantity;
    if (unit != null) m.unit = unit;
    if (unitPrice != null) m.unitPrice = unitPrice;
    if (supplierId != null) m.supplierId = supplierId;
    if (supplierName != null) m.supplierName = supplierName;
    if (supplierPhone != null) m.supplierPhone = supplierPhone;
    if (downPayment != null) m.downPayment = downPayment;
    if (m.supplierId.trim().isEmpty || m.supplierName.trim().isEmpty) {
      throw Exception('اختيار المورد إلزامي');
    }
    if (m.downPayment < 0 || m.downPayment > m.totalValue) {
      throw Exception('الدفعة الأولى يجب أن تكون بين 0 وإجمالي المادة');
    }
    await m.save();
    final project = HiveInit.projects.get(m.projectId);
    if (project != null) {
      await FinanceEngine.onRequiredMaterialUpdated(m, project);
    }
  }

  Future<void> deleteMaterial(RequiredMaterial m) async {
    await FinanceEngine.onRequiredMaterialDeleted(m);
    await m.delete();
  }

  // ── Daily logs ──
  Future<DailyLog> addLog({
    required String projectId,
    required DateTime date,
    String title = '',
    String notes = '',
  }) async {
    final log = DailyLog(projectId: projectId, date: date, title: title, notes: notes);
    await HiveInit.dailyLogs.put(log.id, log);
    return log;
  }

  Future<void> updateLog(DailyLog log, {DateTime? date, String? title, String? notes}) async {
    if (date != null) log.date = date;
    if (title != null) log.title = title;
    if (notes != null) log.notes = notes;
    await log.save();
  }

  Future<void> deleteLog(DailyLog log) async {
    // Cascade: reverse finance for all procedures inside, then delete them.
    final procs =
        HiveInit.siteProcedures.values.where((p) => p.dailyLogId == log.id).toList();
    final project = HiveInit.projects.get(log.projectId);
    for (final p in procs) {
      if (project != null) {
        await FinanceEngine.onSiteProcedureDeleted(p, project);
      } else {
        await FinanceEngine.clearRelatedTransactions(p.id);
      }
      await p.delete();
    }
    await log.delete();
  }

  // ── Site procedures (only inside a daily log) ──
  Future<SiteProcedure> addSiteProcedure(SiteProcedure proc) async {
    final project = HiveInit.projects.get(proc.projectId);
    if (project == null) throw Exception('المشروع غير موجود');
    proc.currency = project.currency;
    proc.recalc();
    // Deduct consumed materials from project stock.
    for (final c in proc.consumedMaterials) {
      final mat = HiveInit.requiredMaterials.get(c.materialId);
      if (mat == null) throw Exception('مادة غير موجودة: ${c.materialName}');
      if (mat.quantity < c.quantity) {
        throw Exception('الكمية غير كافية من ${mat.name}: متاح ${mat.quantity}');
      }
    }
    for (final c in proc.consumedMaterials) {
      final mat = HiveInit.requiredMaterials.get(c.materialId)!;
      mat.quantity -= c.quantity;
      await mat.save();
    }
    await HiveInit.siteProcedures.put(proc.id, proc);
    // Reload project (may have changed) and post finance.
    final live = HiveInit.projects.get(proc.projectId)!;
    await FinanceEngine.onSiteProcedureAdded(proc, live);
    return proc;
  }

  Future<void> deleteSiteProcedure(SiteProcedure proc) async {
    // Restore consumed materials.
    for (final c in proc.consumedMaterials) {
      final mat = HiveInit.requiredMaterials.get(c.materialId);
      if (mat != null) {
        mat.quantity += c.quantity;
        await mat.save();
      }
    }
    final project = HiveInit.projects.get(proc.projectId);
    if (project != null) {
      await FinanceEngine.onSiteProcedureDeleted(proc, project);
    } else {
      await FinanceEngine.clearRelatedTransactions(proc.id);
    }
    await proc.delete();
  }

  /// Sprint 2026-09 Task 2: full edit for worker/master procedures.
  /// Restores old consumed stock, validates + deducts new, then re-posts
  /// finance exactly once via [FinanceEngine.onSiteProcedureUpdated].
  Future<void> updateSiteProcedure(
    SiteProcedure existing, {
    String? workerId,
    String? workerName,
    double? workerWage,
    String? masterId,
    String? masterName,
    MasterContractType? contractType,
    double? dailyRate,
    String? description,
    double? agreedTotal,
    String? agreementPerUnit,
    List<ConsumedMaterial>? consumedMaterials,
    bool? needVehicle,
    String? driverId,
    String? driverName,
    double? driverWage,
    String? transportNotes,
    String? notes,
  }) async {
    final oldTotal = existing.totalCost;
    // 1. Restore old consumed stock.
    for (final c in existing.consumedMaterials) {
      final mat = HiveInit.requiredMaterials.get(c.materialId);
      if (mat != null) {
        mat.quantity += c.quantity;
        await mat.save();
      }
    }
    // 2. Apply new field values.
    if (workerId != null) existing.workerId = workerId;
    if (workerName != null) existing.workerName = workerName;
    if (workerWage != null) existing.workerWage = workerWage;
    if (masterId != null) existing.masterId = masterId;
    if (masterName != null) existing.masterName = masterName;
    if (contractType != null) existing.contractType = contractType;
    if (dailyRate != null) existing.dailyRate = dailyRate;
    if (description != null) existing.description = description;
    if (agreedTotal != null) existing.agreedTotal = agreedTotal;
    if (agreementPerUnit != null) existing.agreementPerUnit = agreementPerUnit;
    if (consumedMaterials != null) existing.consumedMaterials = consumedMaterials;
    if (needVehicle != null) existing.needVehicle = needVehicle;
    if (driverId != null) existing.driverId = driverId;
    if (driverName != null) existing.driverName = driverName;
    if (driverWage != null) existing.driverWage = driverWage;
    if (transportNotes != null) existing.transportNotes = transportNotes;
    if (notes != null) existing.notes = notes;
    existing.recalc();
    // 3. Validate + deduct new consumed stock.
    for (final c in existing.consumedMaterials) {
      final mat = HiveInit.requiredMaterials.get(c.materialId);
      if (mat == null) throw Exception('مادة غير موجودة: ${c.materialName}');
      if (mat.quantity < c.quantity) {
        throw Exception('الكمية غير كافية من ${mat.name}: متاح ${mat.quantity}');
      }
    }
    for (final c in existing.consumedMaterials) {
      final mat = HiveInit.requiredMaterials.get(c.materialId)!;
      mat.quantity -= c.quantity;
      await mat.save();
    }
    // 4. Finance: revert old totals + clear old rows + re-post once.
    final project = HiveInit.projects.get(existing.projectId);
    if (project == null) throw Exception('المشروع غير موجود');
    await FinanceEngine.onSiteProcedureUpdated(
      updated: existing,
      oldTotal: oldTotal,
      project: project,
    );
  }
}

final siteServiceProvider = Provider((ref) => SiteService());
