import 'package:intl/intl.dart';
import 'currency.dart';

class Money {
  static final fmt = NumberFormat.currency(locale: 'ar_IQ', symbol: 'د.ع ', decimalDigits: 0);
  static final fmtSyp = NumberFormat.currency(locale: 'ar_SY', symbol: 'ل.س ', decimalDigits: 0);
  static final fmtUsd = NumberFormat.currency(locale: 'en_US', symbol: '\$ ', decimalDigits: 2);

  static String format(double v) => fmt.format(v);

  /// Currency-aware formatting: `150 $` or `25,000 ل.س`
  static String withCurrency(double v, AppCurrency c) {
    if (c == AppCurrency.usd) return '${fmtUsd.format(v)}';
    return fmtSyp.format(v);
  }

  static String compact(double v){
    if(v>=1e6) return '${(v/1e6).toStringAsFixed(1)}M';
    if(v>=1e3) return '${(v/1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}
