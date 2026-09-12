import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import '../utils/currency.dart';
import '../utils/money.dart';

/// Shared currency badge (Req #1): `$` green vs `ل.س` amber.
class CurrencyBadge extends StatelessWidget {
  final AppCurrency currency;
  final bool dark;
  const CurrencyBadge(this.currency, {super.key, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final isUsd = currency == AppCurrency.usd;
    if (dark) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20)),
        child: Text(isUsd ? '\$ USD' : 'ل.س SYP',
            style: GoogleFonts.cairo(
                fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: isUsd ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(20)),
      child: Text(isUsd ? '\$' : 'ل.س',
          style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isUsd ? AppColors.success : AppColors.goldDark)),
    );
  }
}

/// Mandatory currency selector (Req #1): SYP / USD cards.
class CurrencySelector extends StatelessWidget {
  final AppCurrency value;
  final ValueChanged<AppCurrency> onChanged;
  const CurrencySelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _option(AppCurrency.syp)),
      const SizedBox(width: 12),
      Expanded(child: _option(AppCurrency.usd)),
    ]);
  }

  Widget _option(AppCurrency c) {
    final sel = value == c;
    final isUsd = c == AppCurrency.usd;
    return InkWell(
      onTap: () => onChanged(c),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: sel
              ? (isUsd ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7))
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel
                  ? (isUsd ? AppColors.success : AppColors.goldDark)
                  : AppColors.border,
              width: sel ? 2 : 1),
        ),
        child: Column(children: [
          Text(isUsd ? '\$ USD' : 'ل.س SYP',
              style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isUsd ? AppColors.success : AppColors.goldDark)),
          Text(isUsd ? 'دولار / \$' : 'ليرة سورية / ل.س',
              style: GoogleFonts.cairo(
                  fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

/// Req #4: explicit "Are you sure?" guard for every delete.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'حذف',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title,
          style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15)),
      content: Text(message, style: GoogleFonts.cairo(fontSize: 13)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: GoogleFonts.cairo())),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(confirmLabel,
                style: GoogleFonts.cairo(color: Colors.white))),
      ],
    ),
  );
  return ok == true;
}

/// Live FX preview line (Req #2): shows secondary equivalent instantly.
class FxPreview extends StatelessWidget {
  final double amount;
  final AppCurrency currency;
  final double? dollarRate;
  const FxPreview(
      {super.key,
      required this.amount,
      required this.currency,
      required this.dollarRate});

  @override
  Widget build(BuildContext context) {
    if (dollarRate == null || dollarRate! <= 0 || amount <= 0) {
      return Text('أدخل المبلغ وسعر الصرف لعرض المعادل',
          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary));
    }
    final conv = CurrencyConverter.convert(
        amount: amount, from: currency, dollarRate: dollarRate!);
    final other =
        currency == AppCurrency.usd ? AppCurrency.syp : AppCurrency.usd;
    final formula = currency == AppCurrency.usd
        ? '${Money.withCurrency(amount, currency)} × ${dollarRate!.toStringAsFixed(0)}'
        : '${Money.withCurrency(amount, currency)} ÷ ${dollarRate!.toStringAsFixed(0)}';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: AppColors.goldLight, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(formula,
            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.goldDark)),
        Text('المعادل: ${Money.withCurrency(conv, other)}',
            style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.deepNavy)),
      ]),
    );
  }
}
