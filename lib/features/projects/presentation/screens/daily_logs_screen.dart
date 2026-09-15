import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/widgets.dart';
import '../../../../core/theme/finance_widgets.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/database/hive_init.dart';
import '../../logic/site_providers.dart';
import '../../data/models/project.dart';
import '../../data/models/site_materials.dart';
import '../../data/models/site_procedure.dart';
import 'site_procedure_form.dart';

/// Req #11B: project daily logs — procedures live ONLY inside a log.
class DailyLogsScreen extends ConsumerWidget {
  final Project project;
  const DailyLogsScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dailyLogsProvider(project.id));
    return Scaffold(
      appBar: AppBar(
          title: Text('يوميات تعهد - ${project.location}',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800, fontSize: 15))),
      body: async.when(
        data: (logs) {
          if (logs.isEmpty) {
            return Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                        'لا توجد يوميات بعد.\nأنشئ يومية ثم أضف إجرائيات العمال/المعلمين داخلها.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                            color: AppColors.textSecondary))));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final log = logs[i];
              final procs = HiveInit.siteProcedures.values
                  .where((p) => p.dailyLogId == log.id)
                  .toList();
              final total =
                  procs.fold(0.0, (s, e) => s + e.totalCost);
              return GlassCard(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DailyLogDetailScreen(
                            project: project, log: log))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(
                                log.title.isEmpty
                                    ? 'يومية ${log.date.toString().substring(0, 10)}'
                                    : log.title,
                                style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w800),
                                overflow: TextOverflow.ellipsis)),
                        Text(log.date.toString().substring(0, 10),
                            style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ]),
                      if (log.notes.isNotEmpty)
                        Text(log.notes,
                            style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                          '${procs.length} إجرائية • ${Money.withCurrency(total, project.currency)}',
                          style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepNavy)),
                    ]),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.deepNavy, foregroundColor: Colors.white,
        onPressed: () => _createLog(context, ref),
        icon: const Icon(Icons.add),
        label: Text('يومية جديدة', style: GoogleFonts.cairo()),
      ),
    );
  }

  void _createLog(BuildContext context, WidgetRef ref) {
    final titleC = TextEditingController();
    final notesC = TextEditingController();
    DateTime date = DateTime.now();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('يومية جديدة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleC,
                decoration:
                    const InputDecoration(labelText: 'عنوان اليومية')),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final p = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2040));
                if (p != null) setD(() => date = p);
              },
              child: InputDecorator(
                  decoration:
                      const InputDecoration(labelText: 'التاريخ'),
                  child: Text(date.toString().substring(0, 10),
                      style: GoogleFonts.cairo(fontSize: 13))),
            ),
            const SizedBox(height: 8),
            TextField(controller: notesC,
                decoration:
                    const InputDecoration(labelText: 'ملاحظات'),
                maxLines: 2),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo())),
            ElevatedButton(
              onPressed: () async {
                await ref.read(siteServiceProvider).addLog(
                    projectId: project.id,
                    date: date,
                    title: titleC.text,
                    notes: notesC.text);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('إنشاء', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyLogDetailScreen extends ConsumerWidget {
  final Project project;
  final DailyLog log;
  const DailyLogDetailScreen(
      {super.key, required this.project, required this.log});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(siteProceduresProvider(log.id));
    final procs = HiveInit.siteProcedures.values
        .where((p) => p.dailyLogId == log.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final total = procs.fold(0.0, (s, e) => s + e.totalCost);
    return Scaffold(
      appBar: AppBar(
          title: Text(
              log.title.isEmpty ? 'تفاصيل اليومية' : log.title,
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              tooltip: 'حذف اليومية',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirmDelete(context,
                    title: 'حذف اليومية؟',
                    message:
                        'سيتم حذف ${procs.length} إجرائية وعكس قيودها المالية وإرجاع المواد المستهلكة.');
                if (ok) {
                  await ref.read(siteServiceProvider).deleteLog(log);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        GlassCard(
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              Text('إجمالي اليومية (${procs.length})',
                  style: GoogleFonts.cairo(
                      color: AppColors.textSecondary, fontSize: 12)),
              Text(Money.withCurrency(total, project.currency),
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ])),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SiteProcedureFormScreen(
                          project: project,
                          log: log,
                          kind: SiteProcedureKind.worker))),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4)),
              icon: const Icon(Icons.groups, size: 16),
              label: Text('إجرائية عامل',
                  style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SiteProcedureFormScreen(
                          project: project,
                          log: log,
                          kind: SiteProcedureKind.master))),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4)),
              icon: const Icon(Icons.engineering, size: 16),
              label: Text('إجرائية معلم',
                  style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SiteProcedureFormScreen(
                          project: project,
                          log: log,
                          kind: SiteProcedureKind.cashExpense))),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488), // Teal/emerald
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4)),
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: Text('مصروف نقدي',
                  style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (procs.isEmpty)
          GlassCard(
              child: Center(
                  child: Text('لا توجد إجرائيات أو مصروفات في هذه اليومية',
                      style: GoogleFonts.cairo(
                          color: AppColors.textSecondary)))),
        for (final p in procs) _procCard(context, ref, p),
      ]),
    );
  }

  Widget _procCard(BuildContext context, WidgetRef ref, SiteProcedure p) {
    final isCash = p.kind == SiteProcedureKind.cashExpense;
    final isWorker = p.kind == SiteProcedureKind.worker;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: isCash
                          ? const Color(0xFF0D9488)
                          : isWorker
                              ? AppColors.deepNavy
                              : AppColors.goldLight,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                      isCash
                          ? 'مصروف نقدي'
                          : isWorker
                              ? 'عامل'
                              : 'معلم',
                      style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: (isCash || isWorker)
                              ? Colors.white
                              : AppColors.goldDark))),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      isCash
                          ? (p.description.isNotEmpty ? p.description : 'مصروف نقدي')
                          : p.personName,
                      style:
                          GoogleFonts.cairo(fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis)),
              CurrencyBadge(p.currency),
            ]),
            if (!isCash && p.description.isNotEmpty)
              Text(p.description,
                  style: GoogleFonts.cairo(
                      fontSize: 12, color: AppColors.textSecondary)),
            if (!isCash &&
                !isWorker &&
                p.contractType == MasterContractType.lumpSum) ...[
              Text('مقطوع: ${Money.withCurrency(p.agreedTotal, p.currency)}',
                  style: GoogleFonts.cairo(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              if (p.agreementPerUnit.isNotEmpty)
                Text('متفق عالوحدة: ${p.agreementPerUnit} (معلومة)',
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic)),
            ],
            if (!isCash && p.consumedMaterials.isNotEmpty)
              Text(
                  'مواد مستهلكة: ${p.consumedMaterials.map((c) => '${c.materialName} ×${c.quantity}').join('، ')}',
                  style: GoogleFonts.cairo(
                      fontSize: 11, color: AppColors.textSecondary)),
            if (!isCash && p.needVehicle)
              Text(
                  'نقل: ${p.driverName} • ${Money.withCurrency(p.driverWage, p.currency)}${p.transportNotes.isEmpty ? '' : ' • ${p.transportNotes}'}',
                  style: GoogleFonts.cairo(
                      fontSize: 11, color: AppColors.goldDark)),
            if (p.notes.isNotEmpty)
              Text('ملاحظات: ${p.notes}',
                  style: GoogleFonts.cairo(fontSize: 11)),
            const SizedBox(height: 6),
            Row(children: [
              Text(
                  'الإجمالي ${Money.withCurrency(p.totalCost, p.currency)}',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepNavy)),
              const Spacer(),
              IconButton(
                tooltip: 'تعديل',
                icon: const Icon(Icons.edit_outlined,
                    color: AppColors.deepNavy, size: 20),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => SiteProcedureFormScreen(
                            project: project,
                            log: log,
                            kind: p.kind,
                            existing: p))),
              ),
              IconButton(
                tooltip: 'حذف',
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.error, size: 20),
                onPressed: () async {
                  final ok = await confirmDelete(context,
                      title: 'حذف الإدخال؟',
                      message:
                          'سيتم عكس القيد المالي وإلغاء هذا المصروف/الإجرائية.');
                  if (ok) {
                    await ref
                        .read(siteServiceProvider)
                        .deleteSiteProcedure(p);
                  }
                },
              ),
            ]),
          ])),
    );
  }
}
