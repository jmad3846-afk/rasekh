import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// Req #10: Personnel module — 4 categories in one box.
@HiveType(typeId: 13)
enum PersonnelRole {
  @HiveField(0) worker,   // العمال
  @HiveField(1) master,   // المعلمين
  @HiveField(2) supplier, // الموردين
  @HiveField(3) driver,   // السائقين
}

class PersonnelRoleAdapter extends TypeAdapter<PersonnelRole> {
  @override final typeId = 13;
  @override PersonnelRole read(BinaryReader r) {
    final i = r.readInt();
    if (i < 0 || i >= PersonnelRole.values.length) return PersonnelRole.worker;
    return PersonnelRole.values[i];
  }
  @override void write(BinaryWriter w, PersonnelRole o) => w.writeInt(o.index);
}

extension PersonnelRoleX on PersonnelRole {
  String get arabicLabel {
    switch (this) {
      case PersonnelRole.worker: return 'عامل';
      case PersonnelRole.master: return 'معلم';
      case PersonnelRole.supplier: return 'مورد';
      case PersonnelRole.driver: return 'سائق';
    }
  }
  String get tabLabel {
    switch (this) {
      case PersonnelRole.worker: return 'العمال';
      case PersonnelRole.master: return 'المعلمين';
      case PersonnelRole.supplier: return 'الموردين';
      case PersonnelRole.driver: return 'السائقين';
    }
  }
}

@HiveType(typeId: 12)
class PersonnelEntry extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) PersonnelRole role;
  @HiveField(2) String name;
  @HiveField(3) String phone;
  /// Workers/Suppliers/Masters: location. Masters also use [profession].
  @HiveField(4) String location;
  /// Masters only: profession/trade. Drivers only: vehicle type (reuses field).
  @HiveField(5) String extra;
  @HiveField(6) DateTime createdAt;
  /// Suppliers only: supplied materials / المواد التي يقدمها (free text/tags).
  @HiveField(7) String suppliedMaterials;

  PersonnelEntry({
    String? id, required this.role, required this.name, required this.phone,
    this.location = '', this.extra = '', DateTime? createdAt,
    this.suppliedMaterials = '',
  }) : id = id ?? const Uuid().v4(), createdAt = createdAt ?? DateTime.now();

  /// Masters: profession. Drivers: vehicle type. Others: ''.
  String get professionOrVehicle => extra;

  set professionOrVehicle(String v) => extra = v;

  bool matches(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return true;
    return name.toLowerCase().contains(s) ||
        phone.toLowerCase().contains(s) ||
        location.toLowerCase().contains(s) ||
        extra.toLowerCase().contains(s) ||
        suppliedMaterials.toLowerCase().contains(s);
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'role': role.index, 'name': name, 'phone': phone,
    'location': location, 'extra': extra,
    'createdAt': createdAt.toIso8601String(),
    'suppliedMaterials': suppliedMaterials,
  };
  factory PersonnelEntry.fromJson(Map<String, dynamic> j) => PersonnelEntry(
    id: j['id'], role: PersonnelRole.values[((j['role'] as num).toInt()).clamp(0, PersonnelRole.values.length - 1)],
    name: j['name'], phone: j['phone'],
    location: j['location'] ?? '', extra: j['extra'] ?? '',
    createdAt: DateTime.parse(j['createdAt']),
    suppliedMaterials: (j['suppliedMaterials'] as String?) ?? '',
  );
}

class PersonnelEntryAdapter extends TypeAdapter<PersonnelEntry> {
  @override final typeId = 12;
  @override PersonnelEntry read(BinaryReader r) {
    final e = PersonnelEntry(
      id: r.readString(),
      role: PersonnelRole.values[r.readInt().clamp(0, PersonnelRole.values.length - 1)],
      name: r.readString(), phone: r.readString(),
      location: r.readString(), extra: r.readString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.readInt()),
    );
    // Backward-compatible: boxes written before suppliedMaterials lack field 7.
    try {
      e.suppliedMaterials = r.readString();
    } catch (_) {
      e.suppliedMaterials = '';
    }
    return e;
  }
  @override void write(BinaryWriter w, PersonnelEntry o) {
    w.writeString(o.id); w.writeInt(o.role.index);
    w.writeString(o.name); w.writeString(o.phone);
    w.writeString(o.location); w.writeString(o.extra);
    w.writeInt(o.createdAt.millisecondsSinceEpoch);
    w.writeString(o.suppliedMaterials);
  }
}
