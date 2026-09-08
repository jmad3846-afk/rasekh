import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/widgets.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/services/image_service.dart';
import '../../data/models/project.dart';
import '../../data/models/procedure.dart';
import '../../logic/project_providers.dart';
import 'procedure_form.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final Project project;
  const ProjectDetailScreen({super.key, required this.project});

  @override Widget build(BuildContext context, WidgetRef ref){
    final procsAsync = ref.watch(proceduresProvider(project.id));
    // Watch live project so photoPaths update reactively after edit
    final projectsAsync = ref.watch(projectsProvider);
    final liveProject = projectsAsync.maybeWhen(
      data: (list) => list.firstWhere((p)=> p.id==project.id, orElse: ()=> project),
      orElse: ()=> project,
    );

    return Scaffold(
      appBar: AppBar(title: Text(liveProject.location, style: GoogleFonts.cairo(fontWeight: FontWeight.w800)), flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.navyGradient))),
      body: ListView(padding: const EdgeInsets.all(16), children:[
        GlassCard(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Row(children:[Expanded(child: Text(liveProject.clientName, style: GoogleFonts.cairo(fontWeight: FontWeight.w800))), Text(liveProject.clientPhone, style: GoogleFonts.cairo(color: AppColors.textSecondary))]),
          Text('${liveProject.totalArea} م² • ${liveProject.buildingArea} م² بناء • ${liveProject.roomCount} غرف', style: GoogleFonts.cairo(fontSize:12,color: AppColors.textSecondary)),
          const SizedBox(height:8),
          Text(liveProject.description, style: GoogleFonts.cairo(fontSize:13)),
          const SizedBox(height:12),
          // Always show image area — with proper placeholder if empty
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
            _stat('الإجمالي', Money.format(liveProject.totalCost), AppColors.deepNavy),
            _stat('مكتمل', Money.format(liveProject.completedCost), AppColors.success),
            _stat('معلق', Money.format(liveProject.totalCost-liveProject.completedCost), AppColors.warning),
          ])
        ])),
        const SizedBox(height:16),
        Row(children:[
          Text('الإجرائيات', style: GoogleFonts.cairo(fontSize:16,fontWeight: FontWeight.w800)),
          const Spacer(),
          ElevatedButton.icon(onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder:(_)=> ProcedureFormScreen(project:liveProject))), icon: const Icon(Icons.add, size:18), label: Text('إضافة اجرائية', style: GoogleFonts.cairo(fontSize:12)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.white)),
        ]),
        const SizedBox(height:12),
        procsAsync.when(
          data:(procs){
            if(procs.isEmpty) return GlassCard(child: Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('لا توجد اجرائيات بعد - أضف أول اجرائية (أساس، لبخ، كهرباء...)', style: GoogleFonts.cairo(color: AppColors.textSecondary), textAlign: TextAlign.center))));
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
    return Padding(padding: const EdgeInsets.only(bottom:12), child: GlassCard(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
      Row(children:[
        Expanded(child: Text(pr.title, style: GoogleFonts.cairo(fontWeight: FontWeight.w800))),
        StatusBadge(label: pr.status==ProcedureStatus.completed?'مكتملة':'قيد الانتظار', isCompleted: pr.status==ProcedureStatus.completed),
      ]),
      Text(pr.description, style: GoogleFonts.cairo(fontSize:12,color: AppColors.textSecondary)),
      const Divider(height:16),
      Text('المعلم: ${pr.masterName} • ${Money.format(pr.masterWage)}', style: GoogleFonts.cairo(fontSize:12, fontWeight: FontWeight.w600)),
      Text('العمال: ${pr.workers.map((w)=> '${w.name} (${Money.format(w.cost)})').join('، ')}', style: GoogleFonts.cairo(fontSize:11, color: AppColors.textSecondary)),
      Text('المورد: ${pr.supplier.name} • ${pr.supplier.materials} • ${Money.format(pr.supplier.totalCost)}', style: GoogleFonts.cairo(fontSize:11, color: AppColors.textSecondary)),
      const SizedBox(height:8),
      Row(children:[
        Text('الإجمالي ${Money.format(pr.totalCost)}', style: GoogleFonts.cairo(fontSize:12,fontWeight: FontWeight.w800, color: AppColors.deepNavy)),
        const Spacer(),
        Switch(value: pr.status==ProcedureStatus.completed, activeThumbColor: AppColors.success, onChanged: (v) async {
          await ref.read(projectServiceProvider).updateProcedureStatus(pr, v?ProcedureStatus.completed:ProcedureStatus.pending);
        }),
        Text(pr.status==ProcedureStatus.completed?'مكتمل':'معلق', style: GoogleFonts.cairo(fontSize:11)),
        IconButton(onPressed: () async {
          final ok = await showDialog<bool>(context:context, builder:(_)=> AlertDialog(title: Text('حذف الاجرائية؟', style: GoogleFonts.cairo()), content: Text('سيتم تعديل الإجماليات والمالية', style: GoogleFonts.cairo()), actions:[TextButton(onPressed: ()=> Navigator.pop(context,false), child: Text('إلغاء', style: GoogleFonts.cairo())), TextButton(onPressed: ()=> Navigator.pop(context,true), child: Text('حذف', style: GoogleFonts.cairo(color: AppColors.error)))]));
          if(ok==true) await ref.read(projectServiceProvider).deleteProcedure(pr);
        }, icon: const Icon(Icons.delete_outline, color: AppColors.error, size:20)),
      ])
    ])));
  }
}
