import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/licensing/license_provider.dart';

class TimeLockScreen extends ConsumerWidget {
  const TimeLockScreen({super.key});

  @override Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.navyGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.errorBg, shape: BoxShape.circle),
                    child: const Icon(Icons.access_time_filled_rounded, size: 48, color: AppColors.error),
                  ),
                  const SizedBox(height: 16),
                  Text('تم اكتشاف تلاعب بوقت النظام', style: GoogleFonts.cairo(fontSize:18, fontWeight: FontWeight.w800, color: AppColors.error), textAlign: TextAlign.center),
                  const SizedBox(height:8),
                  Text(
                    'System time tampering detected.\nPlease set the correct time to continue.',
                    style: GoogleFonts.cairo(fontSize:13, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height:10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      'قام النظام باكتشاف أن تاريخ الجهاز الحالي أقدم من آخر وقت تم فتح التطبيق فيه. هذه حماية لمنع تمديد الاشتراك عبر إرجاع الساعة.',
                      style: GoogleFonts.cairo(fontSize:12, color: AppColors.error, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height:16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Re-check time - user may have fixed it
                        final svc = ref.read(licenseServiceProvider);
                        // If time is now correct, the check will update lastOpened and return false
                        // We need to re-validate: if now >= lastOpened, tampering resolved
                        final stillTampered = await svc.checkTimeTampering();
                        if (!stillTampered) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إصلاح الوقت - جاري التحقق...', style: GoogleFonts.cairo()), backgroundColor: AppColors.success));
                          ref.invalidate(licenseStatusProvider);
                          // Let gate rebuild
                          await Future.delayed(const Duration(milliseconds:300));
                          if (context.mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_)=> const _RestartGatePlaceholder()), (r)=> false);
                        } else {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا يزال الوقت غير صحيح - اضبطه تلقائياً من الإعدادات', style: GoogleFonts.cairo()), backgroundColor: AppColors.error));
                        }
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text('إعادة التحقق', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepNavy, foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(height:8),
                  Text('نصيحة: فعّل "التاريخ والوقت التلقائي" في إعدادات الهاتف', style: GoogleFonts.cairo(fontSize:11, color: AppColors.textSecondary), textAlign: TextAlign.center),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RestartGatePlaceholder extends StatelessWidget {
  const _RestartGatePlaceholder();
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
