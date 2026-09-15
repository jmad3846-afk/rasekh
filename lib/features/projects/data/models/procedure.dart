import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/currency.dart';

@HiveType(typeId: 8)
enum ProcedureStatus { @HiveField(0) pending, @HiveField(1) completed }

class ProcedureStatusAdapter extends TypeAdapter<ProcedureStatus> {
  @override final typeId=8;
  @override ProcedureStatus read(BinaryReader r)=> ProcedureStatus.values[r.readInt()];
  @override void write(BinaryWriter w, ProcedureStatus o)=> w.writeInt(o.index);
}

@HiveType(typeId: 5)
class WorkshopWorker extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) String phone;
  @HiveField(3) double cost;
  WorkshopWorker({String? id, required this.name, required this.phone, required this.cost}): id=id??const Uuid().v4();
  Map<String,dynamic> toJson()=> {'id':id,'name':name,'phone':phone,'cost':cost};
  factory WorkshopWorker.fromJson(Map<String,dynamic> j)=> WorkshopWorker(id:j['id'],name:j['name'],phone:j['phone'],cost:(j['cost'] as num).toDouble());
}
class WorkshopWorkerAdapter extends TypeAdapter<WorkshopWorker> {
  @override final typeId=5;
  @override WorkshopWorker read(BinaryReader r)=> WorkshopWorker(id:r.readString(),name:r.readString(),phone:r.readString(),cost:r.readDouble());
  @override void write(BinaryWriter w, WorkshopWorker o){w.writeString(o.id);w.writeString(o.name);w.writeString(o.phone);w.writeDouble(o.cost);}
}

@HiveType(typeId: 6)
class SupplierInfo extends HiveObject {
  @HiveField(0) String name;
  @HiveField(1) String phone;
  @HiveField(2) String materials;
  @HiveField(3) double totalCost;
  SupplierInfo({required this.name, required this.phone, required this.materials, required this.totalCost});
  Map<String,dynamic> toJson()=> {'name':name,'phone':phone,'materials':materials,'totalCost':totalCost};
  factory SupplierInfo.fromJson(Map<String,dynamic> j)=> SupplierInfo(name:j['name'],phone:j['phone'],materials:j['materials'],totalCost:(j['totalCost'] as num).toDouble());
}
class SupplierInfoAdapter extends TypeAdapter<SupplierInfo> {
  @override final typeId=6;
  @override SupplierInfo read(BinaryReader r)=> SupplierInfo(name:r.readString(),phone:r.readString(),materials:r.readString(),totalCost:r.readDouble());
  @override void write(BinaryWriter w, SupplierInfo o){w.writeString(o.name);w.writeString(o.phone);w.writeString(o.materials);w.writeDouble(o.totalCost);}
}

@HiveType(typeId: 4)
class Procedure extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String projectId;
  @HiveField(2) String title;
  @HiveField(3) String description;
  @HiveField(4) ProcedureStatus status;
  @HiveField(5) DateTime date;
  @HiveField(6) String masterName;
  @HiveField(7) String masterPhone;
  @HiveField(8) double masterWage;
  @HiveField(9) List<WorkshopWorker> workers;
  @HiveField(10) SupplierInfo supplier;
  @HiveField(11) double totalCost; // computed
  @HiveField(12) AppCurrency currency;

  Procedure({
    String? id, required this.projectId, required this.title, required this.description,
    this.status=ProcedureStatus.pending, DateTime? date,
    required this.masterName, required this.masterPhone, required this.masterWage,
    List<WorkshopWorker>? workers, required this.supplier,
    this.currency = AppCurrency.syp,
  }) : id=id??const Uuid().v4(), date=date??DateTime.now(), workers=workers??[],
       totalCost = masterWage + (workers??[]).fold(0.0,(s,w)=>s+w.cost) + supplier.totalCost;

  void recalc(){ totalCost = masterWage + workers.fold(0.0,(s,w)=>s+w.cost) + supplier.totalCost; }

  Map<String,dynamic> toJson()=> {
    'id':id,'projectId':projectId,'title':title,'description':description,'status':status.index,'date':date.toIso8601String(),
    'masterName':masterName,'masterPhone':masterPhone,'masterWage':masterWage,
    'workers':workers.map((w)=>w.toJson()).toList(),'supplier':supplier.toJson(),'totalCost':totalCost,
    'currency':currency.code
  };
  factory Procedure.fromJson(Map<String,dynamic> j)=> Procedure(
    id:j['id'],projectId:j['projectId'],title:j['title'],description:j['description'],
    status:ProcedureStatus.values[j['status']],date:DateTime.parse(j['date']),
    masterName:j['masterName'],masterPhone:j['masterPhone'],masterWage:(j['masterWage'] as num).toDouble(),
    workers:(j['workers'] as List).map((e)=>WorkshopWorker.fromJson(Map<String,dynamic>.from(e as Map))).toList(),
    supplier:SupplierInfo.fromJson(Map<String,dynamic>.from(j['supplier'] as Map)),
    currency: AppCurrencyX.fromString(j['currency'] as String?),
  );
}

class ProcedureAdapter extends TypeAdapter<Procedure> {
  @override final typeId=4;
  @override Procedure read(BinaryReader r){
    final id=r.readString(); final projectId=r.readString(); final title=r.readString(); final desc=r.readString();
    final status=ProcedureStatus.values[r.readInt()]; final date=DateTime.fromMillisecondsSinceEpoch(r.readInt());
    final masterName=r.readString(); final masterPhone=r.readString(); final masterWage=r.readDouble();
    final workers=(r.readList() as List).cast<WorkshopWorker>(); final supplier=r.read() as SupplierInfo;
    final p=Procedure(id:id,projectId:projectId,title:title,description:desc,status:status,date:date,masterName:masterName,masterPhone:masterPhone,masterWage:masterWage,workers:workers,supplier:supplier);
    p.totalCost=r.readDouble();
    try {
      p.currency = AppCurrency.values[r.readInt()];
    } catch (_) {
      p.currency = AppCurrency.syp;
    }
    return p;
  }
  @override void write(BinaryWriter w, Procedure o){
    w.writeString(o.id);w.writeString(o.projectId);w.writeString(o.title);w.writeString(o.description);
    w.writeInt(o.status.index);w.writeInt(o.date.millisecondsSinceEpoch);
    w.writeString(o.masterName);w.writeString(o.masterPhone);w.writeDouble(o.masterWage);
    w.writeList(o.workers);w.write(o.supplier);w.writeDouble(o.totalCost);
    w.writeInt(o.currency.index);
  }
}
