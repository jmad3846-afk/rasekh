import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_colors.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/factory/presentation/screens/factory_screen.dart';
import 'features/projects/presentation/screens/projects_screen.dart';
import 'features/finance/presentation/screens/ledger_screen.dart';
import 'features/backup/presentation/backup_screen.dart';
import 'features/personnel/presentation/personnel_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override State<AppShell> createState()=> _S();
}
class _S extends State<AppShell> {
  int idx=0;
  final screens = const [DashboardScreen(), FactoryScreen(), ProjectsScreen(), PersonnelScreen(), LedgerScreen(), BackupScreen()];
  @override Widget build(BuildContext context){
    return Scaffold(
      body: screens[idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx, onDestinationSelected: (v)=> setState(()=> idx=v),
        backgroundColor: Colors.white, indicatorColor: AppColors.goldLight,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard, color: AppColors.deepNavy), label: 'الرئيسية'),
          NavigationDestination(icon: const Icon(Icons.factory_outlined), selectedIcon: const Icon(Icons.factory, color: AppColors.deepNavy), label: 'المعمل'),
          NavigationDestination(icon: const Icon(Icons.business_outlined), selectedIcon: const Icon(Icons.business, color: AppColors.deepNavy), label: 'التعهدات'),
          NavigationDestination(icon: const Icon(Icons.groups_outlined), selectedIcon: const Icon(Icons.groups, color: AppColors.deepNavy), label: 'العاملين'),
          NavigationDestination(icon: const Icon(Icons.account_balance_wallet_outlined), selectedIcon: const Icon(Icons.account_balance_wallet, color: AppColors.deepNavy), label: 'المالية'),
          NavigationDestination(icon: const Icon(Icons.shield_outlined), selectedIcon: const Icon(Icons.shield, color: AppColors.deepNavy), label: 'النسخ'),
        ],
        labelTextStyle: WidgetStateProperty.resolveWith((states){
          if(states.contains(WidgetState.selected)) return GoogleFonts.cairo(fontSize:11, fontWeight: FontWeight.w800, color: AppColors.deepNavy);
          return GoogleFonts.cairo(fontSize:11, color: AppColors.textSecondary);
        }),
      ),
    );
  }
}
