import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/widgets.dart';
import '../../../core/theme/finance_widgets.dart';
import '../../../core/database/hive_init.dart';
import '../data/models/personnel.dart';
import '../logic/personnel_providers.dart';
import '../../finance/data/models/transaction.dart';
import '../../finance/logic/finance_engine.dart';
import '../../dashboard/presentation/personnel_debts.dart';

/// Req #10: standalone Personnel / صفحة العاملين with 4 tabs.
class PersonnelScreen extends ConsumerStatefulWidget {
  const PersonnelScreen({super.key});
  @override ConsumerState<PersonnelScreen> createState() => _S();
}

class _S extends ConsumerState<PersonnelScreen> with SingleTickerProviderStateMixin {
  late TabController tab;
  final searchCtrl = TextEditingController();
  String query = '';

  @override
  void initState() {
    super.initState();
    tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    tab.dispose();
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('العاملين', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        bottom: TabBar(controller: tab, labelColor: Colors.white,
            unselectedLabelColor: Colors.white60, indicatorColor: AppColors.gold,
            isScrollable: true, onTap: (_) => setState(() {}), tabs: const [
          Tab(text: 'العمال', icon: Icon(Icons.groups, size: 18)),
          Tab(text: 'المعلمين', icon: Icon(Icons.engineering, size: 18)),
          Tab(text: 'الموردين', icon: Icon(Icons.local_shipping, size: 18)),
          Tab(text: 'السائقين', icon: Icon(Icons.drive_eta, size: 18)),
        ]),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: searchCtrl,
            onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(
              hintText: _hintFor(tab.index),
              hintStyle: GoogleFonts.cairo(fontSize: 12),
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true, filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        Expanded(
          child: TabBarView(controller: tab, children: [
            _roleTab(PersonnelRole.worker),
            _roleTab(PersonnelRole.master),
            _roleTab(PersonnelRole.supplier),
            _roleTab(PersonnelRole.driver),
          ]),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.deepNavy, foregroundColor: Colors.white,
        onPressed: () => _upsertDialog(PersonnelRole.values[tab.index], null),
        icon: const Icon(Icons.add),
        label: Text('إضافة ${PersonnelRole.values[tab.index].arabicLabel}',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
      ),
    );
  }

  String _hintFor(int index) {
    switch (PersonnelRole.values[index]) {
      case PersonnelRole.worker:
        return 'بحث بالاسم أو الهاتف...';
      case PersonnelRole.master:
        return 'بحث بالاسم أو المهنة أو الهاتف...';
      case PersonnelRole.supplier:
        return 'بحث بالاسم أو الهاتف أو المواد...';
      case PersonnelRole.driver:
        return 'بحث بالاسم أو الهاتف أو نوع السيارة...';
    }
  }

  Widget _roleTab(PersonnelRole role) {
    final all = ref.watch(personnelByRoleProvider(role));
    ref.watch(personnelProvider);
    final q = query.trim().toLowerCase();
    final list = q.isEmpty
        ? all
        : all.where((p) => p.matches(q)).toList();
    if (list.isEmpty) {
      return Center(
          child: Text(query.isEmpty ? 'لا توجد بيانات' : 'لا نتائج مطابقة',
              style: GoogleFonts.cairo(color: AppColors.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final p = list[i];
        return GlassCard(
            child: Row(children: [
          Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                  color: AppColors.goldLight,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(_iconFor(role), color: AppColors.goldDark)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(p.name,
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                Text(_subtitleFor(p),
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ])),
          // Financial navigation button (Req #10).
          IconButton(
            tooltip: 'السجل المالي',
            icon: const Icon(Icons.account_balance_wallet_outlined,
                color: AppColors.deepNavy),
            onPressed: () => _openLedger(context, p),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') _upsertDialog(role, p);
              if (v == 'delete') {
                final ok = await confirmDelete(context,
                    title: 'حذف ${p.name}؟',
                    message: 'هل أنت متأكد من حذف هذا ${role.arabicLabel}؟');
                if (ok) {
                  await ref.read(personnelServiceProvider).delete(p);
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'edit',
                  child: Text('تعديل', style: GoogleFonts.cairo())),
              PopupMenuItem(
                  value: 'delete',
                  child: Text('حذف',
                      style: GoogleFonts.cairo(color: AppColors.error))),
            ],
          ),
        ]));
      },
    );
  }

  IconData _iconFor(PersonnelRole r) {
    switch (r) {
      case PersonnelRole.worker:
        return Icons.groups;
      case PersonnelRole.master:
        return Icons.engineering;
      case PersonnelRole.supplier:
        return Icons.local_shipping;
      case PersonnelRole.driver:
        return Icons.drive_eta;
    }
  }

  String _subtitleFor(PersonnelEntry p) {
    switch (p.role) {
      case PersonnelRole.worker:
        return '${p.phone} • ${p.location}';
      case PersonnelRole.master:
        return '${p.phone} • ${p.extra} • ${p.location}';
      case PersonnelRole.supplier:
        final base = '${p.phone} • ${p.location}';
        if (p.suppliedMaterials.trim().isEmpty) return base;
        return '$base • ${p.suppliedMaterials}';
      case PersonnelRole.driver:
        return '${p.phone} • ${p.extra}';
    }
  }

  void _upsertDialog(PersonnelRole role, PersonnelEntry? existing) {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final phoneC = TextEditingController(text: existing?.phone ?? '');
    final locC = TextEditingController(text: existing?.location ?? '');
    final extraC = TextEditingController(text: existing?.extra ?? '');
    final suppliedC = TextEditingController(text: existing?.suppliedMaterials ?? '');
    final isEdit = existing != null;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
            isEdit
                ? 'تعديل ${role.arabicLabel}'
                : 'إضافة ${role.arabicLabel}',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameC,
                decoration: const InputDecoration(labelText: 'الاسم *')),
            const SizedBox(height: 8),
            TextField(controller: phoneC,
                decoration: const InputDecoration(labelText: 'الهاتف *'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
            if (role == PersonnelRole.supplier) ...[
              const SizedBox(height: 8),
              TextField(controller: suppliedC,
                  decoration: const InputDecoration(
                      labelText: 'المواد التي يقدمها *',
                      hintText: 'مثال: سمنت، حديد، رمل'),
                  maxLines: 2),
            ],
            if (role != PersonnelRole.driver) ...[
              const SizedBox(height: 8),
              TextField(controller: locC,
                  decoration: const InputDecoration(labelText: 'الموقع')),
            ],
            if (role == PersonnelRole.master) ...[
              const SizedBox(height: 8),
              TextField(controller: extraC,
                  decoration:
                      const InputDecoration(labelText: 'المهنة / الحرفة *')),
            ],
            if (role == PersonnelRole.driver) ...[
              const SizedBox(height: 8),
              TextField(controller: extraC,
                  decoration:
                      const InputDecoration(labelText: 'نوع السيارة *')),
            ],
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () async {
              try {
                if (isEdit) {
                  await ref.read(personnelServiceProvider).update(existing,
                      name: nameC.text,
                      phone: phoneC.text,
                      location: locC.text,
                      extra: extraC.text,
                      suppliedMaterials: suppliedC.text);
                } else {
                  await ref.read(personnelServiceProvider).add(
                      role: role,
                      name: nameC.text,
                      phone: phoneC.text,
                      location: locC.text,
                      extra: extraC.text,
                      suppliedMaterials: suppliedC.text);
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
            child: Text(isEdit ? 'حفظ' : 'إضافة',
                style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  /// Financial jump: find project ledgers containing this person;
  /// Sprint 2026-09 Task 7: hide settled projects (remaining == 0).
  /// if multiple -> selector dialog, else open directly.
  void _openLedger(BuildContext context, PersonnelEntry p) {
    final matches = <String>{};
    for (final t in HiveInit.transactions.values) {
      if (t.projectId == null || t.projectId!.isEmpty) continue;
      final samePhone = (t.partyPhone ?? '').trim() == p.phone.trim() &&
          p.phone.trim().isNotEmpty;
      final sameName =
          t.partyName.trim().toLowerCase() == p.name.trim().toLowerCase();
      if (samePhone || sameName) matches.add(t.projectId!);
    }
    // Also include projects where a matching site procedure person id exists.
    for (final s in HiveInit.siteProcedures.values) {
      if (s.workerId == p.id ||
          s.masterId == p.id ||
          s.driverId == p.id) {
        matches.add(s.projectId);
      }
    }
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('لا يوجد سجل مالي لـ ${p.name} في أي مشروع',
              style: GoogleFonts.cairo())));
      return;
    }
    // Task 7 filter: keep only projects with pending dues for this person.
    final party = switch (p.role) {
      PersonnelRole.worker => TransactionParty.worker,
      PersonnelRole.master => TransactionParty.master,
      PersonnelRole.supplier => TransactionParty.supplier,
      PersonnelRole.driver => TransactionParty.driver,
    };
    final active = <String>[];
    for (final pid in matches) {
      final balances = FinanceEngine.personnelBalancesForProject(pid);
      double remaining = 0;
      var found = false;
      for (final e in balances.entries) {
        if (!e.key.startsWith('${party.index}|')) continue;
        if (e.value.phone.trim() == p.phone.trim() ||
            e.value.name.trim().toLowerCase() ==
                p.name.trim().toLowerCase()) {
          remaining = e.value.remaining;
          found = true;
          break;
        }
      }
      // If no balance row found (e.g. procedure id link only), check raw
      // scoped remaining by trying phone + name as partyId candidates.
      if (!found) {
        final byPhone = FinanceEngine.scopedRemaining(
            partyId: p.phone, party: party, projectId: pid);
        final byId = FinanceEngine.scopedRemaining(
            partyId: p.id, party: party, projectId: pid);
        remaining = byPhone > 0 ? byPhone : byId;
        if (remaining > 0.005) found = true;
      }
      if (found && remaining > 0.005) active.add(pid);
    }
    if (active.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'لا توجد مشاريع مستحقة لـ ${p.name} — كل الحسابات خالصة (المتبقي = 0)',
              style: GoogleFonts.cairo())));
      return;
    }
    final projects = active
        .map((id) => HiveInit.projects.get(id))
        .whereType<dynamic>()
        .toList();
    if (projects.length == 1) {
      _openProjectLedger(context, projects.first.id as String, p);
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('اختر مشروعاً لـ ${p.name}',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.separated(
            itemCount: projects.length,
            separatorBuilder: (_, __) => const Divider(height: 8),
            itemBuilder: (_, i) {
              final pr = projects[i];
              return ListTile(
                title: Text(pr.location as String,
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                subtitle: Text(pr.clientName as String,
                    style: GoogleFonts.cairo(fontSize: 11)),
                trailing:
                    const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  _openProjectLedger(
                      context, pr.id as String, p);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _openProjectLedger(
      BuildContext context, String projectId, PersonnelEntry p) {
    // Map personnel role -> transaction party.
    final party = switch (p.role) {
      PersonnelRole.worker => TransactionParty.worker,
      PersonnelRole.master => TransactionParty.master,
      PersonnelRole.supplier => TransactionParty.supplier,
      PersonnelRole.driver => TransactionParty.driver,
    };
    // Find the ledger key "${party.index}|${partyId}" — try phone first, then name match.
    String? key;
    final balances =
        FinanceEngine.personnelBalancesForProject(projectId);
    for (final e in balances.entries) {
      if (!e.key.startsWith('${party.index}|')) continue;
      if (e.value.phone.trim() == p.phone.trim() ||
          e.value.name.trim().toLowerCase() ==
              p.name.trim().toLowerCase()) {
        key = e.key;
        break;
      }
    }
    if (key == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('لا يوجد سجل مالي في هذا المشروع',
              style: GoogleFonts.cairo())));
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PersonProfileScreen(
                projectId: projectId, party: party, partyKey: key!)));
  }
}
