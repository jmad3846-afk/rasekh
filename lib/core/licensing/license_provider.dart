import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'license_service.dart';

final licenseServiceProvider = Provider<LicenseService>((ref) => LicenseService());

final licenseStatusProvider = FutureProvider<LicenseStatus>((ref) async {
  final svc = ref.watch(licenseServiceProvider);
  return svc.checkLicenseStatus();
});

final deviceIdProvider = FutureProvider<String>((ref) async {
  final svc = ref.watch(licenseServiceProvider);
  return svc.getDeviceId();
});

final expiryDateProvider = FutureProvider<DateTime?>((ref) async {
  final svc = ref.watch(licenseServiceProvider);
  return svc.getExpiryDate();
});

/// For ActivationScreen: holds validation message
class ActivationNotifier extends StateNotifier<AsyncValue<LicenseValidationResult?>> {
  final LicenseService _svc;
  ActivationNotifier(this._svc) : super(const AsyncData(null));

  Future<void> activate(String code) async {
    state = const AsyncLoading();
    try {
      final res = await _svc.verifyAndActivate(code);
      state = AsyncData(res);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void reset() => state = const AsyncData(null);
}

final activationProvider = StateNotifierProvider<ActivationNotifier, AsyncValue<LicenseValidationResult?>>(
  (ref) => ActivationNotifier(ref.read(licenseServiceProvider)),
);
