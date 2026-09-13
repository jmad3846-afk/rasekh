import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/widgets.dart';
import '../../../../core/theme/finance_widgets.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/money.dart';
import '../../logic/site_providers.dart';
import '../../data/models/project.dart';
import '../../../personnel/data/models/personnel.dart';
import '../../../personnel/logic/personnel_providers.dart';

/// Req #11A: required raw materials for a project.
class RequiredMaterialsScreen extends ConsumerStatefulWidget {
  final Project project;
  const RequiredMaterialsScreen({super.key, required this.project});
  @override ConsumerState<RequiredMaterialsScreen> createState() => _S();
}

class _S extends ConsumerState<RequiredMaterialsScreen> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(requiredMaterialsProvider(widget.project.id));
    return Scaffold(
      appBar: AppBar(
          title: Text('المواد اللازمة - ${widget.project.location}',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800, fontSize: 15))),
      body: async.when(
        data: (mats) {
          if (mats.isEmpty) {
            return Center(
                child: Text('لا توجد مواد بعد — أضف المواد الخام اللازمة',
                    style: GoogleFonts.cairo(
                        color: AppColors.textSecondary)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: mats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final m = mats[i];
              return GlassCard(
                  child: Row(children: [
                Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                        color: AppColors.goldLight,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.inventory_2_outlined,
                        color: AppColors.goldDark)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(m.name,
                          style:
                              GoogleFonts.cairo(fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis),
                      Text(
                          '${m.category} • ${m.quantity.toStringAsFixed(1)} ${m.unit} • ${Money.withCurrency(m.unitPrice, AppCurrency.syp)}/${m.unit}',
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                      Text(
                          'الإجمالي ${Money.withCurrency(m.totalValue, AppCurrency.syp)}',
                          style: GoogleFonts.cairo(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                      if (m.downPayment > 0)
                        Text(
                            'الدفعة الأولى ${Money.withCurrency(m.downPayment, AppCurrency.syp)} • المتبقي ${Money.withCurrency(m.totalValue - m.downPayment, AppCurrency.syp)}',
                            style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success)),
                      if (m.supplierName.isNotEmpty)
                        Row(children: [
                          const Icon(Icons.local_shipping_outlined,
                              size: 12, color: AppColors.goldDark),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                                'المورد: ${m.supplierName}',
                                style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.goldDark),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                    ])),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') _upsert(m.id, m.name, m.category,
                        m.quantity, m.unit, m.unitPrice,
                        supplierId: m.supplierId, downPayment: m.downPayment);
                    if (v == 'delete') {
                      final ok = await confirmDelete(context,
                          title: 'حذف المادة؟',
                          message:
                              'هل أنت متأكد من حذف "${m.name}"؟');
                      if (ok) {
                        await ref
                            .read(siteServiceProvider)
                            .deleteMaterial(m);
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'edit',
                        child:
                            Text('تعديل', style: GoogleFonts.cairo())),
                    PopupMenuItem(
                        value: 'delete',
                        child: Text('حذف',
                            style: GoogleFonts.cairo(
                                color: AppColors.error))),
                  ],
                ),
              ]));
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold, foregroundColor: Colors.white,
        onPressed: () => _upsert(null, '', '', 0, 'قطعة', 0, downPayment: 0),
        icon: const Icon(Icons.add),
        label: Text('إضافة مادة', style: GoogleFonts.cairo()),
      ),
    );
  }

  void _upsert(String? id, String name, String category, double qty,
      String unit, double price, {String? supplierId, double downPayment = 0}) {
    final suppliers =
        ref.read(personnelByRoleProvider(PersonnelRole.supplier));
    if (suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'لا يوجد موردون — أضف مورداً أولاً من قسم العاملين',
              style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error));
      return;
    }
    final nameC = TextEditingController(text: name);
    final catC = TextEditingController(text: category);
    final qtyC = TextEditingController(
        text: qty == 0 ? '' : qty.toString());
    final unitC = TextEditingController(text: unit);
    final priceC = TextEditingController(
        text: price == 0 ? '' : price.toString());
    final downPaymentC = TextEditingController(
        text: downPayment == 0 ? '' : downPayment.toString());
    String? selectedSupplierId = supplierId;
    // Default to first supplier on create.
    if (selectedSupplierId == null ||
        !suppliers.any((s) => s.id == selectedSupplierId)) {
      selectedSupplierId = id == null ? null : selectedSupplierId;
    }
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: Text(id == null ? 'مادة جديدة' : 'تعديل المادة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: nameC,
                decoration:
                    const InputDecoration(labelText: 'اسم المادة *')),
            const SizedBox(height: 8),
            TextField(controller: catC,
                decoration:
                    const InputDecoration(labelText: 'الفئة')),
            const SizedBox(height: 8),
            // Mandatory supplier picker (Task 2).
            Text('المورد * (إلزامي)',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: selectedSupplierId,
              isExpanded: true,
              hint: Text('اختر المورد *',
                  style: GoogleFonts.cairo(fontSize: 12)),
              items: suppliers
                  .map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(
                            '${s.name} • ${s.phone}${s.suppliedMaterials.trim().isEmpty ? '' : ' • ${s.suppliedMaterials}'}',
                            style: GoogleFonts.cairo(fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setD(() => selectedSupplierId = v),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: TextField(controller: qtyC,
                      decoration: const InputDecoration(
                          labelText: 'الكمية *'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.]'))
                      ])),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(controller: unitC,
                      decoration:
                          const InputDecoration(labelText: 'الوحدة'))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: priceC,
                decoration: const InputDecoration(
                    labelText: 'سعر الوحدة (ل.س)'),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ]),
            const SizedBox(height: 8),
            // Sprint 2026-09 Task 6: mandatory initial down payment.
            TextField(controller: downPaymentC,
                decoration: const InputDecoration(
                    labelText: 'الدفعة الأولى للمورد (ل.س) *',
                    hintText: 'مثال: 0 إذا بدون دفعة',
                    prefixIcon: Icon(Icons.payments_outlined, size: 18)),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ]),
            const SizedBox(height: 4),
            Text('تُسجَّل الدفعة الأولى تلقائياً في دفتر المورد كدفعة مدفوعة مرتبطة بهذا المشروع.',
                style: GoogleFonts.cairo(
                    fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('تُرحّل القيمة تلقائياً: دين على صاحب التعهد (لنا) + مستحق للمورد (علينا) — بالليرة السورية.',
                style: GoogleFonts.cairo(
                    fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () async {
              final q = double.tryParse(qtyC.text) ?? 0;
              if (nameC.text.trim().isEmpty || q <= 0) return;
              if (selectedSupplierId == null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('اختيار المورد إلزامي',
                        style: GoogleFonts.cairo()),
                    backgroundColor: AppColors.error));
                return;
              }
              // Sprint 2026-09 Task 6: mandatory down-payment field.
              if (downPaymentC.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('الدفعة الأولى للمورد مطلوبة (أدخل 0 إذا بدون دفعة)',
                        style: GoogleFonts.cairo()),
                    backgroundColor: AppColors.error));
                return;
              }
              final dp = double.tryParse(downPaymentC.text) ?? -1;
              final unitP = double.tryParse(priceC.text) ?? 0;
              final total = q * unitP;
              if (dp < 0 || dp > total) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('الدفعة الأولى يجب أن تكون بين 0 وإجمالي المادة (${total.toStringAsFixed(0)} ل.س)',
                        style: GoogleFonts.cairo()),
                    backgroundColor: AppColors.error));
                return;
              }
              PersonnelEntry sup;
              try {
                sup = suppliers
                    .firstWhere((e) => e.id == selectedSupplierId);
              } catch (_) {
                return;
              }
              try {
                if (id == null) {
                  await ref.read(siteServiceProvider).addMaterial(
                      projectId: widget.project.id,
                      name: nameC.text,
                      category: catC.text,
                      quantity: q,
                      unit: unitC.text.isEmpty ? 'قطعة' : unitC.text,
                      unitPrice: unitP,
                      supplierId: sup.id,
                      supplierName: sup.name,
                      supplierPhone: sup.phone,
                      downPayment: dp);
                } else {
                  final box = ref;
                  final mat = box
                      .read(requiredMaterialsProvider(widget.project.id))
                      .value
                      ?.firstWhere((e) => e.id == id);
                  if (mat != null) {
                    await ref
                        .read(siteServiceProvider)
                        .updateMaterial(mat,
                            name: nameC.text,
                            category: catC.text,
                            quantity: q,
                            unit: unitC.text,
                            unitPrice: unitP,
                            supplierId: sup.id,
                            supplierName: sup.name,
                            supplierPhone: sup.phone,
                            downPayment: dp);
                  }
                }
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('$e', style: GoogleFonts.cairo()),
                      backgroundColor: AppColors.error));
                }
              }
            },
            child: Text('حفظ', style: GoogleFonts.cairo()),
          ),
        ],
      )),
    );
  }
}
