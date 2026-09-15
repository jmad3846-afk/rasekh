import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/licensing/license_provider.dart';
import '../../../core/licensing/license_service.dart';
import '../../../app.dart';
import 'activation_screen.dart';
import 'time_lock_screen.dart';

/// Root Navigation Guard — wrap MaterialApp home with this.
/// Enforces strict expiry: 23:59:59 comparison + resume + periodic re-check.
class LicenseGate extends ConsumerStatefulWidget {
  const LicenseGate({super.key});
  @override ConsumerState<LicenseGate> createState() => _S();
}

class _S extends ConsumerState<LicenseGate> with WidgetsBindingObserver {
  Timer? _timer;

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Periodic enforcement: if expiry passes while app is open, block instantly.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;
      final licensed = await ref.read(licenseServiceProvider).isAppLicensed();
      if (!licensed) {
        ref.invalidate(licenseStatusProvider);
      }
    });
  }

  @override void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Immediately validate on foreground: tamper + strict expiry.
      ref.read(licenseServiceProvider).onAppResume().then((tampered) async {
        if (!mounted) return;
        if (tampered) {
          ref.invalidate(licenseStatusProvider);
        } else {
          // Also refresh status in case license expired while paused.
          final licensed =
              await ref.read(licenseServiceProvider).isAppLicensed();
          if (!licensed || mounted) {
            ref.invalidate(licenseStatusProvider);
          }
        }
      });
    }
  }

  @override Widget build(BuildContext context) {
    final statusAsync = ref.watch(licenseStatusProvider);

    return statusAsync.when(
      data: (status) {
        switch (status) {
          case LicenseStatus.valid:
            return const AppShell();
          case LicenseStatus.tampered:
            return const TimeLockScreen();
          case LicenseStatus.expired:
          case LicenseStatus.notActivated:
          case LicenseStatus.invalid:
            return const ActivationScreen();
        }
      },
      loading: () => const Scaffold(
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
          CircularProgressIndicator(),
          SizedBox(height:12),
          Text('جاري التحقق من الترخيص...'),
        ])),
      ),
      error: (e, st) => Scaffold(
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
          const Icon(Icons.error_outline, size:48, color: Colors.red),
          const SizedBox(height:12),
          Text('خطأ في التحقق: $e', textAlign: TextAlign.center),
          const SizedBox(height:12),
          ElevatedButton(onPressed: ()=> ref.invalidate(licenseStatusProvider), child: const Text('إعادة المحاولة')),
        ]))),
      ),
    );
  }
}
