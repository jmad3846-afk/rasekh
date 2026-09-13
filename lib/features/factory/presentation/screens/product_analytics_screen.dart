import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/widgets.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/database/hive_init.dart';
import '../../logic/factory_providers.dart';
import '../../data/models/product.dart';

/// Sprint 2026-09: Expenses & Analytics (المصروفات وإحصائيات المنتجات).
/// Per-product sold/consumed quantities (invoice lines) with the product unit,
/// plus historical price-tier filtering: each catalog price change opens a
/// new tier interval, and sales are attributed per interval.
class ProductAnalyticsTab extends ConsumerStatefulWidget {
  const ProductAnalyticsTab({super.key});
  @override
  ConsumerState<ProductAnalyticsTab> createState() => _S();
}

class _S extends ConsumerState<ProductAnalyticsTab> {
  String query = '';
  final searchCtrl = TextEditingController();

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(productsProvider);
    ref.watch(invoicesProvider);
    ref.watch(priceTiersProvider);
    final products = HiveInit.products.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final sales = ProductAnalytics.salesByProduct();
    final q = query.trim().toLowerCase();
    final list = products.where((p) {
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q);
    }).toList();
    final totalRevenue =
        sales.values.fold(0.0, (s, e) => s + e.revenue);
    final totalLines =
        HiveInit.invoices.values.where((i) => !i.isPaymentOnly).length;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          controller: searchCtrl,
          onChanged: (v) => setState(() => query = v),
          decoration: InputDecoration(
            hintText: 'بحث باسم المنتج أو الفئة...',
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
                Text('$totalLines فاتورة مبيعات',
                    style: GoogleFonts.cairo(
                        color: Colors.white70, fontSize: 12)),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('إجمالي إيراد المبيعات',
                          style: GoogleFonts.cairo(
                              color: Colors.white70, fontSize: 11)),
                      Text(
                          Money.withCurrency(
                              totalRevenue, AppCurrency.syp),
                          style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17)),
                    ]),
              ]),
        ),
      ),
      Expanded(
        child: list.isEmpty
            ? Center(
                child: Text('لا توجد منتجات مطابقة',
                    style: GoogleFonts.cairo(
                        color: AppColors.textSecondary)))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = list[i];
                  final s = sales[p.id];
                  final tiers =
                      ProductAnalytics.tiersForProduct(p.id);
                  final soldQty = s?.qty ?? 0;
                  return GlassCard(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ProductTierDetailScreen(
                                    product: p))),
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    color: AppColors.goldLight,
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                child: const Icon(Icons.category,
                                    color: AppColors.goldDark)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(p.name,
                                      style: GoogleFonts.cairo(
                                          fontWeight:
                                              FontWeight.w800),
                                      overflow:
                                          TextOverflow.ellipsis),
                                  Text(
                                      '${p.category} • السعر الحالي ${Money.withCurrency(p.unitPrice, AppCurrency.syp)}/${p.unit} • ${tiers.length} شريحة سعرية',
                                      style: GoogleFonts.cairo(
                                          fontSize: 11,
                                          color: AppColors
                                              .textSecondary),
                                      overflow: TextOverflow.ellipsis),
                                ])),
                            const Icon(Icons.arrow_forward_ios,
                                size: 14,
                                color: AppColors.textSecondary),
                          ]),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius:
                                    BorderRadius.circular(10)),
                            child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('الكمية المباعة/المستهلكة',
                                            style: GoogleFonts.cairo(
                                                fontSize: 11,
                                                color: AppColors
                                                    .textSecondary)),
                                        Text(
                                            '${soldQty.toStringAsFixed(0)} ${p.unit}',
                                            style: GoogleFonts.cairo(
                                                fontSize: 15,
                                                fontWeight:
                                                    FontWeight.w800,
                                                color:
                                                    AppColors.deepNavy)),
                                      ]),
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text('الإيراد',
                                            style: GoogleFonts.cairo(
                                                fontSize: 11,
                                                color: AppColors
                                                    .textSecondary)),
                                        Text(
                                            Money.withCurrency(
                                                s?.revenue ?? 0,
                                                AppCurrency.syp),
                                            style: GoogleFonts.cairo(
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.w800,
                                                color: AppColors
                                                    .success)),
                                      ]),
                                ]),
                          ),
                          Text(
                              '${s?.invoices ?? 0} فاتورة • اضغط لعرض التفصيل حسب الشرائح السعرية',
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

/// Per-product tier breakdown with interval filtering.
class ProductTierDetailScreen extends ConsumerStatefulWidget {
  final Product product;
  const ProductTierDetailScreen({super.key, required this.product});
  @override
  ConsumerState<ProductTierDetailScreen> createState() => _D();
}

class _D extends ConsumerState<ProductTierDetailScreen> {
  int selectedTier = -1; // -1 = all intervals

  @override
  Widget build(BuildContext context) {
    ref.watch(invoicesProvider);
    ref.watch(priceTiersProvider);
    final p = widget.product;
    // Re-read live product (price may have changed).
    final live = HiveInit.products.get(p.id) ?? p;
    final tiers = ProductAnalytics.tiersForProduct(p.id);
    final total = ProductAnalytics.salesByProduct()[p.id];

    return Scaffold(
      appBar: AppBar(
          title: Text('إحصائيات ${live.name}',
              style:
                  GoogleFonts.cairo(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        GlassCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                  'الإجمالي المباع: ${(total?.qty ?? 0).toStringAsFixed(0)} ${live.unit} • الإيراد ${Money.withCurrency(total?.revenue ?? 0, AppCurrency.syp)}',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w800, fontSize: 13)),
              Text(
                  'السعر الحالي: ${Money.withCurrency(live.unitPrice, AppCurrency.syp)}/${live.unit} • ${tiers.length} شريحة سعرية',
                  style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.textSecondary)),
            ])),
        const SizedBox(height: 12),
        Text('فلترة حسب الشريحة السعرية',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
            label: Text('كل الفترات',
                style: GoogleFonts.cairo(fontSize: 12)),
            selected: selectedTier == -1,
            onSelected: (_) => setState(() => selectedTier = -1),
          ),
          for (int i = 0; i < tiers.length; i++)
            ChoiceChip(
              label: Text(
                  '${tiers[i].unitPrice.toStringAsFixed(0)} ل.س',
                  style: GoogleFonts.cairo(fontSize: 12)),
              selected: selectedTier == i,
              onSelected: (_) => setState(() => selectedTier = i),
            ),
        ]),
        const SizedBox(height: 12),
        if (selectedTier == -1)
          for (int i = tiers.length - 1; i >= 0; i--)
            _tierCard(live, tiers[i], i)
        else if (selectedTier >= 0 && selectedTier < tiers.length)
          _tierCard(live, tiers[selectedTier], selectedTier),
      ]),
    );
  }

  Widget _tierCard(Product p, dynamic tier, int index) {
    final s = ProductAnalytics.salesInTier(p.id, tier);
    final breakdown =
        ProductAnalytics.priceBreakdownInTier(p.id, tier);
    final start = (tier.startedAt as DateTime).toString().substring(0, 10);
    final end = tier.endedAt == null
        ? 'حتى الآن (نشطة)'
        : (tier.endedAt as DateTime).toString().substring(0, 10);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: tier.isActive as bool
                  ? AppColors.success
                  : AppColors.border,
              width: (tier.isActive as bool) ? 1.5 : 1)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: Text(
                      'الشريحة ${index + 1}: ${Money.withCurrency((tier.unitPrice as double), AppCurrency.syp)}/${p.unit}',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w800, fontSize: 13),
                      overflow: TextOverflow.ellipsis)),
              if (tier.isActive as bool)
                Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('نشطة',
                        style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success))),
            ]),
            Text('الفترة: $start → $end',
                style: GoogleFonts.cairo(
                    fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text('المباع في الفترة',
                              style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color:
                                      AppColors.textSecondary)),
                          Text(
                              '${s.qty.toStringAsFixed(0)} ${p.unit}',
                              style: GoogleFonts.cairo(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.deepNavy)),
                        ]),
                    Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: [
                          Text('الإيراد (${s.lines} سطر)',
                              style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color:
                                      AppColors.textSecondary)),
                          Text(
                              Money.withCurrency(
                                  s.revenue, AppCurrency.syp),
                              style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.success)),
                        ]),
                  ]),
            ),
            if (breakdown.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('التفصيل حسب سعر البيع الفعلي:',
                  style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              for (final e in (breakdown.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value))))
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    const Icon(Icons.circle,
                        size: 8, color: AppColors.goldDark),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(
                            'بيع ${e.value.toStringAsFixed(0)} ${p.unit} بسعر ${Money.withCurrency(e.key, AppCurrency.syp)}/${p.unit}',
                            style: GoogleFonts.cairo(
                                fontSize: 12))),
                    Text(
                        Money.withCurrency(
                            e.key * e.value, AppCurrency.syp),
                        style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepNavy)),
                  ]),
                ),
            ],
            if (s.lines == 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('لا توجد مبيعات في هذه الفترة بعد',
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppColors.textSecondary)),
              ),
          ]),
    );
  }
}
