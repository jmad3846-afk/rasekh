import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Offline-First HMAC License Service
/// Spec: Code = YYYY-MM-DD-SIGNATURE (10 hex uppercase)
/// Signature = HMAC-SHA256(_appSecret, "$deviceId|$expiryDateStr").hex[0:10].toUpperCase
class LicenseService {
  // ─────────────────────────────────────────────────────────────────
  // !! CHANGE THIS BEFORE PRODUCTION & KEEP IT PRIVATE !!
  // This is the sole secret that makes codes device-bound. If leaked,
  // anyone can forge licenses. Store it only in source obfuscation /
  // compile-time --dart-define if you need extra hardening.
  // ─────────────────────────────────────────────────────────────────
  static const String _appSecret = "FactoryProcurement_Secret_Core_Key_9988";

  static const _kLicenseCode = 'license_code';
  static const _kExpiryDate = 'expiry_date'; // YYYY-MM-DD
  static const _kLastOpened = 'last_opened_timestamp'; // millis
  static const _kCachedDeviceId = 'cached_device_id_fallback';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    wOptions: WindowsOptions(useBackwardCompatibility: true),
  );

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // For testing / injection
  LicenseService();

  /// Retrieves a stable, unique Device ID.
  /// Priority: platform hardware ID → fallback UUID cached in secure storage.
  Future<String> getDeviceId() async {
    try {
      if (kIsWeb) {
        // Web: no hardware ID, use cached UUID
        return _getOrCreateFallbackId();
      }
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        // androidId: 64-bit hex, stable per app signing key + device + user
        final id = info.id; // ANDROID_ID
        if (id != null && id.isNotEmpty && id != '9774d56d682e549c') {
          return id;
        }
        // Fallback to fingerprint / model+id hash
        final fallback = '${info.model}_${info.id}_${info.fingerprint}';
        if (fallback.length > 5) return fallback.replaceAll(' ', '_');
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        final id = info.identifierForVendor;
        if (id != null && id.isNotEmpty) return id;
      } else if (Platform.isWindows) {
        final info = await _deviceInfo.windowsInfo;
        // deviceId is stable GUID, else combine computerName + productId
        final id = info.deviceId;
        if (id.isNotEmpty) return id;
        return '${info.computerName}_${info.productId}'.replaceAll(' ', '_');
      } else if (Platform.isMacOS) {
        final info = await _deviceInfo.macOsInfo;
        return info.systemGUID ?? info.model;
      } else if (Platform.isLinux) {
        final info = await _deviceInfo.linuxInfo;
        return info.machineId ?? info.id;
      }
    } catch (e) {
      debugPrint('[LicenseService] getDeviceId error: $e');
    }
    return _getOrCreateFallbackId();
  }

  Future<String> _getOrCreateFallbackId() async {
    final cached = await _storage.read(key: _kCachedDeviceId);
    if (cached != null && cached.isNotEmpty) return cached;
    final newId = 'FALLBACK-${const Uuid().v4()}';
    await _storage.write(key: _kCachedDeviceId, value: newId);
    return newId;
  }

  // ── HMAC ──────────────────────────────────────────────────────────
  String generateSignature(String deviceId, String expiryDateStr) {
    final key = utf8.encode(_appSecret);
    final data = utf8.encode('$deviceId|$expiryDateStr');
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(data);
    // first 10 hex uppercase
    return digest.toString().substring(0, 10).toUpperCase();
  }

  String generateLicenseCode(String deviceId, String expiryDateStr) {
    final sig = generateSignature(deviceId, expiryDateStr);
    return '$expiryDateStr-$sig';
  }

  // ── Time Rollback Protection ──────────────────────────────────────
  /// Returns true if tampering detected: current < lastOpened - tolerance
  /// Tolerance 2 min handles minor NTP drift without false positives.
  Future<bool> checkTimeTampering() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastStr = await _storage.read(key: _kLastOpened);
    if (lastStr == null) {
      await _storage.write(key: _kLastOpened, value: now.toString());
      return false;
    }
    final last = int.tryParse(lastStr) ?? 0;
    const tolerance = 2 * 60 * 1000; // 2 min
    if (now < last - tolerance) {
      debugPrint('[LicenseService] TIME TAMPERING! now=$now last=$last');
      return true;
    }
    // Only move forward - never allow rollback to overwrite
    if (now > last) {
      await _storage.write(key: _kLastOpened, value: now.toString());
    }
    return false;
  }

  /// Call on every resume to update timestamp (and re-check)
  Future<bool> onAppResume() => checkTimeTampering();

  /// For admin/testing: forcibly set lastOpened (e.g., after correcting time)
  Future<void> resetLastOpenedToNow() async {
    await _storage.write(key: _kLastOpened, value: DateTime.now().millisecondsSinceEpoch.toString());
  }

  // ── Activation / Validation ───────────────────────────────────────
  static final _codeRegExp = RegExp(r'^\d{4}-\d{2}-\d{2}-[A-F0-9]{10}$');

  Future<LicenseValidationResult> verifyAndActivate(String enteredCode) async {
    final code = enteredCode.trim().toUpperCase();
    if (code.isEmpty) {
      return LicenseValidationResult.invalidFormat('الرجاء إدخال كود التفعيل');
    }
    if (!_codeRegExp.hasMatch(code)) {
      return LicenseValidationResult.invalidFormat('صيغة الكود غير صحيحة. الصيغة: YYYY-MM-DD-XXXXXXXXXX');
    }
    final expiryStr = code.substring(0, 10);
    final enteredSig = code.substring(11);

    DateTime expiryDate;
    try {
      expiryDate = DateTime.parse(expiryStr);
    } catch (_) {
      return LicenseValidationResult.invalidFormat('تاريخ الانتهاء غير صالح');
    }
    // Normalize to end of day 23:59:59 so code valid whole expiry day
    final expiryEnd = DateTime(expiryDate.year, expiryDate.month, expiryDate.day, 23, 59, 59);

    final deviceId = await getDeviceId();
    final expectedSig = generateSignature(deviceId, expiryStr);
    if (!_constantTimeEquals(enteredSig, expectedSig)) {
      return LicenseValidationResult.invalidSignature('الكود غير صالح لهذا الجهاز. تأكد من Device ID');
    }
    final now = DateTime.now();
    if (now.isAfter(expiryEnd)) {
      return LicenseValidationResult.expired('الكود منتهي الصلاحية في $expiryStr');
    }
    // Valid → persist securely
    await _storage.write(key: _kLicenseCode, value: code);
    await _storage.write(key: _kExpiryDate, value: expiryStr);
    // Also update lastOpened to now (successful activation proves time is forward)
    await _storage.write(key: _kLastOpened, value: now.millisecondsSinceEpoch.toString());
    return LicenseValidationResult.valid(expiryDate: expiryEnd, expiryStr: expiryStr);
  }

  Future<LicenseStatus> checkLicenseStatus() async {
    // Time tampering takes precedence
    if (await checkTimeTampering()) return LicenseStatus.tampered;

    final code = await _storage.read(key: _kLicenseCode);
    final expiryStr = await _storage.read(key: _kExpiryDate);
    if (code == null || expiryStr == null) return LicenseStatus.notActivated;

    // Re-validate signature in case device changed or code edited
    final deviceId = await getDeviceId();
    final expectedSig = generateSignature(deviceId, expiryStr);
    final expectedCode = '$expiryStr-$expectedSig';
    if (code.trim().toUpperCase() != expectedCode) {
      return LicenseStatus.invalid;
    }
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return LicenseStatus.invalid;
    final expiryEnd = DateTime(expiry.year, expiry.month, expiry.day, 23, 59, 59);
    if (DateTime.now().isAfter(expiryEnd)) return LicenseStatus.expired;

    return LicenseStatus.valid;
  }

  Future<DateTime?> getExpiryDate() async {
    final s = await _storage.read(key: _kExpiryDate);
    if (s == null) return null;
    try {
      final d = DateTime.parse(s);
      return DateTime(d.year, d.month, d.day, 23, 59, 59);
    } catch (_) { return null; }
  }

  Future<String?> getStoredLicense() => _storage.read(key: _kLicenseCode);

  Future<void> clearLicense() async {
    await _storage.delete(key: _kLicenseCode);
    await _storage.delete(key: _kExpiryDate);
  }

  // Constant-time compare to mitigate timing attacks (offline, but good practice)
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

enum LicenseStatus { valid, expired, notActivated, invalid, tampered }

class LicenseValidationResult {
  final bool isValid;
  final String? errorMessage;
  final DateTime? expiryDate;
  final String? expiryStr;
  final ResultKind kind;
  LicenseValidationResult._(this.isValid, this.errorMessage, this.expiryDate, this.expiryStr, this.kind);
  factory LicenseValidationResult.valid({required DateTime expiryDate, required String expiryStr}) =>
      LicenseValidationResult._(true, null, expiryDate, expiryStr, ResultKind.valid);
  factory LicenseValidationResult.invalidFormat(String msg) =>
      LicenseValidationResult._(false, msg, null, null, ResultKind.invalidFormat);
  factory LicenseValidationResult.invalidSignature(String msg) =>
      LicenseValidationResult._(false, msg, null, null, ResultKind.invalidSignature);
  factory LicenseValidationResult.expired(String msg) =>
      LicenseValidationResult._(false, msg, null, null, ResultKind.expired);
}

enum ResultKind { valid, invalidFormat, invalidSignature, expired }
