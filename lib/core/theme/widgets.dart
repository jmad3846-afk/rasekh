import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

// Glass / premium card
class GlassCard extends StatelessWidget {
  final Widget child; final EdgeInsets? padding; final VoidCallback? onTap;
  const GlassCard({super.key, required this.child, this.padding, this.onTap});
  @override Widget build(BuildContext context){
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0,4))],
        ),
        child: child,
      ));
  }
}

class StatusBadge extends StatelessWidget {
  final String label; final bool isCompleted;
  const StatusBadge.pending(this.label,{super.key}): isCompleted=false;
  const StatusBadge.completed(this.label,{super.key}): isCompleted=true;
  const StatusBadge({super.key, required this.label, required this.isCompleted});
  @override Widget build(BuildContext context){
    final bg = isCompleted ? AppColors.successBg : AppColors.warningBg;
    final fg = isCompleted ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children:[
        Container(width:7,height:7,decoration:BoxDecoration(color:fg,shape:BoxShape.circle)),
        const SizedBox(width:6),
        Text(label, style: GoogleFonts.cairo(fontSize:12,fontWeight:FontWeight.w700,color:fg)),
      ]),
    );
  }
}

class FinanceSummaryCard extends StatelessWidget {
  final String title; final String amount; final IconData icon; final Color color; final String subtitle;
  const FinanceSummaryCard({super.key, required this.title, required this.amount, required this.icon, required this.color, required this.subtitle});
  @override Widget build(BuildContext context){
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Row(children:[
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon,color:color,size:20)),
          const Spacer(),
          Icon(Icons.trending_up, color: color.withOpacity(0.6), size:18),
        ]),
        const SizedBox(height:12),
        Text(title, style: GoogleFonts.cairo(fontSize:12,color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height:2),
        Text(amount, style: GoogleFonts.cairo(fontSize:18,fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        Text(subtitle, style: GoogleFonts.cairo(fontSize:11,color: AppColors.textSecondary)),
      ]),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title; final String? action; final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.action, this.onAction});
  @override Widget build(BuildContext context){
    return Row(children:[
      Text(title, style: GoogleFonts.cairo(fontSize:16,fontWeight: FontWeight.w800)),
      const Spacer(),
      if(action!=null) TextButton(onPressed:onAction, child: Text(action!, style: GoogleFonts.cairo(color: AppColors.goldDark, fontWeight: FontWeight.w700))),
    ]);
  }
}
