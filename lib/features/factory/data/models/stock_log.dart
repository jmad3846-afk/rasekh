import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// Inventory restock audit log (Sprint 2026-09: financial batch tracking).
/// [purchaseCost] = TOTAL batch cost (what the batch cost us).
/// [downPayment] = initial amount paid to the inventory supplier (0 = unpaid).
/// Remaining batch debt = purchaseCost - downPayment - later partial payments
/// (derived live from the supplier ledger, see FinanceEngine).
/// Only [quantityAdded] mutates Product.stockQuantity.
@HiveType(typeId: 23)
class StockLog extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String productId;
  @HiveField(2) String productName;
  @HiveField(3) double quantityAdded;
  @HiveField(4) double purchaseCost;
  @HiveField(5) String supplierName;
  @HiveField(6) String supplierPhone;
  @HiveField(7) String notes;
  @HiveField(8) DateTime createdAt;
  /// Sprint 2026-09: initial down payment to the inventory supplier (SYP).
  /// Posted as a supplier PAYMENT entry linked to this batch.
  @HiveField(9) double downPayment;
  /// Sprint: materials this inventory supplier sells (recorded per batch).
  /// Latest non-empty value per supplier is used for auto-complete profiles.
  @HiveField(10) String suppliedMaterials;

  StockLog({
    String? id,
    required this.productId,
    required this.productName,
    required this.quantityAdded,
    this.purchaseCost = 0,
    this.supplierName = '',
    this.supplierPhone = '',
    this.notes = '',
    DateTime? createdAt,
    this.downPayment = 0,
    this.suppliedMaterials = '',
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Total batch cost (SYP).
  double get batchTotal => purchaseCost;

  /// Unpaid remainder of THIS batch at restock time (before partial payments).
  double get batchRemaining => (purchaseCost - downPayment).clamp(0, double.infinity).toDouble();

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'productName': productName,
        'quantityAdded': quantityAdded,
        'purchaseCost': purchaseCost,
        'supplierName': supplierName,
        'supplierPhone': supplierPhone,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'downPayment': downPayment,
        'suppliedMaterials': suppliedMaterials,
      };

  factory StockLog.fromJson(Map<String, dynamic> j) => StockLog(
        id: j['id'],
        productId: j['productId'] ?? '',
        productName: j['productName'] ?? '',
        quantityAdded: ((j['quantityAdded'] as num?) ?? 0).toDouble(),
        purchaseCost: ((j['purchaseCost'] as num?) ?? 0).toDouble(),
        supplierName: j['supplierName'] ?? '',
        supplierPhone: j['supplierPhone'] ?? '',
        notes: j['notes'] ?? '',
        createdAt: DateTime.parse(j['createdAt']),
        downPayment: ((j['downPayment'] as num?) ?? 0).toDouble(),
        suppliedMaterials: j['suppliedMaterials'] ?? '',
      );
}

class StockLogAdapter extends TypeAdapter<StockLog> {
  @override
  final typeId = 23;

  @override
  StockLog read(BinaryReader r) {
    final log = StockLog(
      id: r.readString(),
      productId: r.readString(),
      productName: r.readString(),
      quantityAdded: r.readDouble(),
      purchaseCost: r.readDouble(),
      supplierName: r.readString(),
      supplierPhone: r.readString(),
      notes: r.readString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.readInt()),
    );
    // Backward-compatible: old rows lack the down-payment trailing field.
    try {
      log.downPayment = r.readDouble();
    } catch (_) {
      log.downPayment = 0;
    }
    // Backward-compatible: rows saved before suppliedMaterials existed.
    try {
      log.suppliedMaterials = r.readString();
    } catch (_) {
      log.suppliedMaterials = '';
    }
    return log;
  }

  @override
  void write(BinaryWriter w, StockLog o) {
    w.writeString(o.id);
    w.writeString(o.productId);
    w.writeString(o.productName);
    w.writeDouble(o.quantityAdded);
    w.writeDouble(o.purchaseCost);
    w.writeString(o.supplierName);
    w.writeString(o.supplierPhone);
    w.writeString(o.notes);
    w.writeInt(o.createdAt.millisecondsSinceEpoch);
    w.writeDouble(o.downPayment);
    w.writeString(o.suppliedMaterials);
  }
}
