import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

@HiveType(typeId: 1)
class Customer extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) String phone;
  @HiveField(3) String? address;
  @HiveField(4) DateTime createdAt;

  Customer({String? id, required this.name, required this.phone, this.address, DateTime? createdAt})
      : id = id ?? const Uuid().v4(), createdAt = createdAt ?? DateTime.now();

  Map<String,dynamic> toJson()=> {'id':id,'name':name,'phone':phone,'address':address,'createdAt':createdAt.toIso8601String()};
  factory Customer.fromJson(Map<String,dynamic> j)=> Customer(id: j['id'], name: j['name'], phone: j['phone'], address: j['address'], createdAt: DateTime.parse(j['createdAt']));
}

class CustomerAdapter extends TypeAdapter<Customer> {
  @override final typeId=1;
  @override Customer read(BinaryReader r)=> Customer(id: r.readString(), name: r.readString(), phone: r.readString(), address: r.readBool()?r.readString():null, createdAt: DateTime.fromMillisecondsSinceEpoch(r.readInt()));
  @override void write(BinaryWriter w, Customer o){ w.writeString(o.id);w.writeString(o.name);w.writeString(o.phone);w.writeBool(o.address!=null);if(o.address!=null) w.writeString(o.address!);w.writeInt(o.createdAt.millisecondsSinceEpoch);}
}
