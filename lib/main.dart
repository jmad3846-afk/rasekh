import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/database/hive_init.dart';
import 'core/theme/app_theme.dart';
import 'features/factory/data/models/product.dart';
import 'features/licensing/presentation/license_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveInit.init();
  if (HiveInit.products.isEmpty) {
    final demo = [
      Product(name: 'سمنت مقاوم', category: 'سمنت', unitPrice: 95000, stockQuantity: 120, unit: 'طن'),
      Product(name: 'بلوك 20سم', category: 'بلوك', unitPrice: 750, stockQuantity: 5000, unit: 'قطعة'),
      Product(name: 'رمل مغسول', category: 'رمل', unitPrice: 25000, stockQuantity: 80, unit: 'م3'),
      Product(name: 'حديد 12ملم', category: 'حديد', unitPrice: 850000, stockQuantity: 15, unit: 'طن'),
    ];
    for (final p in demo) await HiveInit.products.put(p.id, p);
  }
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override Widget build(BuildContext context){
    return MaterialApp(
      title: 'راسخ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, child)=> Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const LicenseGate(),
    );
  }
}
