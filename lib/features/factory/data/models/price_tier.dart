import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// Sprint 2026-09: historical catalog-price tier for a factory product.
///
/// A new tier is created every time the product's catalog [unitPrice] changes:
/// - the previous active tier is closed ([endedAt] = change time),
/// - a new tier opens ([startedAt] = change time, [endedAt] = null).
/// Sales analytics attributes each invoice line to the tier whose
/// [startedAt, endedAt) interval contains the invoice date, so users can
/// see exact sold volumes per price-change interval.
@HiveType(typeId: 24)
class ProductPriceTier extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String productId;
  @HiveField(2) String productName;
  @HiveField(3) double unitPrice;
  @HiveField(4) String unit;
  @HiveField(5) DateTime startedAt;
  @HiveField(6) DateTime? endedAt;
  @HiveField(7) DateTime createdAt;

  ProductPriceTier({
    String? id,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    this.unit = 'قطعة',
    DateTime? startedAt,
    this.endedAt,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        startedAt = startedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  bool get isActive => endedAt == null;

  /// Does [date] fall inside this tier's effective interval?
  bool covers(DateTime date) {
    if (date.isBefore(startedAt)) return false;
    if (endedAt != null && !date.isBefore(endedAt!)) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'productName': productName,
        'unitPrice': unitPrice,
        'unit': unit,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory ProductPriceTier.fromJson(Map<String, dynamic> j) =>
      ProductPriceTier(
        id: j['id'],
        productId: j['productId'] ?? '',
        productName: j['productName'] ?? '',
        unitPrice: ((j['unitPrice'] as num?) ?? 0).toDouble(),
        unit: j['unit'] ?? 'قطعة',
        startedAt: DateTime.parse(j['startedAt']),
        endedAt: j['endedAt'] == null
            ? null
            : DateTime.parse(j['endedAt'] as String),
        createdAt: DateTime.parse(j['createdAt']),
      );
}

class ProductPriceTierAdapter extends TypeAdapter<ProductPriceTier> {
  @override
  final typeId = 24;

  @override
  ProductPriceTier read(BinaryReader r) {
    final id = r.readString();
    final productId = r.readString();
    final productName = r.readString();
    final unitPrice = r.readDouble();
    final unit = r.readString();
    final startedAt =
        DateTime.fromMillisecondsSinceEpoch(r.readInt());
    final hasEnd = r.readBool();
    final endedAt = hasEnd
        ? DateTime.fromMillisecondsSinceEpoch(r.readInt())
        : null;
    final createdAt =
        DateTime.fromMillisecondsSinceEpoch(r.readInt());
    return ProductPriceTier(
      id: id,
      productId: productId,
      productName: productName,
      unitPrice: unitPrice,
      unit: unit,
      startedAt: startedAt,
      endedAt: endedAt,
      createdAt: createdAt,
    );
  }

  @override
  void write(BinaryWriter w, ProductPriceTier o) {
    w.writeString(o.id);
    w.writeString(o.productId);
    w.writeString(o.productName);
    w.writeDouble(o.unitPrice);
    w.writeString(o.unit);
    w.writeInt(o.startedAt.millisecondsSinceEpoch);
    w.writeBool(o.endedAt != null);
    if (o.endedAt != null) {
      w.writeInt(o.endedAt!.millisecondsSinceEpoch);
    }
    w.writeInt(o.createdAt.millisecondsSinceEpoch);
  }
}
