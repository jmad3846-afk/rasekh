import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/widgets.dart';
import '../../../../core/theme/finance_widgets.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/database/hive_init.dart';
import '../../finance/data/models/transaction.dart';
import '../../finance/logic/finance_engine.dart';
import '../../finance/presentation/screens/ledger_screen.dart';

/// Req #3A: detailed debt breakdown with currency toggle + person search.
class DebtBreakdownScreen extends ConsumerStatefulWidget {
  /// true = outstanding debts owed TO us (clients); false = payable we owe others.
  final bool receivable;
  const DebtBreakdownScreen({super.key, required this.receivable});
  @override ConsumerState<DebtBreakdownScreen> createState() => _S();
}

class _S extends ConsumerState<DebtBreakdownScreen> {
  // Sprint 2026-09 Task 1: SYP-only analytics — USD filter removed entirely.
  static const filter = AppCurrency.syp;
  String query = '';
  final ctrl = TextEditingController();

  @override void dispose() { ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    ref.watch(transactionsProvider);
    final parties = widget.receivable
        ? {TransactionParty.client}
        : {TransactionParty.supplier, TransactionParty.master, TransactionParty.worker, TransactionParty.driver};
    final txs = HiveInit.transactions.values
        .where((t) => parties.contains(t.party) && t.currency == filter)
        .toList();
    final Map<String, List<TransactionEntry>> grouped = {};
    for (final t in txs) {
      grouped.putIfAbsent(t.partyId, () => []).add(t);
    }
    // Person search filter.
    final q = query.trim().toLowerCase();
    final entries = grouped.entries.where((e) {
      if (q.isEmpty) return true;
      final first = e.value.first;
      return first.partyName.toLowerCase().contains(q) ||
          (first.partyPhone ?? '').toLowerCase().contains(q) ||
          e.key.toLowerCase().contains(q);
    }).toList();
    // Total accumulated per filter.
    double total = 0;
    for (final e in entries) {
      final bal = FinanceEngine.balanceFor(e.key, e.value.first.party, currency: filter);
      total += bal;
    }

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.receivable ? 'ديون مستحقة لنا' : 'ديون علينا للآخرين',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Sprint 2026-09 Task 1: fixed SYP banner (no currency toggle).
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.currency_exchange,
                    size: 18, color: AppColors.goldDark),
                const SizedBox(width: 8),
                Text('العملة: ل.س (ليرة سورية) — ثابتة',
                    style: GoogleFonts.cairo(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                hintText: 'بحث عن شخص بالاسم أو الهاتف...',
                hintStyle: GoogleFonts.cairo(fontSize: 12),
                prefixIcon: const Icon(Icons.person_search, size: 20),
                isDense: true, filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  gradient: AppColors.navyGradient,
                  borderRadius: BorderRadius.circular(14)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('إجمالي التراكم (ل.س)',
                        style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12)),
                    Text(Money.withCurrency(total, AppCurrency.syp),
                        style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18)),
                  ]),
            ),
          ]),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(child: Text('لا توجد ديون مطابقة',
                  style: GoogleFonts.cairo(color: AppColors.textSecondary)))
                : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final partyId = entries[i].key;
                    final list = entries[i].value
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    final first = list.first;
                    final bal = FinanceEngine.balanceFor(
                        partyId, first.party, currency: filter);
                    final s = FinanceEngine.personSummary(list);
                    return GlassCard(
                        onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PersonFinanceDetailScreen(
                                  partyId: partyId,
                                  party: first.party,
                                  partyName: first.partyName,
                                  currency: filter,
                                ),
                              ),
                            ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            Expanded(
                                child: Text(first.partyName,
                                    style: GoogleFonts.cairo(
                                        fontWeight: FontWeight.w800),
                                    overflow: TextOverflow.ellipsis)),
                            CurrencyBadge(filter),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios,
                                size: 14, color: AppColors.textSecondary),
                          ]),
                          Text(first.partyPhone ?? partyId,
                              style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                              'المتراكم: ${Money.withCurrency(bal, filter)} • مدفوع: ${Money.withCurrency(s.paid, filter)} • ${list.length} حركة',
                              style: GoogleFonts.cairo(fontSize: 11)),
                          Text('اضغط لعرض التفاصيل الكاملة وتسجيل دفعة',
                              style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  color: AppColors.goldDark)),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => showPaymentDialog(
                                context: context,
                                party: first.party,
                                partyId: partyId,
                                partyName: first.partyName,
                                partyPhone: first.partyPhone,
                                projectId: first.projectId,
                                initialCurrency: filter,
                                onSaved: () => setState(() {}),
                              ),
                              icon: const Icon(Icons.payments_outlined, size: 16),
                              label: Text('دفع دفعة', style: GoogleFonts.cairo(fontSize: 12)),
                            ),
                          ),
                        ]));
                  },
                ),
        ),
      ]),
    );
  }
}

/// Req #3A: low-stock products list.
class LowStockScreen extends ConsumerWidget {
  const LowStockScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = HiveInit.products.values.where((p) => p.isLowStock).toList()
      ..sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));
    return Scaffold(
      appBar: AppBar(
          title: Text('المنتجات ذات المخزون المنخفض',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800))),
      body: products.isEmpty
          ? Center(child: Text('لا توجد منتجات تحت حد الأمان',
              style: GoogleFonts.cairo(color: AppColors.textSecondary)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final p = products[i];
                return GlassCard(
                    child: Row(children: [
                  Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                          color: AppColors.errorBg,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: AppColors.error)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Flexible(
                              child: Text(p.name,
                                  style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 6),
                          // Sprint 2026-09 Task 1: SYP-only.
                          const CurrencyBadge(AppCurrency.syp),
                        ]),
                        Text(
                            '${p.category} • ${Money.withCurrency(p.unitPrice, AppCurrency.syp)}/${p.unit}',
                            style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                        Text(
                            'متوفر ${p.stockQuantity.toStringAsFixed(0)} / الحد ${p.safetyStock.toStringAsFixed(0)}',
                            style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: AppColors.error,
                                fontWeight: FontWeight.w700)),
                      ])),
                ]));
              },
            ),
    );
  }
}

/// Task 5: full interactive person ledger — opened from لنا/علينا KPIs.
/// Shows balances + complete timeline + record payment directly.
/// Live-updates central ledger via [transactionsProvider] watch.
/// Sprint 2026-09 Task 1: SYP-only — [currency] kept for compat but ignored.
class PersonFinanceDetailScreen extends ConsumerWidget {
  final String partyId;
  final TransactionParty party;
  final String partyName;
  final AppCurrency currency;
  const PersonFinanceDetailScreen({
    super.key,
    required this.partyId,
    required this.party,
    required this.partyName,
    this.currency = AppCurrency.syp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(transactionsProvider);
    const cur = AppCurrency.syp;
    final list = FinanceEngine.ledgerFor(partyId, party, currency: cur);
    final s = FinanceEngine.personSummary(list);
    final bal = FinanceEngine.balanceFor(partyId, party, currency: cur);
    final first = list.isNotEmpty ? list.first : null;
    return Scaffold(
      appBar: AppBar(
          title: Text(partyName,
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(
              child: _card('المتبقي', Money.withCurrency(bal, AppCurrency.syp),
                  AppColors.error, AppColors.errorBg)),
          const SizedBox(width: 10),
          Expanded(
              child: _card('المدفوع', Money.withCurrency(s.paid, AppCurrency.syp),
                  AppColors.success, AppColors.successBg)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => showPaymentDialog(
              context: context,
              party: party,
              partyId: partyId,
              partyName: partyName,
              partyPhone: first?.partyPhone,
              projectId: first?.projectId,
              initialCurrency: AppCurrency.syp,
            ),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepNavy,
                foregroundColor: Colors.white),
            icon: const Icon(Icons.payments_outlined),
            label: Text('دفع دفعة / تسوية',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),
        Text('السجل الكامل (${list.length} حركة) — اضغط أي سطر للتفاصيل',
            style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        if (list.isEmpty)
          GlassCard(
              child: Center(
                  child: Text('لا توجد حركات بهذه العملة',
                      style: GoogleFonts.cairo(
                          color: AppColors.textSecondary)))),
        for (final t in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              onTap: () => showTransactionDetail(context, t),
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(t.source,
                          style: GoogleFonts.cairo(
                              fontSize: 12, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                      Text(
                          '${t.reason} • ${t.createdAt.toString().substring(0, 10)}',
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                      if (t.dollarRate != null)
                        Text('سعر ${t.dollarRate!.toStringAsFixed(0)}',
                            style: GoogleFonts.cairo(
                                fontSize: 10, color: AppColors.goldDark)),
                    ])),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Money.withCurrency(t.amount, AppCurrency.syp),
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: t.type == TransactionType.payment
                                  ? AppColors.success
                                  : AppColors.error)),
                      if (t.isPayment)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: 'تعديل',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.edit_outlined,
                                size: 16, color: AppColors.deepNavy),
                            onPressed: () =>
                                showEditPaymentDialog(
                                    context: context, payment: t),
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.delete_outline,
                                size: 16, color: AppColors.error),
                            onPressed: () async {
                              final ok = await confirmDelete(context,
                                  title: 'حذف الدفعة؟',
                                  message:
                                      'هل أنت متأكد من حذف دفعة ${Money.withCurrency(t.amount, AppCurrency.syp)}؟');
                              if (ok) {
                                await FinanceEngine.deletePayment(t);
                              }
                            },
                          ),
                        ]),
                    ]),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _card(String label, String value, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.cairo(
                fontSize: 12, color: fg, fontWeight: FontWeight.w700)),
        Text(value,
            style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
      ]),
    );
  }
}
