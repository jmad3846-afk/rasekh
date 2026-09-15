import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/finance_widgets.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/database/hive_init.dart';
import '../../logic/site_providers.dart';
import '../../data/models/project.dart';
import '../../data/models/site_materials.dart';
import '../../data/models/site_procedure.dart';
import '../../../personnel/data/models/personnel.dart';

/// Req #11: worker/master procedure form (inside a daily log only).
/// Sprint 2026-09 Task 2: supports both create ([existing] == null)
/// and full edit ([existing] != null) with ledger recalculation.
class SiteProcedureFormScreen extends ConsumerStatefulWidget {
  final Project project;
  final DailyLog log;
  final SiteProcedureKind kind;
  final SiteProcedure? existing;
  const SiteProcedureFormScreen(
      {super.key,
      required this.project,
      required this.log,
      required this.kind,
      this.existing});

  @override
  ConsumerState<SiteProcedureFormScreen> createState() => _S();
}

class _S extends ConsumerState<SiteProcedureFormScreen> {
  final _form = GlobalKey<FormState>();
  PersonnelEntry? worker;
  PersonnelEntry? master;
  PersonnelEntry? driver;
  MasterContractType contractType = MasterContractType.daily;
  final workerWageC = TextEditingController();
  final dailyRateC = TextEditingController();
  final agreedC = TextEditingController();
  final agreeUnitC = TextEditingController();
  final descC = TextEditingController();
  final notesC = TextEditingController();
  final driverWageC = TextEditingController();
  final transportNotesC = TextEditingController();
  bool needVehicle = false;
  // Consumed materials draft: materialId -> qty.
  final Map<String, double> consumed = {};
  bool saving = false;
  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      contractType = e.contractType;
      needVehicle = e.needVehicle;
      workerWageC.text = e.workerWage == 0 ? '' : e.workerWage.toString();
      dailyRateC.text = e.dailyRate == 0 ? '' : e.dailyRate.toString();
      agreedC.text = e.agreedTotal == 0 ? '' : e.agreedTotal.toString();
      agreeUnitC.text = e.agreementPerUnit;
      descC.text = e.description;
      notesC.text = e.notes;
      driverWageC.text = e.driverWage == 0 ? '' : e.driverWage.toString();
      transportNotesC.text = e.transportNotes;
      for (final c in e.consumedMaterials) {
        consumed[c.materialId] = c.quantity;
      }
      // Resolve personnel dropdown selections by stored ids.
      try {
        if (e.workerId.isNotEmpty) {
          worker = HiveInit.personnel.values
              .where((p) => p.role == PersonnelRole.worker)
              .firstWhere((p) => p.id == e.workerId);
        }
      } catch (_) {}
      try {
        if (e.masterId.isNotEmpty) {
          master = HiveInit.personnel.values
              .where((p) => p.role == PersonnelRole.master)
              .firstWhere((p) => p.id == e.masterId);
        }
      } catch (_) {}
      try {
        if (e.driverId.isNotEmpty) {
          driver = HiveInit.personnel.values
              .where((p) => p.role == PersonnelRole.driver)
              .firstWhere((p) => p.id == e.driverId);
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    workerWageC.dispose(); dailyRateC.dispose(); agreedC.dispose();
    agreeUnitC.dispose(); descC.dispose(); notesC.dispose();
    driverWageC.dispose(); transportNotesC.dispose();
    super.dispose();
  }

  double get _consumedMatCost {
    double sum = 0;
    consumed.forEach((matId, qty) {
      if (qty > 0) {
        try {
          final mat = HiveInit.requiredMaterials.get(matId);
          if (mat != null && mat.unitPrice > 0) {
            sum += qty * mat.unitPrice;
          }
        } catch (_) {}
      }
    });
    return sum;
  }

  double get _base {
    if (widget.kind == SiteProcedureKind.cashExpense) {
      return double.tryParse(workerWageC.text) ?? 0;
    }
    if (widget.kind == SiteProcedureKind.worker) {
      return double.tryParse(workerWageC.text) ?? 0;
    }
    return contractType == MasterContractType.daily
        ? (double.tryParse(dailyRateC.text) ?? 0)
        : (double.tryParse(agreedC.text) ?? 0);
  }

  double get _total => _base + (needVehicle ? (double.tryParse(driverWageC.text) ?? 0) : 0) + _consumedMatCost;

  List<PersonnelEntry> _byRole(PersonnelRole r) =>
      HiveInit.personnel.values.where((e) => e.role == r).toList();

  @override
  Widget build(BuildContext context) {
    final isCash = widget.kind == SiteProcedureKind.cashExpense;
    final isWorker = widget.kind == SiteProcedureKind.worker;
    final materials = HiveInit.requiredMaterials.values
        .where((m) => m.projectId == widget.project.id)
        .toList();
    return Scaffold(
      appBar: AppBar(
          title: Text(
              isEdit
                  ? (isCash ? 'تعديل مصروف نقدي' : (isWorker ? 'تعديل إجرائية عامل' : 'تعديل إجرائية معلم'))
                  : (isCash ? 'إضافة مصروف نقدي' : (isWorker ? 'إجرائية عامل' : 'إجرائية معلم')),
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800))),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.currency_exchange,
                    size: 18, color: AppColors.goldDark),
                const SizedBox(width: 8),
                Text('عملة المشروع:',
                    style: GoogleFonts.cairo(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                CurrencyBadge(widget.project.currency),
              ])),
          const SizedBox(height: 16),
          if (isCash) ...[
            TextFormField(
              controller: workerWageC,
              decoration: const InputDecoration(
                labelText: 'المبلغ / Amount *',
                hintText: 'أدخل قيمة المصروف النقدي',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              onChanged: (_) => setState(() {}),
              validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descC,
              decoration: const InputDecoration(
                labelText: 'السبب أو البيان / Reason or Description *',
                hintText: 'مثال: رخصة بناء، مواصلات طارئة، شراء مستلزمات موقع...',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              maxLines: 2,
              validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: notesC,
              decoration: const InputDecoration(
                labelText: 'ملاحظات / Notes (اختياري)',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
              maxLines: 2,
            ),
          ] else if (isWorker) ...[
            Text('العامل *',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            DropdownButtonFormField<PersonnelEntry>(
              value: worker,
              decoration: const InputDecoration(
                  labelText: 'اختر العامل (من العاملين)'),
              items: _byRole(PersonnelRole.worker)
                  .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text('${p.name} • ${p.phone}',
                          style: GoogleFonts.cairo(fontSize: 13))))
                  .toList(),
              onChanged: (v) => setState(() => worker = v),
              validator: (v) => v == null ? 'اختر العامل' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: workerWageC,
                decoration:
                    const InputDecoration(labelText: 'أجرة العامل *'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                onChanged: (_) => setState(() {}),
                validator: (v) => v!.isEmpty ? 'مطلوب' : null),
          ] else ...[
            Row(children: [
              Expanded(
                  child: _contractOption(MasterContractType.daily,
                      'يومية', Icons.today_outlined)),
              const SizedBox(width: 8),
              Expanded(
                  child: _contractOption(MasterContractType.lumpSum,
                      'مقطوع', Icons.handshake_outlined)),
            ]),
            const SizedBox(height: 12),
            Text('المعلم *',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            DropdownButtonFormField<PersonnelEntry>(
              value: master,
              decoration: const InputDecoration(
                  labelText: 'اختر المعلم (من العاملين)'),
              items: _byRole(PersonnelRole.master)
                  .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(
                          '${p.name} • ${p.extra} • ${p.phone}',
                          style: GoogleFonts.cairo(fontSize: 13))))
                  .toList(),
              onChanged: (v) => setState(() => master = v),
              validator: (v) => v == null ? 'اختر المعلم' : null,
            ),
            const SizedBox(height: 12),
            if (contractType == MasterContractType.daily)
              TextFormField(
                  controller: dailyRateC,
                  decoration: const InputDecoration(
                      labelText: 'الأجرة اليومية *'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  onChanged: (_) => setState(() {}),
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null)
            else ...[
              TextFormField(
                  controller: descC,
                  decoration: const InputDecoration(
                      labelText: 'وصف الإجرائية *'),
                  maxLines: 2,
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null),
              const SizedBox(height: 8),
              TextFormField(
                  controller: agreedC,
                  decoration: const InputDecoration(
                      labelText: 'السعر المتفق الإجمالي *'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  onChanged: (_) => setState(() {}),
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null),
              const SizedBox(height: 8),
              TextFormField(
                  controller: agreeUnitC,
                  decoration: const InputDecoration(
                      labelText: 'كم متفقين عالوحدة (معلومة فقط)',
                      hintText: 'مثال: 50 ألف للمتر')),
            ],
          ],
          if (!isCash && isWorker) ...[
            const SizedBox(height: 12),
            TextFormField(
                controller: notesC,
                decoration: const InputDecoration(
                    labelText: 'ملاحظات (وصف العمل المنجز)'),
                maxLines: 2),
          ] else if (!isCash && contractType == MasterContractType.daily) ...[
            const SizedBox(height: 12),
            TextFormField(
                controller: notesC,
                decoration:
                    const InputDecoration(labelText: 'ملاحظات'),
                maxLines: 2),
          ],
          if (!isCash) ...[
            const SizedBox(height: 16),
            Text('المواد المستهلكة (تخصم من المواد اللازمة)',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (materials.isEmpty)
              Text('لا توجد مواد لازمة — أضفها أولاً من زر المواد اللازمة.',
                  style: GoogleFonts.cairo(
                      fontSize: 12, color: AppColors.textSecondary)),
            for (final m in materials)
              CheckboxListTile(
                dense: true,
                title: Text('${m.name} (متاح ${m.quantity.toStringAsFixed(1)} ${m.unit})',
                    style: GoogleFonts.cairo(fontSize: 12)),
                value: consumed.containsKey(m.id),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      consumed[m.id] = 1;
                    } else {
                      consumed.remove(m.id);
                    }
                  });
                },
                secondary: consumed.containsKey(m.id)
                    ? SizedBox(
                        width: 70,
                        child: TextFormField(
                          initialValue: consumed[m.id].toString(),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          decoration: const InputDecoration(
                              labelText: 'كمية', isDense: true),
                          onChanged: (val) => consumed[m.id] =
                              double.tryParse(val) ?? 0,
                        ),
                      )
                    : null,
              ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: Text('بحاجة سيارة؟ / Need Vehicle',
                  style: GoogleFonts.cairo(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              value: needVehicle,
              activeThumbColor: AppColors.deepNavy,
              onChanged: (v) => setState(() => needVehicle = v),
            ),
            if (needVehicle) ...[
              DropdownButtonFormField<PersonnelEntry>(
                value: driver,
                decoration: const InputDecoration(
                    labelText: 'اختر السائق (من العاملين) *'),
                items: _byRole(PersonnelRole.driver)
                    .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(
                            '${p.name} • ${p.extra} • ${p.phone}',
                            style: GoogleFonts.cairo(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => driver = v),
                validator: (v) =>
                    (needVehicle && v == null) ? 'اختر السائق' : null,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: driverWageC,
                        decoration: const InputDecoration(
                            labelText: 'أجرة السائق *'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        onChanged: (_) => setState(() {}),
                        validator: (v) =>
                            (needVehicle && (v == null || v.isEmpty))
                                ? 'مطلوب'
                                : null)),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        controller: transportNotesC,
                        decoration: const InputDecoration(
                            labelText: 'ملاحظات النقل'))),
              ]),
            ],
          ],
          const SizedBox(height: 12),
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.navyCard,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('إجمالي المصروف',
                        style: GoogleFonts.cairo(
                            color: Colors.white70, fontSize: 12)),
                    Text(
                        Money.withCurrency(
                            _total, widget.project.currency),
                        style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                  ])),
          Text(
              isCash
                  ? 'مصروف نقدي مباشر يضاف إلى مصروفات صاحب التعهد.'
                  : isWorker
                      ? 'المعادلة الكلية: أجرة العامل + أجرة السائق (إن وُجد) + تكلفة المواد المستهلكة (إن وُجدت)'
                      : 'المعادلة الكلية: الأجرة/المقطوع + أجرة السائق (إن وُجد) + تكلفة المواد المستهلكة (إن وُجدت)',
              style: GoogleFonts.cairo(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!_form.currentState!.validate()) return;
                      setState(() => saving = true);
                      try {
                        final cons = consumed.entries
                            .where((e) => e.value > 0)
                            .map((e) {
                          final mat = materials.firstWhere(
                              (m) => m.id == e.key);
                          return ConsumedMaterial(
                              materialId: mat.id,
                              materialName: mat.name,
                              quantity: e.value,
                              unit: mat.unit);
                        }).toList();
                        if (isEdit) {
                          await ref.read(siteServiceProvider).updateSiteProcedure(
                                widget.existing!,
                                workerId: worker?.id ?? '',
                                workerName: worker?.name ?? '',
                                workerWage: double.tryParse(workerWageC.text) ?? 0,
                                masterId: master?.id ?? '',
                                masterName: master?.name ?? '',
                                contractType: contractType,
                                dailyRate: double.tryParse(dailyRateC.text) ?? 0,
                                description: isWorker
                                    ? notesC.text
                                    : (contractType == MasterContractType.lumpSum
                                        ? descC.text
                                        : notesC.text),
                                agreedTotal: double.tryParse(agreedC.text) ?? 0,
                                agreementPerUnit: agreeUnitC.text,
                                consumedMaterials: cons,
                                needVehicle: needVehicle,
                                driverId: driver?.id ?? '',
                                driverName: driver?.name ?? '',
                                driverWage: double.tryParse(driverWageC.text) ?? 0,
                                transportNotes: transportNotesC.text,
                                notes: notesC.text,
                              );
                        } else {
                        final proc = SiteProcedure(
                          projectId: widget.project.id,
                          dailyLogId: widget.log.id,
                          kind: widget.kind,
                          workerId: worker?.id ?? '',
                          workerName: worker?.name ?? '',
                          workerWage:
                              double.tryParse(workerWageC.text) ?? 0,
                          masterId: master?.id ?? '',
                          masterName: master?.name ?? '',
                          contractType: contractType,
                          dailyRate:
                              double.tryParse(dailyRateC.text) ?? 0,
                          description: isWorker
                              ? notesC.text
                              : (contractType ==
                                      MasterContractType.lumpSum
                                  ? descC.text
                                  : notesC.text),
                          agreedTotal:
                              double.tryParse(agreedC.text) ?? 0,
                          agreementPerUnit: agreeUnitC.text,
                          consumedMaterials: cons,
                          needVehicle: needVehicle,
                          driverId: driver?.id ?? '',
                          driverName: driver?.name ?? '',
                          driverWage:
                              double.tryParse(driverWageC.text) ?? 0,
                          transportNotes: transportNotesC.text,
                          notes: isWorker
                              ? notesC.text
                              : notesC.text,
                          date: widget.log.date,
                          currency: widget.project.currency,
                        );
                        await ref
                            .read(siteServiceProvider)
                            .addSiteProcedure(proc);
                        }
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                                  content: Text('$e',
                                      style: GoogleFonts.cairo()),
                                  backgroundColor: AppColors.error));
                        }
                      } finally {
                        if (mounted) setState(() => saving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepNavy),
              child: Text(saving ? 'جاري الحفظ...' : (isEdit ? 'حفظ التعديل' : 'حفظ الإجرائية'),
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _contractOption(MasterContractType t, String label, IconData icon) {
    final sel = contractType == t;
    return InkWell(
      onTap: () => setState(() => contractType = t),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppColors.deepNavy : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel ? AppColors.deepNavy : AppColors.border,
              width: sel ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon,
              color: sel ? Colors.white : AppColors.textSecondary,
              size: 20),
          Text(label,
              style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: sel ? Colors.white : AppColors.textPrimary)),
        ]),
      ),
    );
  }
}
