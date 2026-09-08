import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/widgets.dart';
import '../../../../core/utils/money.dart';
import '../../logic/project_providers.dart';
import 'project_form.dart';
import 'project_detail.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref){
    final async = ref.watch(projectsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('قسم التعهدات', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)), actions: [IconButton(onPressed: (){}, icon: const Icon(Icons.search))]),
      body: async.when(
        data:(projects){
          if(projects.isEmpty) return Center(child: Column(mainAxisAlignment:MainAxisAlignment.center, children:[Icon(Icons.business_outlined,size:64,color: Colors.grey[300]), const SizedBox(height:12), Text('لا توجد مشاريع', style: GoogleFonts.cairo(color: AppColors.textSecondary)), const SizedBox(height:12), ElevatedButton(onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder:(_)=> const ProjectFormScreen())), child: Text('إنشاء تعهد جديد'))]));
          return ListView.separated(padding: const EdgeInsets.all(16), itemCount: projects.length, separatorBuilder: (_,__)=> const SizedBox(height:12), itemBuilder: (_,i){
            final p=projects[i];
            return GlassCard(onTap: ()=> Navigator.push(context, MaterialPageRoute(builder:(_)=> ProjectDetailScreen(project:p))), child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              Row(children:[
                Container(width:48,height:48,decoration: BoxDecoration(gradient: AppColors.navyGradient, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.location_city, color: Colors.white)),
                const SizedBox(width:12),
                Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
                  Text(p.location, style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize:14)),
                  Text('${p.clientName} • ${p.clientPhone}', style: GoogleFonts.cairo(fontSize:11,color: AppColors.textSecondary)),
                  Text('${p.totalArea} م² كلي • ${p.buildingArea} م² بناء • ${p.roomCount} غرف', style: GoogleFonts.cairo(fontSize:11, color: AppColors.textSecondary)),
                ])),
                PopupMenuButton(onSelected: (v) async {
                  if(v=='edit') Navigator.push(context, MaterialPageRoute(builder:(_)=> ProjectFormScreen(project:p)));
                  if(v=='delete'){ await ref.read(projectServiceProvider).delete(p); }
                }, itemBuilder: (_)=> [PopupMenuItem(value:'edit', child: Text('تعديل', style: GoogleFonts.cairo())), PopupMenuItem(value:'delete', child: Text('حذف', style: GoogleFonts.cairo(color: AppColors.error)))])
              ]),
              const SizedBox(height:12),
              LinearProgressIndicator(value: p.totalCost==0?0: p.completedCost/p.totalCost, color: AppColors.gold, backgroundColor: AppColors.divider),
              const SizedBox(height:8),
              Row(children:[
                Text('الإجمالي ${Money.format(p.totalCost)}', style: GoogleFonts.cairo(fontSize:11, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('مكتمل ${Money.format(p.completedCost)}', style: GoogleFonts.cairo(fontSize:11, color: AppColors.success)),
                const SizedBox(width:8),
                Text('معلق ${Money.format(p.totalCost - p.completedCost)}', style: GoogleFonts.cairo(fontSize:11, color: AppColors.warning)),
              ])
            ]));
          });
        },
        loading: ()=> const Center(child: CircularProgressIndicator()),
        error:(e,s)=> Center(child: Text('$e')),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder:(_)=> const ProjectFormScreen())), backgroundColor: AppColors.deepNavy, foregroundColor: Colors.white, icon: const Icon(Icons.add_business), label: Text('تعهد جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.w700))),
    );
  }
}
