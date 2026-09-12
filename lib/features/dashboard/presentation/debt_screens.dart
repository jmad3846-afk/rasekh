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
  AppCurrency filter = AppCurrency.syp;
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
            // Currency toggle filter.
            Row(children: [
              Text('العملة:', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              ChoiceChip(
                  label: Text('ل.س SYP', style: GoogleFonts.cairo(fontSize: 12)),
                  selected: filter == AppCurrency.syp,
                  onSelected: (_) => setState(() => filter = AppCurrency.syp)),
              const SizedBox(width: 8),
              ChoiceChip(
                  label: Text('\$ USD', style: GoogleFonts.cairo(fontSize: 12)),
                  selected: filter == AppCurrency.usd,
                  onSelected: (_) => setState(() => filter = AppCurrency.usd)),
            ]),
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
                    Text('إجمالي التراكم (${filter.code})',
                        style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12)),
                    Text(Money.withCurrency(total, filter),
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
                          ]),
                          Text(first.partyPhone ?? partyId,
                              style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                              'المتراكم: ${Money.withCurrency(bal, filter)} • مدفوع: ${Money.withCurrency(s.paid, filter)} • ${list.length} حركة',
                              style: GoogleFonts.cairo(fontSize: 11)),
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
                          CurrencyBadge(p.currency),
                        ]),
                        Text(
                            '${p.category} • ${Money.withCurrency(p.unitPrice, p.currency)}/${p.unit}',
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
