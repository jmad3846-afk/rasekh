import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

@HiveType(typeId: 0)
class Product extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String name; // e.g. Cement, Block
  @HiveField(2) String category;
  @HiveField(3) double unitPrice;
  @HiveField(4) double stockQuantity;
  @HiveField(5) String unit; // طن, قطعة, م3
  @HiveField(6) DateTime createdAt;
  @HiveField(7) String? imagePath;

  Product({
    String? id, required this.name, required this.category,
    required this.unitPrice, required this.stockQuantity,
    this.unit = 'قطعة', DateTime? createdAt, this.imagePath,
  }) : id = id ?? const Uuid().v4(), createdAt = createdAt ?? DateTime.now();

  Map<String,dynamic> toJson() => {
    'id': id, 'name': name, 'category': category,
    'unitPrice': unitPrice, 'stockQuantity': stockQuantity,
    'unit': unit, 'createdAt': createdAt.toIso8601String(), 'imagePath': imagePath
  };
  factory Product.fromJson(Map<String,dynamic> j) => Product(
    id: j['id'], name: j['name'], category: j['category'],
    unitPrice: (j['unitPrice'] as num).toDouble(),
    stockQuantity: (j['stockQuantity'] as num).toDouble(),
    unit: j['unit'] ?? 'قطعة',
    createdAt: DateTime.parse(j['createdAt']),
    imagePath: j['imagePath'],
  );
}

class ProductAdapter extends TypeAdapter<Product> {
  @override final typeId = 0;
  @override Product read(BinaryReader r) {
    return Product(
      id: r.readString(), name: r.readString(), category: r.readString(),
      unitPrice: r.readDouble(), stockQuantity: r.readDouble(),
      unit: r.readString(), createdAt: DateTime.fromMillisecondsSinceEpoch(r.readInt()),
      imagePath: r.readBool() ? r.readString() : null,
    );
  }
  @override void write(BinaryWriter w, Product o) {
    w.writeString(o.id); w.writeString(o.name); w.writeString(o.category);
    w.writeDouble(o.unitPrice); w.writeDouble(o.stockQuantity);
    w.writeString(o.unit); w.writeInt(o.createdAt.millisecondsSinceEpoch);
    w.writeBool(o.imagePath != null); if (o.imagePath != null) w.writeString(o.imagePath!);
  }
}
