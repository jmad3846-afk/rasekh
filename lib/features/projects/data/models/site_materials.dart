import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// Req #11A: raw materials required for a project.
@HiveType(typeId: 14)
class RequiredMaterial extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String projectId;
  @HiveField(2) String name;
  @HiveField(3) String category;
  @HiveField(4) double quantity; // planned / remaining stock for the project
  @HiveField(5) String unit;
  @HiveField(6) double unitPrice;
  @HiveField(7) DateTime createdAt;
  /// Mandatory link to Personnel supplier (Task 2).
  @HiveField(8) String supplierId;
  @HiveField(9) String supplierName;
  @HiveField(10) String supplierPhone;
  /// Sprint 2026-09: initial down payment to supplier (SYP).
  /// Recorded as a supplier PAYMENT entry linked to this material.
  @HiveField(11) double downPayment;

  RequiredMaterial({
    String? id, required this.projectId, required this.name,
    this.category = '', required this.quantity,
    this.unit = 'قطعة', this.unitPrice = 0, DateTime? createdAt,
    this.supplierId = '', this.supplierName = '', this.supplierPhone = '',
    this.downPayment = 0,
  }) : id = id ?? const Uuid().v4(), createdAt = createdAt ?? DateTime.now();

  double get totalValue => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
    'id': id, 'projectId': projectId, 'name': name, 'category': category,
    'quantity': quantity, 'unit': unit, 'unitPrice': unitPrice,
    'createdAt': createdAt.toIso8601String(),
    'supplierId': supplierId, 'supplierName': supplierName,
    'supplierPhone': supplierPhone, 'downPayment': downPayment,
  };
  factory RequiredMaterial.fromJson(Map<String, dynamic> j) => RequiredMaterial(
    id: j['id'], projectId: j['projectId'], name: j['name'],
    category: j['category'] ?? '', quantity: (j['quantity'] as num).toDouble(),
    unit: j['unit'] ?? 'قطعة', unitPrice: ((j['unitPrice'] as num?) ?? 0).toDouble(),
    createdAt: DateTime.parse(j['createdAt']),
    supplierId: (j['supplierId'] as String?) ?? '',
    supplierName: (j['supplierName'] as String?) ?? '',
    supplierPhone: (j['supplierPhone'] as String?) ?? '',
    downPayment: ((j['downPayment'] as num?) ?? 0).toDouble(),
  );
}

class RequiredMaterialAdapter extends TypeAdapter<RequiredMaterial> {
  @override final typeId = 14;
  @override RequiredMaterial read(BinaryReader r) {
    final m = RequiredMaterial(
      id: r.readString(), projectId: r.readString(), name: r.readString(),
      category: r.readString(), quantity: r.readDouble(),
      unit: r.readString(), unitPrice: r.readDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.readInt()),
    );
    // Backward-compatible: old rows lack supplier trailing fields.
    try {
      m.supplierId = r.readString();
    } catch (_) {
      m.supplierId = '';
    }
    try {
      m.supplierName = r.readString();
    } catch (_) {
      m.supplierName = '';
    }
    try {
      m.supplierPhone = r.readString();
    } catch (_) {
      m.supplierPhone = '';
    }
    try {
      m.downPayment = r.readDouble();
    } catch (_) {
      m.downPayment = 0;
    }
    return m;
  }
  @override void write(BinaryWriter w, RequiredMaterial o) {
    w.writeString(o.id); w.writeString(o.projectId); w.writeString(o.name);
    w.writeString(o.category); w.writeDouble(o.quantity);
    w.writeString(o.unit); w.writeDouble(o.unitPrice);
    w.writeInt(o.createdAt.millisecondsSinceEpoch);
    w.writeString(o.supplierId); w.writeString(o.supplierName);
    w.writeString(o.supplierPhone);
    w.writeDouble(o.downPayment);
  }
}

/// Req #11B: a daily journal entry inside a project.
/// Procedures can ONLY be added inside a daily log.
@HiveType(typeId: 15)
class DailyLog extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String projectId;
  @HiveField(2) DateTime date;
  @HiveField(3) String title;
  @HiveField(4) String notes;
  @HiveField(5) DateTime createdAt;

  DailyLog({
    String? id, required this.projectId, DateTime? date,
    this.title = '', this.notes = '', DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       date = date ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id, 'projectId': projectId, 'date': date.toIso8601String(),
    'title': title, 'notes': notes, 'createdAt': createdAt.toIso8601String(),
  };
  factory DailyLog.fromJson(Map<String, dynamic> j) => DailyLog(
    id: j['id'], projectId: j['projectId'], date: DateTime.parse(j['date']),
    title: j['title'] ?? '', notes: j['notes'] ?? '',
    createdAt: DateTime.parse(j['createdAt']),
  );
}

class DailyLogAdapter extends TypeAdapter<DailyLog> {
  @override final typeId = 15;
  @override DailyLog read(BinaryReader r) => DailyLog(
    id: r.readString(), projectId: r.readString(),
    date: DateTime.fromMillisecondsSinceEpoch(r.readInt()),
    title: r.readString(), notes: r.readString(),
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.readInt()),
  );
  @override void write(BinaryWriter w, DailyLog o) {
    w.writeString(o.id); w.writeString(o.projectId);
    w.writeInt(o.date.millisecondsSinceEpoch);
    w.writeString(o.title); w.writeString(o.notes);
    w.writeInt(o.createdAt.millisecondsSinceEpoch);
  }
}
