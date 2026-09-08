import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/licensing/license_provider.dart';
import '../../../core/licensing/license_service.dart';
import '../../../app.dart';
import 'activation_screen.dart';
import 'time_lock_screen.dart';

/// Root Navigation Guard — wrap MaterialApp home with this
class LicenseGate extends ConsumerStatefulWidget {
  const LicenseGate({super.key});
  @override ConsumerState<LicenseGate> createState() => _S();
}

class _S extends ConsumerState<LicenseGate> with WidgetsBindingObserver {
  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check time tampering on resume
      ref.read(licenseServiceProvider).onAppResume().then((tampered) {
        if (tampered) {
          ref.invalidate(licenseStatusProvider);
        } else {
          // Also refresh status in case license expired while paused
          ref.invalidate(licenseStatusProvider);
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
