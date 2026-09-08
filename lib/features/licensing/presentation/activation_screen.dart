import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/licensing/license_provider.dart';
import '../../../core/licensing/license_service.dart';

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});
  @override ConsumerState<ActivationScreen> createState() => _S();
}

class _S extends ConsumerState<ActivationScreen> {
  final _ctrl = TextEditingController();
  bool _obscureDeviceId = false;

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final deviceIdAsync = ref.watch(deviceIdProvider);
    final expiryAsync = ref.watch(expiryDateProvider);
    final activationState = ref.watch(activationProvider);

    final statusAsync = ref.watch(licenseStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.navyGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.12))),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.verified_user_rounded, size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text('تفعيل التطبيق', style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('النظام يعمل Offline بالكامل - التفعيل مرتبط بهذا الجهاز فقط', style: GoogleFonts.cairo(fontSize: 12, color: Colors.white70), textAlign: TextAlign.center),
                  ]),
                ),
                const SizedBox(height: 16),

                // Status banner
                statusAsync.when(
                  data: (s) {
                    String msg; Color bg; Color fg; IconData icon;
                    switch (s) {
                      case LicenseStatus.valid:
                        return const SizedBox.shrink();
                      case LicenseStatus.expired:
                        msg = 'الترخيص منتهي'; bg = AppColors.errorBg; fg = AppColors.error; icon = Icons.error_outline;
                        break;
                      case LicenseStatus.tampered:
                        msg = 'تم اكتشاف تلاعب بالوقت'; bg = AppColors.errorBg; fg = AppColors.error; icon = Icons.warning_amber_rounded;
                        break;
                      case LicenseStatus.invalid:
                        msg = 'كود غير صالح لهذا الجهاز'; bg = AppColors.errorBg; fg = AppColors.error; icon = Icons.block;
                        break;
                      case LicenseStatus.notActivated:
                        msg = 'التطبيق غير مفعل - أدخل كود التفعيل'; bg = AppColors.warningBg; fg = AppColors.goldDark; icon = Icons.lock_outline;
                    }
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: fg.withOpacity(0.3))),
                      child: Row(children:[ Icon(icon, color: fg, size: 18), const SizedBox(width:8), Expanded(child: Text(msg, style: GoogleFonts.cairo(fontSize:13, fontWeight: FontWeight.w700, color: fg)))]),
                    );
                  },
                  loading: ()=> const SizedBox.shrink(),
                  error: (_,__)=> const SizedBox.shrink(),
                ),
                // Show expiry if exists
                expiryAsync.maybeWhen(
                  data: (d) {
                    if (d == null) return const SizedBox.shrink();
                    final isExpired = DateTime.now().isAfter(d);
                    return Padding(
                      padding: const EdgeInsets.only(top:8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          isExpired ? 'منتهي منذ: ${d.toString().substring(0,10)}' : 'ينتهي في: ${d.toString().substring(0,10)}',
                          style: GoogleFonts.cairo(fontSize:12, color: isExpired ? AppColors.error : AppColors.success, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                  orElse: ()=> const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

                // Device ID card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0,4))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children:[
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.deepNavy, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.phone_android_rounded, color: Colors.white, size:18)),
                      const SizedBox(width:8),
                      Text('معرّف الجهاز (Device ID)', style: GoogleFonts.cairo(fontSize:13, fontWeight: FontWeight.w800, color: AppColors.deepNavy)),
                      const Spacer(),
                      IconButton(onPressed: ()=> setState(()=> _obscureDeviceId = !_obscureDeviceId), icon: Icon(_obscureDeviceId? Icons.visibility_off_outlined : Icons.visibility_outlined, size:18, color: AppColors.textSecondary)),
                    ]),
                    const SizedBox(height:8),
                    deviceIdAsync.when(
                      data: (id) => Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                        child: Row(children:[
                          Expanded(child: SelectableText(_obscureDeviceId ? '•' * 12 : id, style: GoogleFonts.cairo(fontSize:13, fontWeight: FontWeight.w700, color: AppColors.deepNavy))),
                          const SizedBox(width:8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: id));
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم نسخ Device ID', style: GoogleFonts.cairo()), backgroundColor: AppColors.success, duration: const Duration(seconds:1)));
                            },
                            icon: const Icon(Icons.copy_rounded, size:16),
                            label: Text('نسخ', style: GoogleFonts.cairo(fontSize:12, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal:14, vertical:8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          ),
                        ]),
                      ),
                      loading: ()=> const LinearProgressIndicator(),
                      error: (e,_)=> Text('خطأ: $e', style: GoogleFonts.cairo(color: AppColors.error, fontSize:12)),
                    ),
                    const SizedBox(height:8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal:10, vertical:8),
                      decoration: BoxDecoration(color: AppColors.goldLight, borderRadius: BorderRadius.circular(8)),
                      child: Row(children:[
                        const Icon(Icons.send_rounded, size:16, color: AppColors.goldDark),
                        const SizedBox(width:6),
                        Expanded(child: Text('أرسل هذا المعرف للمسؤول عبر واتساب/تيليجرام ليُنشئ لك كود التفعيل', style: GoogleFonts.cairo(fontSize:11, color: AppColors.goldDark))),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // Activation input card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                    Text('كود التفعيل', style: GoogleFonts.cairo(fontSize:13, fontWeight: FontWeight.w800)),
                    const SizedBox(height:4),
                    Text('الصيغة: YYYY-MM-DD-XXXXXXXXXX  (مثال: 2027-09-08-A1B2C3D4E5)', style: GoogleFonts.cairo(fontSize:11, color: AppColors.textSecondary)),
                    const SizedBox(height:10),
                    TextField(
                      controller: _ctrl,
                      textCapitalization: TextCapitalization.characters,
                      style: GoogleFonts.cairo(fontSize:14, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                      decoration: InputDecoration(
                        hintText: '2027-09-08-**********',
                        hintStyle: GoogleFonts.cairo(color: Colors.grey[400], fontSize:13),
                        prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppColors.deepNavy),
                        suffixIcon: _ctrl.text.isNotEmpty ? IconButton(onPressed: (){ _ctrl.clear(); setState((){}); ref.read(activationProvider.notifier).reset(); }, icon: const Icon(Icons.clear_rounded, size:18)) : null,
                      ),
                      onChanged: (_) => setState((){}),
                      onSubmitted: (_) => _activate(),
                    ),
                    const SizedBox(height:10),
                    // Inline feedback
                    activationState.when(
                      data: (res) {
                        if (res == null) return const SizedBox.shrink();
                        final isOk = res.isValid;
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: isOk ? AppColors.successBg : AppColors.errorBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: isOk ? AppColors.success : AppColors.error, width:0.6)),
                          child: Row(children:[
                            Icon(isOk? Icons.check_circle_rounded : Icons.error_rounded, size:18, color: isOk? AppColors.success: AppColors.error),
                            const SizedBox(width:8),
                            Expanded(child: Text(isOk? 'تم التفعيل بنجاح! ينتهي في ${res.expiryStr}' : (res.errorMessage ?? 'خطأ'), style: GoogleFonts.cairo(fontSize:12, fontWeight: FontWeight.w700, color: isOk? AppColors.success: AppColors.error))),
                          ]),
                        );
                      },
                      loading: ()=> const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth:2))),
                      error: (e,_)=> Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(10)), child: Row(children:[const Icon(Icons.error, color: AppColors.error, size:18), const SizedBox(width:8), Expanded(child: Text('خطأ: $e', style: GoogleFonts.cairo(color: AppColors.error, fontSize:12))) ])),
                    ),
                    const SizedBox(height:14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: activationState.isLoading ? null : _activate,
                        icon: const Icon(Icons.lock_open_rounded),
                        label: Text('تفعيل التطبيق', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepNavy, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical:14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                    const SizedBox(height:8),
                    Center(child: Text('الكود مرتبط بهذا الجهاز فقط ولا يعمل على جهاز آخر', style: GoogleFonts.cairo(fontSize:11, color: AppColors.textSecondary))),
                  ]),
                ),
                const SizedBox(height: 14),
                // Footer
                Text('Factory Management • Offline Licensing v1.0', style: GoogleFonts.cairo(fontSize:11, color: Colors.white54)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _activate() async {
    final code = _ctrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('أدخل كود التفعيل أولاً', style: GoogleFonts.cairo()), backgroundColor: AppColors.error));
      return;
    }
    await ref.read(activationProvider.notifier).activate(code);
    final state = ref.read(activationProvider);
    state.whenData((res) async {
      if (res != null && res.isValid) {
        // Invalidate license status and navigate
        ref.invalidate(licenseStatusProvider);
        ref.invalidate(expiryDateProvider);
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          // Pop to gate will auto-route to AppShell
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_)=> const _PostActivateRedirect()), (r)=> false);
        }
      }
    });
  }
}

// Small helper to trigger gate re-check
class _PostActivateRedirect extends ConsumerWidget {
  const _PostActivateRedirect();
  @override Widget build(BuildContext context, WidgetRef ref) {
    // This will be replaced by LicenseGate in main.dart, but for standalone use show success
    return Scaffold(
      backgroundColor: AppColors.successBg,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
        const Icon(Icons.check_circle, size: 64, color: AppColors.success),
        const SizedBox(height:12),
        Text('تم التفعيل بنجاح', style: GoogleFonts.cairo(fontSize:18, fontWeight: FontWeight.w800, color: AppColors.success)),
        const SizedBox(height:8),
        ElevatedButton(onPressed: ()=> Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_)=> const ActivationScreen()), (r)=> false), child: Text('متابعة', style: GoogleFonts.cairo())),
      ])),
    );
  }
}
