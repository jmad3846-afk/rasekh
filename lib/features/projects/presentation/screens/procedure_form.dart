import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/money.dart';
import '../../data/models/project.dart';
import '../../data/models/procedure.dart';
import '../../logic/project_providers.dart';

class ProcedureFormScreen extends ConsumerStatefulWidget {
  final Project project;
  final Procedure? procedure; // null = create, non-null = edit
  const ProcedureFormScreen({super.key, required this.project, this.procedure});
  @override ConsumerState<ProcedureFormScreen> createState()=> _S();
}
class _S extends ConsumerState<ProcedureFormScreen> {
  final _form=GlobalKey<FormState>();
  late TextEditingController title, desc, masterName, masterPhone, masterWage;
  late TextEditingController supName, supPhone, supMat, supCost;
  late ProcedureStatus status;
  late DateTime date;
  List<WorkshopWorker> workers=[];
  // worker temp
  final wName=TextEditingController(), wPhone=TextEditingController(), wCost=TextEditingController();
  bool saving=false;

  bool get isEdit => widget.procedure != null;

  @override void initState() {
    super.initState();
    final p = widget.procedure;
    title = TextEditingController(text: p?.title ?? '');
    desc = TextEditingController(text: p?.description ?? '');
    masterName = TextEditingController(text: p?.masterName ?? '');
    masterPhone = TextEditingController(text: p?.masterPhone ?? '');
    masterWage = TextEditingController(text: p != null ? p.masterWage.toString() : '');
    supName = TextEditingController(text: p?.supplier.name ?? '');
    supPhone = TextEditingController(text: p?.supplier.phone ?? '');
    supMat = TextEditingController(text: p?.supplier.materials ?? '');
    supCost = TextEditingController(text: p != null ? p.supplier.totalCost.toString() : '');
    status = p?.status ?? ProcedureStatus.pending;
    date = p?.date ?? DateTime.now();
    if (p != null) {
      workers = p.workers.map((w) => WorkshopWorker(id: w.id, name: w.name, phone: w.phone, cost: w.cost)).toList();
    }
  }

  double get _liveTotal {
    final mw = double.tryParse(masterWage.text) ?? 0;
    final sc = double.tryParse(supCost.text) ?? 0;
    final wc = workers.fold(0.0, (s, w) => s + w.cost);
    return mw + wc + sc;
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'تعديل الاجرائية - ${widget.project.location}' : 'اجرائية جديدة - ${widget.project.location}', style: GoogleFonts.cairo(fontSize:14,fontWeight: FontWeight.w800))),
      body: Form(key:_form, child: ListView(padding: const EdgeInsets.all(16), children:[
        Container(padding: const EdgeInsets.symmetric(horizontal:12,vertical:8), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
          child: Row(children:[
            const Icon(Icons.currency_exchange, size:18, color: AppColors.goldDark),
            const SizedBox(width:8),
            Text('عملة المشروع:', style: GoogleFonts.cairo(fontSize:12, fontWeight: FontWeight.w700)),
            const SizedBox(width:8),
            _currencyBadge(widget.project.currency),
            const Spacer(),
            Text('تُورَّث تلقائياً', style: GoogleFonts.cairo(fontSize:11, color: AppColors.textSecondary)),
          ])),
        const SizedBox(height:12),
        TextFormField(controller:title, decoration: const InputDecoration(labelText:'عنوان الاجرائية *', hintText:'أساس، لبخ، كهرباء، سيراميك'), validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:12),
        TextFormField(controller:desc, decoration: const InputDecoration(labelText:'وصف تفصيلي *'), maxLines:2, validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child: DropdownButtonFormField<ProcedureStatus>(value:status, decoration: const InputDecoration(labelText:'الحالة'), items:[
            DropdownMenuItem(value:ProcedureStatus.pending, child: Text('قيد الانتظار (لا يضاف للذمة)', style: GoogleFonts.cairo())),
            DropdownMenuItem(value:ProcedureStatus.completed, child: Text('مكتملة (يضاف للذمة)', style: GoogleFonts.cairo())),
          ], onChanged:(v)=> setState(()=> status=v!))),
          const SizedBox(width:12),
          Expanded(child: InkWell(onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2040));
            if (picked != null) setState(()=> date = picked);
          }, child: InputDecorator(decoration: const InputDecoration(labelText:'التاريخ'), child: Text(date.toString().substring(0,10), style: GoogleFonts.cairo(fontSize:13))))),
        ]),
        const SizedBox(height:16),
        _section('أجرة المعلم'),
        TextFormField(controller:masterName, decoration: const InputDecoration(labelText:'اسم المعلم *'), validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:8),
        Row(children:[
          Expanded(child: TextFormField(controller:masterPhone, decoration: const InputDecoration(labelText:'هاتف المعلم *'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator:(v)=> v!.isEmpty?'مطلوب':null)),
          const SizedBox(width:12),
          Expanded(child: TextFormField(controller:masterWage, decoration: const InputDecoration(labelText:'الأجرة *'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))], onChanged:(_)=> setState((){}), validator:(v)=> v!.isEmpty?'مطلوب':null)),
        ]),
        const SizedBox(height:16),
        _section('عمال الورشة'),
        if(workers.isNotEmpty) ...workers.map((w)=> ListTile(dense:true, title: Text('${w.name} - ${w.phone}', style: GoogleFonts.cairo(fontSize:13)), subtitle: Text(Money.withCurrency(w.cost, widget.project.currency), style: GoogleFonts.cairo(fontSize:11)), trailing: IconButton(icon: const Icon(Icons.delete, size:18, color: AppColors.error), onPressed: ()=> setState(()=> workers.remove(w))))),
        Row(children:[
          Expanded(child: TextFormField(controller:wName, decoration: const InputDecoration(labelText:'اسم العامل', isDense:true))),
          const SizedBox(width:8),
          Expanded(child: TextFormField(controller:wPhone, decoration: const InputDecoration(labelText:'الهاتف', isDense:true), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
          const SizedBox(width:8),
          SizedBox(width:90, child: TextFormField(controller:wCost, decoration: const InputDecoration(labelText:'الأجرة', isDense:true), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))])),
          IconButton(onPressed: (){
            if(wName.text.isEmpty||wCost.text.isEmpty) return;
            setState(()=> workers.add(WorkshopWorker(name:wName.text, phone:wPhone.text, cost: double.tryParse(wCost.text) ?? 0)));
            wName.clear(); wPhone.clear(); wCost.clear();
          }, icon: const Icon(Icons.add_circle, color: AppColors.deepNavy)),
        ]),
        const SizedBox(height:16),
        _section('المورد - المواد'),
        TextFormField(controller:supName, decoration: const InputDecoration(labelText:'اسم المورد *'), validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:8),
        TextFormField(controller:supPhone, decoration: const InputDecoration(labelText:'هاتف المورد *'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:8),
        TextFormField(controller:supMat, decoration: const InputDecoration(labelText:'المواد الموردة *', hintText:'سمنت 10 طن، رمل...'), validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:8),
        TextFormField(controller:supCost, decoration: const InputDecoration(labelText:'إجمالي تكلفة المواد *'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))], onChanged:(_)=> setState((){}), validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:12),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
          Text('الإجمالي المحسوب', style: GoogleFonts.cairo(color: Colors.white70, fontSize:12)),
          Text(Money.withCurrency(_liveTotal, widget.project.currency), style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w800, fontSize:15)),
        ])),
        const SizedBox(height:8),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.goldLight, borderRadius: BorderRadius.circular(12)), child: Text(isEdit ? 'تنبيه: التعديل سيعكس القيود المالية القديمة ويكتب القيم الجديدة مرة واحدة فقط (بدون تكرار).' : 'تنبيه: الإجمالي = أجرة المعلم + أجور العمال + المواد. المكتمل فقط يضاف لذمة العميل.', style: GoogleFonts.cairo(fontSize:11, color: AppColors.goldDark))),
        const SizedBox(height:16),
        SizedBox(width:double.infinity, child: ElevatedButton(onPressed: saving ? null : () async {
          if(!_form.currentState!.validate()) return;
          setState(()=> saving = true);
          try {
            final workerList = List<WorkshopWorker>.from(workers);
            final supplier = SupplierInfo(name: supName.text, phone: supPhone.text, materials: supMat.text, totalCost: double.tryParse(supCost.text) ?? 0);
            if (isEdit) {
              await ref.read(projectServiceProvider).updateProcedure(
                proc: widget.procedure!,
                title: title.text, description: desc.text, status: status, date: date,
                masterName: masterName.text, masterPhone: masterPhone.text,
                masterWage: double.tryParse(masterWage.text) ?? 0,
                workers: workerList, supplier: supplier,
              );
              if(mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ التعديل وتحديث المالية', style: GoogleFonts.cairo()), backgroundColor: AppColors.success));
                Navigator.pop(context);
              }
            } else {
              final proc = Procedure(
                projectId: widget.project.id, title: title.text, description: desc.text, status: status, date: date,
                masterName: masterName.text, masterPhone: masterPhone.text, masterWage: double.tryParse(masterWage.text) ?? 0,
                workers: workerList, supplier: supplier, currency: widget.project.currency,
              );
              await ref.read(projectServiceProvider).addProcedure(proc);
              if(mounted) Navigator.pop(context);
            }
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: GoogleFonts.cairo()), backgroundColor: AppColors.error));
          } finally {
            if (mounted) setState(()=> saving = false);
          }
        }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepNavy), child: Text(saving ? 'جاري الحفظ...' : (isEdit ? 'حفظ التعديل' : 'حفظ الاجرائية'), style: GoogleFonts.cairo(fontWeight: FontWeight.w700)))) ,
      ])),
    );
  }
  Widget _section(String t)=> Padding(padding: const EdgeInsets.only(bottom:8), child: Text(t, style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize:14, color: AppColors.deepNavy)));
  Widget _currencyBadge(AppCurrency c) {
    final isUsd = c == AppCurrency.usd;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal:10, vertical:4),
      decoration: BoxDecoration(color: isUsd ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(20), border: Border.all(color: isUsd ? AppColors.success : AppColors.goldDark)),
      child: Text(isUsd ? '\$ USD' : 'ل.س SYP', style: GoogleFonts.cairo(fontSize:12, fontWeight: FontWeight.w800, color: isUsd ? AppColors.success : AppColors.goldDark)),
    );
  }
}
