import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/widgets.dart';
import '../../../../core/theme/finance_widgets.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/database/hive_init.dart';
import '../../finance/logic/finance_engine.dart';
import '../../finance/presentation/screens/ledger_screen.dart';

/// Req #3B: unpaid personnel -> projects -> personnel list -> profile + pay.
class UnpaidPersonnelScreen extends ConsumerWidget {
  const UnpaidPersonnelScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(transactionsProvider);
    final projectIds = FinanceEngine.projectsWithUnpaidPersonnel();
    final projects = HiveInit.projects.values
        .where((p) => projectIds.contains(p.id))
        .toList();
    return Scaffold(
      appBar: AppBar(
          title: Text('الأشخاص الواجب الدفع لهم',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800))),
      body: projects.isEmpty
          ? Center(
              child: Text('لا توجد أرصدة معلقة للعاملين',
                  style:
                      GoogleFonts.cairo(color: AppColors.textSecondary)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: projects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final pr = projects[i];
                final balances =
                    FinanceEngine.personnelBalancesForProject(pr.id);
                final pending = balances.values
                    .where((b) => b.remaining > 0.005)
                    .toList();
                final totalPending = pending.fold(
                    0.0, (s, b) => s + b.remaining);
                return GlassCard(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ProjectPersonnelScreen(projectId: pr.id))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(pr.location,
                                  style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis)),
                          // Sprint 2026-09 Task 1: SYP-only drill-down.
                          const CurrencyBadge(AppCurrency.syp),
                        ]),
                        Text('${pr.clientName} • ${pending.length} شخص معلق',
                            style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                            'إجمالي معلق: ${Money.withCurrency(totalPending, AppCurrency.syp)}',
                            style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.error)),
                      ]),
                );
              },
            ),
    );
  }
}

class ProjectPersonnelScreen extends ConsumerWidget {
  final String projectId;
  const ProjectPersonnelScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(transactionsProvider);
    final project = HiveInit.projects.get(projectId);
    if (project == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('المشروع غير موجود')));
    }
    final balances = FinanceEngine.personnelBalancesForProject(projectId);
    final list = balances.entries.toList()
      ..sort((a, b) => b.value.remaining.compareTo(a.value.remaining));
    return Scaffold(
      appBar: AppBar(
          title: Text('عاملو ${project.location}',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800))),
      body: list.isEmpty
          ? Center(
              child: Text('لا توجد حركات عاملين',
                  style:
                      GoogleFonts.cairo(color: AppColors.textSecondary)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final b = list[i].value;
                return GlassCard(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PersonProfileScreen(
                              projectId: projectId,
                              party: b.party,
                              partyKey: list[i].key))),
                  child: Row(children: [
                    const Icon(Icons.person, color: AppColors.goldDark),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(b.name,
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis),
                          Text('${b.phone} • ${_partyLabel(b.party)}',
                              style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ])),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                              'متبقي ${Money.withCurrency(b.remaining, AppCurrency.syp)}',
                              style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: b.remaining > 0
                                      ? AppColors.error
                                      : AppColors.success)),
                          Text(
                              'مدفوع ${Money.withCurrency(b.paid, AppCurrency.syp)}',
                              style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ]),
                  ]),
                );
              },
            ),
    );
  }

  String _partyLabel(dynamic p) => p.toString().split('.').last;
}

/// Personal financial profile with instant "Make Payment / دفع دفعة".
class PersonProfileScreen extends ConsumerWidget {
  final String projectId;
  final dynamic party;
  final String partyKey; // "${party.index}|${partyId}"
  const PersonProfileScreen(
      {super.key,
      required this.projectId,
      required this.party,
      required this.partyKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(transactionsProvider);
    final parts = partyKey.split('|');
    final pid = parts.length > 1 ? parts.sublist(1).join('|') : partyKey;
    final txs = HiveInit.transactions.values
        .where((t) =>
            t.projectId == projectId &&
            t.party == party &&
            t.partyId == pid)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (txs.isEmpty) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('لا توجد حركات')));
    }
    final first = txs.first;
    final s = FinanceEngine.personSummary(txs);
    // Sprint 2026-09 Task 1: SYP-only drill-down.
    const cur = AppCurrency.syp;
    return Scaffold(
      appBar: AppBar(
          title: Text(first.partyName,
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(
              child: _card('المتبقي للدفع', Money.withCurrency(s.remaining, cur),
                  AppColors.error, AppColors.errorBg)),
          const SizedBox(width: 10),
          Expanded(
              child: _card('مجموع المدفوع', Money.withCurrency(s.paid, cur),
                  AppColors.success, AppColors.successBg)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => showPaymentDialog(
              context: context,
              party: first.party,
              partyId: first.partyId,
              partyName: first.partyName,
              partyPhone: first.partyPhone,
              projectId: projectId,
              initialCurrency: cur,
              onSaved: () {},
            ),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepNavy,
                foregroundColor: Colors.white),
            icon: const Icon(Icons.payments_outlined),
            label: Text('Make Payment / دفع دفعة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),
        for (final t in txs)
          GlassCard(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Flexible(
                            child: Text(t.source,
                                style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 6),
                        // Sprint 2026-09 Task 1: SYP-only.
                        const CurrencyBadge(AppCurrency.syp),
                      ]),
                      Text('${t.reason} • ${t.createdAt.toString().substring(0, 10)}',
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ])),
                Text(
                    '${t.type.toString().contains('payment') ? '-' : '+'}${Money.withCurrency(t.amount, AppCurrency.syp)}',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800, fontSize: 12)),
              ])),
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
