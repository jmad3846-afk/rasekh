import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/widgets.dart';
import '../../../../core/theme/finance_widgets.dart';
import '../../../../core/utils/money.dart';
import '../../logic/site_providers.dart';
import '../../data/models/project.dart';

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
                          '${m.category} • ${m.quantity.toStringAsFixed(1)} ${m.unit} • ${Money.withCurrency(m.unitPrice, widget.project.currency)}/${m.unit}',
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                      Text(
                          'الإجمالي ${Money.withCurrency(m.totalValue, widget.project.currency)}',
                          style: GoogleFonts.cairo(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ])),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') _upsert(m.id, m.name, m.category,
                        m.quantity, m.unit, m.unitPrice);
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
        onPressed: () => _upsert(null, '', '', 0, 'قطعة', 0),
        icon: const Icon(Icons.add),
        label: Text('إضافة مادة', style: GoogleFonts.cairo()),
      ),
    );
  }

  void _upsert(String? id, String name, String category, double qty,
      String unit, double price) {
    final nameC = TextEditingController(text: name);
    final catC = TextEditingController(text: category);
    final qtyC = TextEditingController(
        text: qty == 0 ? '' : qty.toString());
    final unitC = TextEditingController(text: unit);
    final priceC = TextEditingController(
        text: price == 0 ? '' : price.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(id == null ? 'مادة جديدة' : 'تعديل المادة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameC,
                decoration:
                    const InputDecoration(labelText: 'اسم المادة *')),
            const SizedBox(height: 8),
            TextField(controller: catC,
                decoration:
                    const InputDecoration(labelText: 'الفئة')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: TextField(controller: qtyC,
                      decoration: const InputDecoration(
                          labelText: 'الكمية *'),
                      keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(controller: unitC,
                      decoration:
                          const InputDecoration(labelText: 'الوحدة'))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: priceC,
                decoration: const InputDecoration(
                    labelText: 'سعر الوحدة'),
                keyboardType: TextInputType.number),
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
              try {
                if (id == null) {
                  await ref.read(siteServiceProvider).addMaterial(
                      projectId: widget.project.id,
                      name: nameC.text,
                      category: catC.text,
                      quantity: q,
                      unit: unitC.text.isEmpty ? 'قطعة' : unitC.text,
                      unitPrice:
                          double.tryParse(priceC.text) ?? 0);
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
                            unitPrice:
                                double.tryParse(priceC.text) ?? 0);
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
      ),
    );
  }
}
