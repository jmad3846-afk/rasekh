import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/widgets.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/database/hive_init.dart';
import '../../logic/factory_providers.dart';
import '../../../finance/data/models/transaction.dart';
import '../../../finance/logic/finance_engine.dart';

/// Sprint 2026-09: dedicated inventory-suppliers ledger (موردو مخزون المعمل).
/// Factory scope ONLY — contracting (project-linked) suppliers are excluded.
class InventorySuppliersTab extends ConsumerStatefulWidget {
  const InventorySuppliersTab({super.key});
  @override
  ConsumerState<InventorySuppliersTab> createState() => _S();
}

class _S extends ConsumerState<InventorySuppliersTab> {
  String query = '';
  final searchCtrl = TextEditingController();

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(transactionsProvider);
    ref.watch(stockLogsProvider);
    final balances = FinanceEngine.inventorySupplierBalances();
    final profiles = FinanceEngine.inventorySupplierProfiles();
    final q = query.trim().toLowerCase();
    final entries = balances.entries.where((e) {
      if (q.isEmpty) return true;
      return e.value.name.toLowerCase().contains(q) ||
          e.value.phone.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => b.value.remaining.compareTo(a.value.remaining));
    final totalRemaining =
        balances.values.fold(0.0, (s, b) => s + b.remaining);
    final totalCost =
        balances.values.fold(0.0, (s, b) => s + b.totalCost);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          controller: searchCtrl,
          onChanged: (v) => setState(() => query = v),
          decoration: InputDecoration(
            hintText: 'بحث باسم مورد المخزون أو الرقم...',
            hintStyle:
                GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      searchCtrl.clear();
                      setState(() => query = '');
                    })
                : null,
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              gradient: AppColors.navyGradient,
              borderRadius: BorderRadius.circular(14)),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${balances.length} مورد مخزون',
                          style: GoogleFonts.cairo(
                              color: Colors.white70, fontSize: 12)),
                      Text(
                          'إجمالي دفعات المخزون: ${Money.withCurrency(totalCost, AppCurrency.syp)}',
                          style: GoogleFonts.cairo(
                              color: Colors.white70, fontSize: 11)),
                    ]),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('المتبقي الكلي',
                          style: GoogleFonts.cairo(
                              color: Colors.white70, fontSize: 11)),
                      Text(
                          Money.withCurrency(
                              totalRemaining, AppCurrency.syp),
                          style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17)),
                    ]),
              ]),
        ),
      ),
      Expanded(
        child: entries.isEmpty
            ? Center(
                child: Text(
                    query.isEmpty
                        ? 'لا توجد دفعات مخزون بتكلفة بعد — أضف مخزوناً مع تكلفة الدفعة'
                        : 'لا نتائج مطابقة للبحث',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                        color: AppColors.textSecondary)))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final partyId = entries[i].key;
                  final b = entries[i].value;
                  final settled = b.remaining <= 0.005;
                  final mats =
                      profiles[partyId]?.suppliedMaterials.trim() ?? '';
                  return GlassCard(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                InventorySupplierDetailScreen(
                                    partyId: partyId))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    color: AppColors.goldLight,
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                child: const Icon(
                                    Icons.local_shipping,
                                    color: AppColors.goldDark)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(b.name,
                                      style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.w800),
                                      overflow: TextOverflow.ellipsis),
                                  Text(
                                      '${b.phone} • ${b.moves} حركة',
                                      style: GoogleFonts.cairo(
                                          fontSize: 11,
                                          color:
                                              AppColors.textSecondary),
                                      overflow: TextOverflow.ellipsis),
                                  if (mats.isNotEmpty)
                                    Text('يبيع: $mats',
                                        style: GoogleFonts.cairo(
                                            fontSize: 11,
                                            fontWeight:
                                                FontWeight.w700,
                                            color:
                                                AppColors.goldDark),
                                        overflow:
                                            TextOverflow.ellipsis),
                                ])),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: settled
                                      ? AppColors.successBg
                                      : AppColors.errorBg,
                                  borderRadius:
                                      BorderRadius.circular(20)),
                              child: Text(settled ? 'خالص' : 'متبقي',
                                  style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: settled
                                          ? AppColors.success
                                          : AppColors.error)),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                                child: Text(
                                    'إجمالي الدفعات ${Money.withCurrency(b.totalCost, AppCurrency.syp)}',
                                    style: GoogleFonts.cairo(
                                        fontSize: 11,
                                        color: AppColors.textSecondary))),
                            Text(
                                'متبقي ${Money.withCurrency(b.remaining, AppCurrency.syp)}',
                                style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: settled
                                        ? AppColors.success
                                        : AppColors.error)),
                          ]),
                          Text(
                              'مدفوع ${Money.withCurrency(b.paid, AppCurrency.syp)} — اضغط للسجل الكامل والدفع الجزئي',
                              style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  color: AppColors.goldDark)),
                        ]),
                  );
                },
              ),
      ),
    ]);
  }
}

/// Full per-supplier workspace: summary + batch history + audit + partial pay.
class InventorySupplierDetailScreen extends ConsumerWidget {
  final String partyId;
  const InventorySupplierDetailScreen(
      {super.key, required this.partyId});

  List<dynamic> _batchesFor(String pid) {
    if (pid.startsWith('stock-')) {
      final name = pid.substring('stock-'.length).toLowerCase();
      return HiveInit.stockLogs.values
          .where((l) =>
              l.supplierPhone.trim().isEmpty &&
              l.supplierName.trim().toLowerCase() == name)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return HiveInit.stockLogs.values
        .where((l) => l.supplierPhone.trim() == pid)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(transactionsProvider);
    ref.watch(stockLogsProvider);
    final balances = FinanceEngine.inventorySupplierBalances();
    final b = balances[partyId];
    if (b == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('المورد غير موجود')));
    }
    final txs = FinanceEngine.inventorySupplierLedger()
        .where((t) => t.partyId == partyId)
        .toList();
    final batches = _batchesFor(partyId);
    final settled = b.remaining <= 0.005;
    final mats =
        FinanceEngine.inventorySupplierProfiles()[partyId]?.suppliedMaterials.trim() ?? '';

    return Scaffold(
      appBar: AppBar(
          title: Text(b.name,
              style:
                  GoogleFonts.cairo(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(
              child: _card(
                  'إجمالي دفعات المخزون',
                  Money.withCurrency(b.totalCost, AppCurrency.syp),
                  AppColors.deepNavy,
                  AppColors.background)),
          const SizedBox(width: 8),
          Expanded(
              child: _card(
                  'المتبقي المستحق',
                  Money.withCurrency(b.remaining, AppCurrency.syp),
                  settled ? AppColors.success : AppColors.error,
                  settled ? AppColors.successBg : AppColors.errorBg)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: _card(
                  'مجموع المدفوع',
                  Money.withCurrency(b.paid, AppCurrency.syp),
                  AppColors.success,
                  AppColors.successBg)),
          const SizedBox(width: 8),
          Expanded(
              child: _card('الهاتف', b.phone, AppColors.deepNavy,
                  AppColors.background)),
        ]),
        if (mats.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.goldLight,
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 16, color: AppColors.goldDark),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('المواد التي يبيعها: $mats',
                      style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.goldDark))),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => showInventoryPaymentDialog(
                context: context,
                ref: ref,
                partyId: partyId,
                partyName: b.name,
                partyPhone: b.phone == partyId ? null : b.phone),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepNavy,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14)),
            icon: const Icon(Icons.payments_outlined),
            label: Text('دفع دفعة جزئية',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 16),
        Text('دفعات المخزون (${batches.length})',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (batches.isEmpty)
          GlassCard(
              child: Center(
                  child: Text('لا توجد دفعات مسجلة',
                      style: GoogleFonts.cairo(
                          color: AppColors.textSecondary)))),
        for (final l in batches)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(l.productName as String,
                            style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                            overflow: TextOverflow.ellipsis)),
                    Text(
                        '+${(l.quantityAdded as double).toStringAsFixed(0)}',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w800,
                            color: AppColors.success)),
                  ]),
                  Text(
                      '${(l.createdAt as DateTime).toString().substring(0, 10)} • الإجمالي ${Money.withCurrency((l.purchaseCost as double), AppCurrency.syp)} • الأولى ${Money.withCurrency((l.downPayment as double), AppCurrency.syp)} • متبقي الدفعة ${Money.withCurrency(((l.purchaseCost as double) - (l.downPayment as double)).clamp(0, double.infinity), AppCurrency.syp)}',
                      style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppColors.textSecondary)),
                ]),
          ),
        const SizedBox(height: 8),
        Text('السجل المالي الكامل (${txs.length} حركة)',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final t in txs)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Icon(
                    t.type == TransactionType.payment
                        ? Icons.check_circle
                        : Icons.arrow_downward,
                    size: 16,
                    color: t.type == TransactionType.payment
                        ? AppColors.success
                        : AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      Text(t.source,
                          style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                      Text(
                          '${t.reason} • ${t.createdAt.toString().substring(0, 10)}',
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ])),
                Text(
                    '${t.type == TransactionType.payment ? '-' : '+'}${Money.withCurrency(t.amount, AppCurrency.syp)}',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: t.type == TransactionType.payment
                            ? AppColors.success
                            : AppColors.error)),
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
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.cairo(
                    fontSize: 11, color: fg, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
            Text(value,
                style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
          ]),
    );
  }
}

/// Partial payment dialog guarded by the INVENTORY-scoped remaining.
Future<void> showInventoryPaymentDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String partyId,
  required String partyName,
  String? partyPhone,
}) {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController(text: 'دفعة جزئية لمورد مخزون');
  String? errorMsg;

  return showDialog(
    context: context,
    builder: (_) => StatefulBuilder(builder: (ctx, setD) {
      final amt = double.tryParse(amountCtrl.text) ?? 0;
      final remaining =
          FinanceEngine.inventorySupplierRemaining(partyId);
      final over = amt > remaining + 0.005;
      return AlertDialog(
        title: Text('دفع دفعة جزئية - $partyName',
            style: GoogleFonts.cairo(
                fontSize: 15, fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child:
              Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('المبلغ المتبقي المستحق',
                        style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    Flexible(
                        child: Text(
                            Money.withCurrency(
                                remaining, AppCurrency.syp),
                            style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: remaining > 0
                                    ? AppColors.error
                                    : AppColors.success))),
                  ]),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: amountCtrl,
                onChanged: (_) => setD(() {}),
                decoration: const InputDecoration(
                    labelText: 'المبلغ (ل.س) *',
                    prefixIcon: Icon(Icons.payments_outlined, size: 18)),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ]),
            if (over && amt > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('المبلغ المدخل أكبر من المتبقي المستحق',
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error)),
              ),
            if (errorMsg != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(errorMsg!,
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error)),
              ),
            const SizedBox(height: 12),
            TextField(
                controller: noteCtrl,
                decoration:
                    const InputDecoration(labelText: 'ملاحظات')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
              onPressed: () async {
                if (amt <= 0) return;
                try {
                  await ref
                      .read(productServiceProvider)
                      .payInventorySupplier(
                        partyId: partyId,
                        partyName: partyName,
                        partyPhone: partyPhone,
                        amount: amt,
                        reason: noteCtrl.text.isEmpty
                            ? 'دفعة جزئية لمورد مخزون'
                            : noteCtrl.text,
                      );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  setD(() => errorMsg = '$e'
                      .replaceAll('Exception: ', ''));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepNavy),
              child: Text('تأكيد الدفع', style: GoogleFonts.cairo())),
        ],
      );
    }),
  );
}
