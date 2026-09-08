#!/usr/bin/env dart
// ignore_for_file: avoid_print
/// Offline License Generator — run locally by admin
/// Usage:
///   dart run tool/license_generator.dart --deviceId <ID> --days 30
///   dart run tool/license_generator.dart --deviceId <ID> --expiry 2027-09-08
///   dart run tool/license_generator.dart --deviceId <ID> --months 12
/// Or interactive: dart run tool/license_generator.dart

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

const String _appSecret = "FactoryProcurement_Secret_Core_Key_9988";

String generateSignature(String deviceId, String expiryDateStr) {
  final key = utf8.encode(_appSecret);
  final data = utf8.encode('$deviceId|$expiryDateStr');
  final hmac = Hmac(sha256, key);
  return hmac.convert(data).toString().substring(0, 10).toUpperCase();
}

String generateCode(String deviceId, String expiryDateStr) {
  return '$expiryDateStr-${generateSignature(deviceId, expiryDateStr)}';
}

void printUsage() {
  print('''
Factory Management — Offline License Generator
==============================================
Usage:
  dart run tool/license_generator.dart --deviceId <DEVICE_ID> [options]

Options:
  --deviceId <id>     Device ID from client (copy from ActivationScreen)
  --days <n>          Valid for n days from today (e.g., 30)
  --months <n>        Valid for n months (approx 30*n days)
  --expiry YYYY-MM-DD Custom expiry date (e.g., 2027-09-08)
  --yearly            Shortcut for 365 days
  --monthly           Shortcut for 30 days
  --help              Show this help

Examples:
  dart run tool/license_generator.dart --deviceId ABC123 --days 30
  dart run tool/license_generator.dart --deviceId ABC123 --yearly
  dart run tool/license_generator.dart --deviceId ABC123 --expiry 2028-01-01

Code format: YYYY-MM-DD-XXXXXXXXXX (HMAC-SHA256 first 10 hex)
Verification: HMAC_SHA256(_appSecret, "deviceId|YYYY-MM-DD")
''');
}

String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    printUsage();
    exit(0);
  }

  String? deviceId;
  String? expiryStr;
  int? days;

  // Manual arg parse (no external deps)
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--deviceId' && i + 1 < args.length) deviceId = args[++i];
    else if (a.startsWith('--deviceId=')) deviceId = a.split('=').last;
    else if (a == '--expiry' && i + 1 < args.length) expiryStr = args[++i];
    else if (a.startsWith('--expiry=')) expiryStr = a.split('=').last;
    else if (a == '--days' && i + 1 < args.length) days = int.tryParse(args[++i]);
    else if (a.startsWith('--days=')) days = int.tryParse(a.split('=').last);
    else if (a == '--months' && i + 1 < args.length) days = (int.tryParse(args[++i]) ?? 0) * 30;
    else if (a.startsWith('--months=')) days = (int.tryParse(a.split('=').last) ?? 0) * 30;
    else if (a == '--yearly') days = 365;
    else if (a == '--monthly') days = 30;
    else if (!a.startsWith('--') && deviceId == null) deviceId = a; // positional
  }

  // Interactive fallback
  if (deviceId == null || deviceId.isEmpty) {
    printUsage();
    stdout.write('\nEnter Device ID: ');
    deviceId = stdin.readLineSync()?.trim();
    if (deviceId == null || deviceId.isEmpty) {
      print('Device ID required. Aborting.');
      exit(1);
    }
  }

  if (expiryStr == null && days == null) {
    print('\nNo expiry specified. Choose:');
    print('  1) 30 days (monthly)');
    print('  2) 365 days (yearly)');
    print('  3) Custom days');
    print('  4) Custom date (YYYY-MM-DD)');
    stdout.write('Select [1-4] (default 1): ');
    final sel = stdin.readLineSync()?.trim() ?? '1';
    switch (sel) {
      case '2': days = 365; break;
      case '3':
        stdout.write('Enter days: ');
        days = int.tryParse(stdin.readLineSync()?.trim() ?? '');
        days ??= 30;
        break;
      case '4':
        stdout.write('Enter expiry YYYY-MM-DD: ');
        expiryStr = stdin.readLineSync()?.trim();
        break;
      default: days = 30;
    }
  }

  if (expiryStr == null) {
    final d = DateTime.now().add(Duration(days: days ?? 30));
    expiryStr = _formatDate(d);
  } else {
    // Validate date
    try {
      final parsed = DateTime.parse(expiryStr);
      expiryStr = _formatDate(parsed);
    } catch (_) {
      print('Invalid date format: $expiryStr (expected YYYY-MM-DD)');
      exit(1);
    }
  }

  deviceId = deviceId.trim();
  // Normalize: keep as entered, but trim spaces
  final code = generateCode(deviceId, expiryStr);
  final sig = code.split('-').last;

  print('\n────────────────────────────────────────');
  print('Device ID : $deviceId');
  print('Expiry    : $expiryStr (23:59:59)');
  print('Signature : $sig');
  print('────────────────────────────────────────');
  print('ACTIVATION CODE:');
  print('  $code');
  print('────────────────────────────────────────');
  print('Send this code to client via WhatsApp/Telegram.');
  print('Code is device-bound and offline-verifiable via HMAC-SHA256.');
  print('Secret: ${_appSecret.substring(0,8)}... (first 8 chars, do not share)');
  // Verify round-trip
  final verifySig = generateSignature(deviceId, expiryStr);
  print('Verify: ${verifySig == sig ? "OK ✓" : "FAIL"}');
}
