import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/widgets.dart';
import '../logic/backup_service.dart';
import '../../../core/database/hive_init.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override State<BackupScreen> createState()=> _S();
}
class _S extends State<BackupScreen> {
  bool loading=false;
  String? lastPath;

  Future<void> _export() async {
    setState(()=> loading=true);
    try{
      final path = await BackupService.exportBackup(asZip: true);
      setState(()=> lastPath=path);
      if (!mounted) return;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الإلغاء', style: GoogleFonts.cairo())));
        return;
      }
      await showDialog(context: context, builder:(_)=> AlertDialog(
        title: Text('تم إنشاء النسخة بنجاح ✓', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: AppColors.success)),
        content: Text('تم الحفظ في:\n$path\n\nتحقق من وجود data.json + checksum.txt داخل ZIP.', style: GoogleFonts.cairo(fontSize:12)),
        actions:[ElevatedButton(onPressed: ()=> Navigator.pop(context), child: Text('حسناً', style: GoogleFonts.cairo()))],
      ));
    }catch(e){
      if(mounted) await showDialog(context: context, builder:(_)=> AlertDialog(
        title: Text('فشل التصدير', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: AppColors.error)),
        content: Text('$e', style: GoogleFonts.cairo(fontSize:13)),
        actions:[TextButton(onPressed: ()=> Navigator.pop(context), child: Text('إغلاق', style: GoogleFonts.cairo()))],
      ));
    } finally { if (mounted) setState(()=> loading=false); }
  }

  Future<void> _restore() async {
    final ok = await showDialog<bool>(context:context, builder:(_)=> AlertDialog(
      title: Text('تأكيد الاسترجاع', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
      content: Text('سيتم استبدال جميع البيانات الحالية بالنسخة الاحتياطية بعد التحقق من سلامتها. هل أنت متأكد؟', style: GoogleFonts.cairo()),
      actions:[
        TextButton(onPressed: ()=> Navigator.pop(context,false), child: Text('إلغاء', style: GoogleFonts.cairo())),
        ElevatedButton(onPressed: ()=> Navigator.pop(context,true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: Text('استرجاع', style: GoogleFonts.cairo(color: Colors.white))),
      ],
    ));
    if(ok!=true) return;
    setState(()=> loading=true);
    try{
      final res = await BackupService.restoreBackup();
      if (!mounted) return;
      if(res==RestoreResult.success) {
        await showDialog(context: context, builder:(_)=> AlertDialog(
          title: Text('تم الاسترجاع بنجاح ✓', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: AppColors.success)),
          content: Text('تم التحقق من data.json والـ checksum والروابط، واستعادة الصور لمجلد التطبيق. أعد تشغيل التطبيق لتحديث كل الشاشات.', style: GoogleFonts.cairo(fontSize:13)),
          actions:[ElevatedButton(onPressed: ()=> Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success), child: Text('حسناً', style: GoogleFonts.cairo(color: Colors.white)))],
        ));
      }
      if(res==RestoreResult.cancelled && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الإلغاء', style: GoogleFonts.cairo())));
    }catch(e){
      if(mounted) await showDialog(context: context, builder:(_)=> AlertDialog(
        title: Text('فشل الاسترجاع', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: AppColors.error)),
        content: SingleChildScrollView(child: Text('$e', style: GoogleFonts.cairo(fontSize:13))),
        actions:[TextButton(onPressed: ()=> Navigator.pop(context), child: Text('إغلاق', style: GoogleFonts.cairo()))],
      ));
    } finally { if (mounted) setState(()=> loading=false); }
  }

  @override Widget build(BuildContext context){
    final counts = {
      'المنتجات': HiveInit.products.length,
      'العملاء': HiveInit.customers.length,
      'الفواتير': HiveInit.invoices.length,
      'المشاريع': HiveInit.projects.length,
      'الاجرائيات': HiveInit.procedures.length,
      'الحركات المالية': HiveInit.transactions.length,
    };
    return Scaffold(
      appBar: AppBar(title: Text('النسخ الاحتياطي والأمان', style: GoogleFonts.cairo(fontWeight: FontWeight.w800))),
      body: Stack(children:[
        ListView(padding: const EdgeInsets.all(16), children:[
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: AppColors.navyGradient, borderRadius: BorderRadius.circular(16)), child: Row(children:[
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.shield_rounded, color: Colors.white, size:28)),
            const SizedBox(width:12),
            Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              Text('حماية البيانات - Offline First', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w800)),
              Text('يتم حفظ كل شيء محلياً. قم بتصدير نسخة مشفرة إلى SD/USB عبر OTG بانتظام.', style: GoogleFonts.cairo(color: Colors.white70, fontSize:11)),
            ])),
          ])),
          const SizedBox(height:16),
          GlassCard(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
            Text('ملخص البيانات الحالية', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            const SizedBox(height:12),
            Wrap(spacing:8, runSpacing:8, children: counts.entries.map((e)=> Container(padding: const EdgeInsets.symmetric(horizontal:12,vertical:8), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: Text('${e.key}: ${e.value}', style: GoogleFonts.cairo(fontSize:12, fontWeight: FontWeight.w600)))).toList()),
            const SizedBox(height:12),
            Text('صيغة التصدير: ZIP يحتوي data.json + checksum.txt + images/ مع روابط FK واضحة للتدقيق الخارجي', style: GoogleFonts.cairo(fontSize:11, color: AppColors.textSecondary)),
            Text('مثال: Factory_Backup_2026-09-08_1430.zip', style: GoogleFonts.cairo(fontSize:11, color: AppColors.goldDark, fontWeight: FontWeight.w700)),
          ])),
          const SizedBox(height:16),
          GlassCard(child: Column(children:[
            SizedBox(width:double.infinity, child: ElevatedButton.icon(onPressed: loading?null:_export, icon: const Icon(Icons.backup_outlined), label: Text('تصدير نسخة كاملة (USB/SD)', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepNavy, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical:14)))),
            const SizedBox(height:8),
            Text('سيطلب منك اختيار المجلد (SD Card أو USB OTG) عبر SAF', style: GoogleFonts.cairo(fontSize:11, color: AppColors.textSecondary), textAlign: TextAlign.center),
            if(lastPath!=null) Padding(padding: const EdgeInsets.only(top:8), child: Text('آخر حفظ: $lastPath', style: GoogleFonts.cairo(fontSize:11, color: AppColors.success))),
            const Divider(height:24),
            SizedBox(width:double.infinity, child: ElevatedButton.icon(onPressed: loading?null:_restore, icon: const Icon(Icons.restore), label: Text('استرجاع نسخة احتياطية', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical:14)))),
            const SizedBox(height:8),
            Text('يتم التحقق تلقائياً من checksum و FK قبل الكتابة', style: GoogleFonts.cairo(fontSize:11, color: AppColors.textSecondary), textAlign: TextAlign.center),
          ])),
          const SizedBox(height:16),
          GlassCard(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
            Text('مخطط JSON (للتدقيق الخارجي)', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            const SizedBox(height:8),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)), child: Text(
              '{\n  "metadata": {"version":"1.0","createdAt":"ISO8601"},\n  "products": [...],\n  "customers": [{"id":"uuid PK"}],\n  "invoices": [{"customerId":"FK -> customers.id"}],\n  "projects": [{"clientId":"FK"}],\n  "procedures": [{"projectId":"FK -> projects.id"}],\n  "transactions": [{"partyId":"FK","source":"human readable"}]\n}',
              style: GoogleFonts.cairo(fontSize:11, color: AppColors.textSecondary),
            )),
          ])),
        ]),
        if(loading) Container(color: Colors.black.withOpacity(0.35), child: Center(child: GlassCard(child: Column(mainAxisSize:MainAxisSize.min, children:[
          const CircularProgressIndicator(color: AppColors.gold),
          const SizedBox(height:12),
          Text('جاري المعالجة...', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          Text('يرجى عدم إغلاق التطبيق', style: GoogleFonts.cairo(fontSize:11,color: AppColors.textSecondary)),
        ])))),
      ]),
    );
  }
}
