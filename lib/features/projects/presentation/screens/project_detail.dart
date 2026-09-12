import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/widgets.dart';
import '../../../../core/theme/finance_widgets.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/services/image_service.dart';
import '../../../../core/database/hive_init.dart';
import '../../data/models/project.dart';
import '../../data/models/procedure.dart';
import '../../logic/project_providers.dart';
import '../../logic/site_providers.dart';
import 'required_materials_screen.dart';
import 'daily_logs_screen.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final Project project;
  /// 0 = scroll to materials shortcut, 1 = daily logs (used by dashboard quick nav).
  final int initialTab;
  const ProjectDetailScreen({super.key, required this.project, this.initialTab = 1});

  @override Widget build(BuildContext context, WidgetRef ref){
    final procsAsync = ref.watch(proceduresProvider(project.id));
    final projectsAsync = ref.watch(projectsProvider);
    final liveProject = projectsAsync.maybeWhen(
      data: (list) => list.firstWhere((p)=> p.id==project.id, orElse: ()=> project),
      orElse: ()=> project,
    );
    ref.watch(dailyLogsProvider(project.id));
    ref.watch(requiredMaterialsProvider(project.id));
    final dailyCount = HiveInit.dailyLogs.values.where((d)=> d.projectId == project.id).length;
    final matCount = HiveInit.requiredMaterials.values.where((m)=> m.projectId == project.id).length;
    final siteTotal = HiveInit.siteProcedures.values
        .where((p)=> p.projectId == project.id)
        .fold(0.0, (s, e)=> s + e.totalCost);

    return Scaffold(
      appBar: AppBar(title: Text(liveProject.location, style: GoogleFonts.cairo(fontWeight: FontWeight.w800)), flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.navyGradient)), actions: [
        Padding(padding: const EdgeInsets.symmetric(vertical:12, horizontal:4), child: CurrencyBadge(liveProject.currency, dark: true)),
        const SizedBox(width:8),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children:[
        GlassCard(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Row(children:[Expanded(child: Text(liveProject.clientName, style: GoogleFonts.cairo(fontWeight: FontWeight.w800))), Text(liveProject.clientPhone, style: GoogleFonts.cairo(color: AppColors.textSecondary))]),
          Text('${liveProject.totalArea} م² • ${liveProject.buildingArea} م² بناء • ${liveProject.roomCount} غرف', style: GoogleFonts.cairo(fontSize:12,color: AppColors.textSecondary)),
          const SizedBox(height:8),
          Text(liveProject.description, style: GoogleFonts.cairo(fontSize:13)),
          const SizedBox(height:12),
          Text('صور العقد (${liveProject.photoPaths.length})', style: GoogleFonts.cairo(fontSize:12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height:8),
          if(liveProject.photoPaths.isEmpty)
            Container(
              height: 90,
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
                const Icon(Icons.image_not_supported_outlined, color: Color(0xFF94A3B8)),
                const SizedBox(height:4),
                Text('لا توجد صور مرفقة', style: GoogleFonts.cairo(fontSize:12, color: AppColors.textSecondary)),
              ])),
            )
          else
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: liveProject.photoPaths.length,
                separatorBuilder:(_,__)=> const SizedBox(width:8),
                itemBuilder:(_,i){
                  final path = liveProject.photoPaths[i];
                  return SafeImageFile(
                    path: path, width: 130, height: 100, borderRadius: 10,
                    onTap: ()=> showImageViewer(context, liveProject.photoPaths, i),
                  );
                },
              ),
            ),
          const Divider(height:24),
          Row(children:[
            _stat('الإجمالي', Money.withCurrency(liveProject.totalCost, liveProject.currency), AppColors.deepNavy),
            _stat('مكتمل', Money.withCurrency(liveProject.completedCost, liveProject.currency), AppColors.success),
            _stat('معلق', Money.withCurrency(liveProject.totalCost-liveProject.completedCost, liveProject.currency), AppColors.warning),
          ]),
          if (siteTotal > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('إجمالي اليوميات: ${Money.withCurrency(siteTotal, liveProject.currency)}',
                  style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.goldDark)),
            ),
        ])),
        const SizedBox(height: 16),
        // ── Req #11: entry points ──
        Row(children:[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder:(_)=> RequiredMaterialsScreen(project: liveProject))),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.white),
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              label: Text('المواد اللازمة ($matCount)', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder:(_)=> DailyLogsScreen(project: liveProject))),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepNavy, foregroundColor: Colors.white),
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text('يوميات تعهد ($dailyCount)', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.goldLight, borderRadius: BorderRadius.circular(10)),
          child: Text('الإجرائيات الجديدة تضاف حصراً داخل يومية محددة (زر يوميات تعهد).',
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.goldDark))),
        const SizedBox(height: 16),
        Row(children:[
          Text('الإجرائيات القديمة (للأرشيف)', style: GoogleFonts.cairo(fontSize: 14,fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        procsAsync.when(
          data:(procs){
            if(procs.isEmpty) return GlassCard(child: Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('لا توجد اجرائيات قديمة', style: GoogleFonts.cairo(color: AppColors.textSecondary), textAlign: TextAlign.center))));
            return Column(children: procs.map((pr)=> _procedureCard(context, ref, pr)).toList());
          },
          loading: ()=> const Center(child: CircularProgressIndicator()),
          error:(e,s)=> Text('$e'),
        )
      ]),
    );
  }
  Widget _stat(String label, String value, Color color){
    return Expanded(child: Column(children:[
      Text(label, style: GoogleFonts.cairo(fontSize:11,color: AppColors.textSecondary)),
      Text(value, style: GoogleFonts.cairo(fontSize:13,fontWeight: FontWeight.w800, color: color)),
    ]));
  }
  Widget _procedureCard(BuildContext context, WidgetRef ref, Procedure pr){
    final cur = pr.currency;
    return Padding(padding: const EdgeInsets.only(bottom:12), child: GlassCard(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
      Row(children:[
        Expanded(child: Text(pr.title, style: GoogleFonts.cairo(fontWeight: FontWeight.w800))),
        CurrencyBadge(cur),
        const SizedBox(width:6),
        StatusBadge(label: pr.status==ProcedureStatus.completed?'مكتملة':'قيد الانتظار', isCompleted: pr.status==ProcedureStatus.completed),
      ]),
      Text(pr.description, style: GoogleFonts.cairo(fontSize:12,color: AppColors.textSecondary)),
      const Divider(height:16),
      Text('المعلم: ${pr.masterName} • ${Money.withCurrency(pr.masterWage, cur)}', style: GoogleFonts.cairo(fontSize:12, fontWeight: FontWeight.w600)),
      Text('العمال: ${pr.workers.map((w)=> '${w.name} (${Money.withCurrency(w.cost, cur)})').join('، ')}', style: GoogleFonts.cairo(fontSize:11, color: AppColors.textSecondary)),
      Text('المورد: ${pr.supplier.name} • ${pr.supplier.materials} • ${Money.withCurrency(pr.supplier.totalCost, cur)}', style: GoogleFonts.cairo(fontSize:11, color: AppColors.textSecondary)),
      const SizedBox(height:8),
      Row(children:[
        Flexible(child: Text('الإجمالي ${Money.withCurrency(pr.totalCost, cur)}', style: GoogleFonts.cairo(fontSize:12,fontWeight: FontWeight.w800, color: AppColors.deepNavy))),
        const Spacer(),
        IconButton(onPressed: () async {
          final ok = await confirmDelete(context, title: 'حذف الاجرائية؟',
              message: 'هل أنت متأكد من حذف هذه الإجرائية؟ سيتم تعديل الإجماليات والمالية.');
          if(ok==true) await ref.read(projectServiceProvider).deleteProcedure(pr);
        }, icon: const Icon(Icons.delete_outline, color: AppColors.error, size:20)),
      ])
    ])));
  }
}
