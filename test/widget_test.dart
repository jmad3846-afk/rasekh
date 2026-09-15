// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:factory_managment/features/factory/data/models/stock_log.dart';
import 'package:factory_managment/features/factory/presentation/screens/product_form.dart';
import 'package:factory_managment/features/finance/logic/finance_engine.dart';

void main() {
  test('Category field validator accepts a blank string', () {
    expect(ProductFormSheet.optionalCategoryValidator(''), isNull);
    expect(ProductFormSheet.optionalCategoryValidator('   '), isNull);
  });

  test('Stock log query can match by supplier or person name', () {
    final log = StockLog(
      productId: 'p1',
      productName: 'سمنت',
      quantityAdded: 10,
      purchaseCost: 100,
      supplierName: 'فارس المورد',
      supplierPhone: '09991110011',
      suppliedMaterials: 'سمنت',
      notes: 'restock',
    );

    expect(FinanceEngine.matchesStockLogQuery(log, 'فارس'), isTrue);
    expect(FinanceEngine.matchesStockLogQuery(log, '09991110011'), isTrue);
    expect(FinanceEngine.matchesStockLogQuery(log, 'غير موجود'), isFalse);
  });
}
