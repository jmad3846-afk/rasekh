import 'package:hive/hive.dart';

/// Supported currencies: Syrian Pound + US Dollar.
enum AppCurrency { syp, usd }

extension AppCurrencyX on AppCurrency {
  String get code => this == AppCurrency.usd ? 'USD' : 'SYP';
  String get symbol => this == AppCurrency.usd ? '\$' : 'ل.س';
  String get arabicName => this == AppCurrency.usd ? 'دولار' : 'ليرة سورية';

  static AppCurrency fromString(String? v) {
    if (v == null) return AppCurrency.syp;
    final s = v.trim().toUpperCase();
    if (s == 'USD' || s == '\$' || s == 'DOLLAR') return AppCurrency.usd;
    return AppCurrency.syp;
  }
}

class AppCurrencyAdapter extends TypeAdapter<AppCurrency> {
  @override
  final int typeId = 11;

  @override
  AppCurrency read(BinaryReader reader) {
    try {
      return AppCurrency.values[reader.readInt()];
    } catch (_) {
      return AppCurrency.syp;
    }
  }

  @override
  void write(BinaryWriter writer, AppCurrency obj) {
    writer.writeInt(obj.index);
  }
}
