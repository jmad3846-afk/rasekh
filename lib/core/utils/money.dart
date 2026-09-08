import 'package:intl/intl.dart';
class Money {
  static final fmt = NumberFormat.currency(locale: 'ar_IQ', symbol: 'د.ع ', decimalDigits: 0);
  static String format(double v) => fmt.format(v);
  static String compact(double v){
    if(v>=1e6) return '${(v/1e6).toStringAsFixed(1)}M';
    if(v>=1e3) return '${(v/1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}
