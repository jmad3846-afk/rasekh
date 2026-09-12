import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/currency.dart';

/// Req #11: new contracting procedure model (lives inside a DailyLog).
@HiveType(typeId: 20)
enum SiteProcedureKind {
  @HiveField(0) worker, // إجرائية عامل
  @HiveField(1) master, // إجرائية معلم
}

class SiteProcedureKindAdapter extends TypeAdapter<SiteProcedureKind> {
  @override final typeId = 20;
  @override SiteProcedureKind read(BinaryReader r) {
    final i = r.readInt();
    if (i < 0 || i >= SiteProcedureKind.values.length) return SiteProcedureKind.worker;
    return SiteProcedureKind.values[i];
  }
  @override void write(BinaryWriter w, SiteProcedureKind o) => w.writeInt(o.index);
}

@HiveType(typeId: 21)
enum MasterContractType {
  @HiveField(0) daily, // يومية
  @HiveField(1) lumpSum, // مقطوع
}

class MasterContractTypeAdapter extends TypeAdapter<MasterContractType> {
  @override final typeId = 21;
  @override MasterContractType read(BinaryReader r) {
    final i = r.readInt();
    if (i < 0 || i >= MasterContractType.values.length) return MasterContractType.daily;
    return MasterContractType.values[i];
  }
  @override void write(BinaryWriter w, MasterContractType o) => w.writeInt(o.index);
}

/// Consumed raw material — deducted from the project's RequiredMaterials.
@HiveType(typeId: 22)
class ConsumedMaterial extends HiveObject {
  @HiveField(0) String materialId;
  @HiveField(1) String materialName;
  @HiveField(2) double quantity;
  @HiveField(3) String unit;

  ConsumedMaterial({
    required this.materialId, required this.materialName,
    required this.quantity, this.unit = 'قطعة',
  });

  Map<String, dynamic> toJson() => {
    'materialId': materialId, 'materialName': materialName,
    'quantity': quantity, 'unit': unit,
  };
  factory ConsumedMaterial.fromJson(Map<String, dynamic> j) => ConsumedMaterial(
    materialId: j['materialId'], materialName: j['materialName'],
    quantity: (j['quantity'] as num).toDouble(), unit: j['unit'] ?? 'قطعة',
  );
}

class ConsumedMaterialAdapter extends TypeAdapter<ConsumedMaterial> {
  @override final typeId = 22;
  @override ConsumedMaterial read(BinaryReader r) => ConsumedMaterial(
    materialId: r.readString(), materialName: r.readString(),
    quantity: r.readDouble(), unit: r.readString(),
  );
  @override void write(BinaryWriter w, ConsumedMaterial o) {
    w.writeString(o.materialId); w.writeString(o.materialName);
    w.writeDouble(o.quantity); w.writeString(o.unit);
  }
}

/// Req #11 – Type 1 (worker) & Type 2 (master) procedures.
///
/// Total cost = worker/master wage + driver wage (transport).
@HiveType(typeId: 18)
class SiteProcedure extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String projectId;
  @HiveField(2) String dailyLogId;
  @HiveField(3) SiteProcedureKind kind;
  // Worker fields
  @HiveField(4) String workerId;
  @HiveField(5) String workerName;
  @HiveField(6) double workerWage;
  // Master fields
  @HiveField(7) String masterId;
  @HiveField(8) String masterName;
  @HiveField(9) MasterContractType contractType;
  @HiveField(10) double dailyRate;
  @HiveField(11) String description; // work done / procedure description
  @HiveField(12) double agreedTotal; // lump-sum total agreed price
  @HiveField(13) String agreementPerUnit; // كم متفقين عالوحدة (info only)
  // Shared
  @HiveField(14) List<ConsumedMaterial> consumedMaterials;
  @HiveField(15) bool needVehicle;
  @HiveField(16) String driverId;
  @HiveField(17) String driverName;
  @HiveField(18) double driverWage;
  @HiveField(19) String transportNotes;
  @HiveField(20) String notes;
  @HiveField(21) double totalCost;
  @HiveField(22) DateTime date;
  @HiveField(23) AppCurrency currency;
  @HiveField(24) DateTime createdAt;

  SiteProcedure({
    String? id,
    required this.projectId,
    required this.dailyLogId,
    required this.kind,
    this.workerId = '', this.workerName = '', this.workerWage = 0,
    this.masterId = '', this.masterName = '',
    this.contractType = MasterContractType.daily,
    this.dailyRate = 0,
    this.description = '',
    this.agreedTotal = 0,
    this.agreementPerUnit = '',
    List<ConsumedMaterial>? consumedMaterials,
    this.needVehicle = false,
    this.driverId = '', this.driverName = '',
    this.driverWage = 0, this.transportNotes = '',
    this.notes = '',
    double? totalCost,
    DateTime? date,
    this.currency = AppCurrency.syp,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       consumedMaterials = consumedMaterials ?? [],
       date = date ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now(),
       totalCost = totalCost ?? 0 {
    recalc();
  }

  double get baseWage {
    if (kind == SiteProcedureKind.worker) return workerWage;
    return contractType == MasterContractType.daily ? dailyRate : agreedTotal;
  }

  String get personName => kind == SiteProcedureKind.worker ? workerName : masterName;

  void recalc() {
    totalCost = baseWage + (needVehicle ? driverWage : 0);
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'projectId': projectId, 'dailyLogId': dailyLogId,
    'kind': kind.index,
    'workerId': workerId, 'workerName': workerName, 'workerWage': workerWage,
    'masterId': masterId, 'masterName': masterName,
    'contractType': contractType.index, 'dailyRate': dailyRate,
    'description': description, 'agreedTotal': agreedTotal,
    'agreementPerUnit': agreementPerUnit,
    'consumedMaterials': consumedMaterials.map((e) => e.toJson()).toList(),
    'needVehicle': needVehicle, 'driverId': driverId, 'driverName': driverName,
    'driverWage': driverWage, 'transportNotes': transportNotes,
    'notes': notes, 'totalCost': totalCost,
    'date': date.toIso8601String(), 'currency': currency.code,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SiteProcedure.fromJson(Map<String, dynamic> j) {
    final p = SiteProcedure(
      id: j['id'], projectId: j['projectId'], dailyLogId: j['dailyLogId'],
      kind: SiteProcedureKind.values[((j['kind'] as num).toInt()).clamp(0, SiteProcedureKind.values.length - 1)],
      workerId: j['workerId'] ?? '', workerName: j['workerName'] ?? '',
      workerWage: ((j['workerWage'] as num?) ?? 0).toDouble(),
      masterId: j['masterId'] ?? '', masterName: j['masterName'] ?? '',
      contractType: MasterContractType.values[((j['contractType'] as num?)?.toInt() ?? 0).clamp(0, MasterContractType.values.length - 1)],
      dailyRate: ((j['dailyRate'] as num?) ?? 0).toDouble(),
      description: j['description'] ?? '',
      agreedTotal: ((j['agreedTotal'] as num?) ?? 0).toDouble(),
      agreementPerUnit: j['agreementPerUnit'] ?? '',
      consumedMaterials: ((j['consumedMaterials'] as List?) ?? [])
          .map((e) => ConsumedMaterial.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      needVehicle: j['needVehicle'] ?? false,
      driverId: j['driverId'] ?? '', driverName: j['driverName'] ?? '',
      driverWage: ((j['driverWage'] as num?) ?? 0).toDouble(),
      transportNotes: j['transportNotes'] ?? '',
      notes: j['notes'] ?? '',
      totalCost: ((j['totalCost'] as num?) ?? 0).toDouble(),
      date: DateTime.parse(j['date']),
      currency: AppCurrencyX.fromString(j['currency'] as String?),
      createdAt: DateTime.parse(j['createdAt']),
    );
    p.recalc();
    return p;
  }
}

class SiteProcedureAdapter extends TypeAdapter<SiteProcedure> {
  @override final typeId = 18;
  @override SiteProcedure read(BinaryReader r) {
    final p = SiteProcedure(
      id: r.readString(), projectId: r.readString(), dailyLogId: r.readString(),
      kind: SiteProcedureKind.values[r.readInt().clamp(0, SiteProcedureKind.values.length - 1)],
      workerId: r.readString(), workerName: r.readString(), workerWage: r.readDouble(),
      masterId: r.readString(), masterName: r.readString(),
      contractType: MasterContractType.values[r.readInt().clamp(0, MasterContractType.values.length - 1)],
      dailyRate: r.readDouble(), description: r.readString(),
      agreedTotal: r.readDouble(), agreementPerUnit: r.readString(),
      consumedMaterials: (r.readList() as List).cast<ConsumedMaterial>(),
      needVehicle: r.readBool(),
      driverId: r.readString(), driverName: r.readString(),
      driverWage: r.readDouble(), transportNotes: r.readString(),
      notes: r.readString(), totalCost: r.readDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(r.readInt()),
      currency: AppCurrency.values[r.readInt().clamp(0, AppCurrency.values.length - 1)],
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.readInt()),
    );
    return p;
  }
  @override void write(BinaryWriter w, SiteProcedure o) {
    w.writeString(o.id); w.writeString(o.projectId); w.writeString(o.dailyLogId);
    w.writeInt(o.kind.index);
    w.writeString(o.workerId); w.writeString(o.workerName); w.writeDouble(o.workerWage);
    w.writeString(o.masterId); w.writeString(o.masterName);
    w.writeInt(o.contractType.index);
    w.writeDouble(o.dailyRate); w.writeString(o.description);
    w.writeDouble(o.agreedTotal); w.writeString(o.agreementPerUnit);
    w.writeList(o.consumedMaterials);
    w.writeBool(o.needVehicle);
    w.writeString(o.driverId); w.writeString(o.driverName);
    w.writeDouble(o.driverWage); w.writeString(o.transportNotes);
    w.writeString(o.notes); w.writeDouble(o.totalCost);
    w.writeInt(o.date.millisecondsSinceEpoch);
    w.writeInt(o.currency.index);
    w.writeInt(o.createdAt.millisecondsSinceEpoch);
  }
}
