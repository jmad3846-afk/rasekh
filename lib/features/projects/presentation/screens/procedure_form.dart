import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/project.dart';
import '../../data/models/procedure.dart';
import '../../logic/project_providers.dart';

class ProcedureFormScreen extends ConsumerStatefulWidget {
  final Project project;
  const ProcedureFormScreen({super.key, required this.project});
  @override ConsumerState<ProcedureFormScreen> createState()=> _S();
}
class _S extends ConsumerState<ProcedureFormScreen> {
  final _form=GlobalKey<FormState>();
  final title=TextEditingController(), desc=TextEditingController(), masterName=TextEditingController(), masterPhone=TextEditingController(), masterWage=TextEditingController();
  final supName=TextEditingController(), supPhone=TextEditingController(), supMat=TextEditingController(), supCost=TextEditingController();
  ProcedureStatus status=ProcedureStatus.pending;
  List<WorkshopWorker> workers=[];
  // worker temp
  final wName=TextEditingController(), wPhone=TextEditingController(), wCost=TextEditingController();

  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text('اجرائية جديدة - ${widget.project.location}', style: GoogleFonts.cairo(fontSize:14,fontWeight: FontWeight.w800))),
      body: Form(key:_form, child: ListView(padding: const EdgeInsets.all(16), children:[
        TextFormField(controller:title, decoration: const InputDecoration(labelText:'عنوان الاجرائية *', hintText:'أساس، لبخ، كهرباء، سيراميك'), validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:12),
        TextFormField(controller:desc, decoration: const InputDecoration(labelText:'وصف تفصيلي *'), maxLines:2, validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:12),
        DropdownButtonFormField<ProcedureStatus>(value:status, decoration: const InputDecoration(labelText:'الحالة'), items:[
          DropdownMenuItem(value:ProcedureStatus.pending, child: Text('قيد الانتظار (لا يضاف للذمة)', style: GoogleFonts.cairo())),
          DropdownMenuItem(value:ProcedureStatus.completed, child: Text('مكتملة (يضاف للذمة)', style: GoogleFonts.cairo())),
        ], onChanged:(v)=> setState(()=> status=v!)),
        const SizedBox(height:16),
        _section('أجرة المعلم'),
        TextFormField(controller:masterName, decoration: const InputDecoration(labelText:'اسم المعلم *'), validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:8),
        Row(children:[
          Expanded(child: TextFormField(controller:masterPhone, decoration: const InputDecoration(labelText:'هاتف المعلم *'), validator:(v)=> v!.isEmpty?'مطلوب':null)),
          const SizedBox(width:12),
          Expanded(child: TextFormField(controller:masterWage, decoration: const InputDecoration(labelText:'الأجرة *'), keyboardType: TextInputType.number, validator:(v)=> v!.isEmpty?'مطلوب':null)),
        ]),
        const SizedBox(height:16),
        _section('عمال الورشة'),
        if(workers.isNotEmpty) ...workers.map((w)=> ListTile(dense:true, title: Text('${w.name} - ${w.phone}', style: GoogleFonts.cairo(fontSize:13)), subtitle: Text('${w.cost.toStringAsFixed(0)} د.ع', style: GoogleFonts.cairo(fontSize:11)), trailing: IconButton(icon: const Icon(Icons.delete, size:18, color: AppColors.error), onPressed: ()=> setState(()=> workers.remove(w))))),
        Row(children:[
          Expanded(child: TextFormField(controller:wName, decoration: const InputDecoration(labelText:'اسم العامل', isDense:true))),
          const SizedBox(width:8),
          Expanded(child: TextFormField(controller:wPhone, decoration: const InputDecoration(labelText:'الهاتف', isDense:true))),
          const SizedBox(width:8),
          SizedBox(width:90, child: TextFormField(controller:wCost, decoration: const InputDecoration(labelText:'الأجرة', isDense:true), keyboardType: TextInputType.number)),
          IconButton(onPressed: (){
            if(wName.text.isEmpty||wCost.text.isEmpty) return;
            setState(()=> workers.add(WorkshopWorker(name:wName.text, phone:wPhone.text, cost: double.parse(wCost.text))));
            wName.clear(); wPhone.clear(); wCost.clear();
          }, icon: const Icon(Icons.add_circle, color: AppColors.deepNavy)),
        ]),
        const SizedBox(height:16),
        _section('المورد - المواد'),
        TextFormField(controller:supName, decoration: const InputDecoration(labelText:'اسم المورد *'), validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:8),
        TextFormField(controller:supPhone, decoration: const InputDecoration(labelText:'هاتف المورد *'), validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:8),
        TextFormField(controller:supMat, decoration: const InputDecoration(labelText:'المواد الموردة *', hintText:'سمنت 10 طن، رمل...'), validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:8),
        TextFormField(controller:supCost, decoration: const InputDecoration(labelText:'إجمالي تكلفة المواد *'), keyboardType: TextInputType.number, validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:20),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.goldLight, borderRadius: BorderRadius.circular(12)), child: Text('تنبيه: الإجمالي = أجرة المعلم + أجور العمال + المواد. المكتمل فقط يضاف لذمة العميل.', style: GoogleFonts.cairo(fontSize:11, color: AppColors.goldDark))),
        const SizedBox(height:16),
        SizedBox(width:double.infinity, child: ElevatedButton(onPressed: () async {
          if(!_form.currentState!.validate()) return;
          final proc = Procedure(
            projectId: widget.project.id, title: title.text, description: desc.text, status: status,
            masterName: masterName.text, masterPhone: masterPhone.text, masterWage: double.parse(masterWage.text),
            workers: workers, supplier: SupplierInfo(name: supName.text, phone: supPhone.text, materials: supMat.text, totalCost: double.parse(supCost.text)),
          );
          await ref.read(projectServiceProvider).addProcedure(proc);
          if(mounted) Navigator.pop(context);
        }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepNavy), child: Text('حفظ الاجرائية', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)))) ,
      ])),
    );
  }
  Widget _section(String t)=> Padding(padding: const EdgeInsets.only(bottom:8), child: Text(t, style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize:14, color: AppColors.deepNavy)));
}
