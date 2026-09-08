import 'package:flutter/material.dart';

class AppColors {
  // Industrial palette
  static const deepNavy = Color(0xFF0F172A); // Slate 900
  static const navyLight = Color(0xFF1E293B); // Slate 800
  static const navyCard = Color(0xFF1E293B);
  static const gold = Color(0xFFF59E0B); // Amber 500 - Construction Gold
  static const goldDark = Color(0xFFD97706);
  static const goldLight = Color(0xFFFEF3C7);
  static const background = Color(0xFFF8FAFC); // Slate 50 - Off-white
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textOnDark = Colors.white;
  static const success = Color(0xFF10B981); // Emerald
  static const successBg = Color(0xFFECFDF5);
  static const error = Color(0xFFEF4444);
  static const errorBg = Color(0xFFFEF2F2);
  static const warning = Color(0xFFF59E0B); // Amber for pending
  static const warningBg = Color(0xFFFEF3C7);
  static const border = Color(0xFFE2E8F0);
  static const divider = Color(0xFFF1F5F9);

  // Gradients
  static const navyGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF334155)],
    begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const goldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft, end: Alignment.bottomRight);
}
