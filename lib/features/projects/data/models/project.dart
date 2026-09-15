import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/currency.dart';

@HiveType(typeId: 3)
class Project extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String clientName;
  @HiveField(2) String clientPhone;
  @HiveField(3) String location;
  @HiveField(4) double totalArea;
  @HiveField(5) double buildingArea;
  @HiveField(6) int roomCount;
  @HiveField(7) String description;
  @HiveField(8) List<String> photoPaths;
  @HiveField(9) DateTime createdAt;
  @HiveField(10) double totalCost; // sum of all procedures
  @HiveField(11) double completedCost; // sum of completed only
  @HiveField(12) String clientId; // link to Customer-like ledger
  @HiveField(13) AppCurrency currency;

  Project({
    String? id, required this.clientName, required this.clientPhone, required this.location,
    required this.totalArea, required this.buildingArea, required this.roomCount,
    required this.description, List<String>? photoPaths, DateTime? createdAt,
    this.totalCost=0, this.completedCost=0, String? clientId,
    this.currency = AppCurrency.syp,
  }) : id=id??const Uuid().v4(), photoPaths=photoPaths??[], createdAt=createdAt??DateTime.now(), clientId=clientId?? const Uuid().v4();

  Map<String,dynamic> toJson()=> {
    'id':id,'clientName':clientName,'clientPhone':clientPhone,'location':location,
    'totalArea':totalArea,'buildingArea':buildingArea,'roomCount':roomCount,
    'description':description,'photoPaths':photoPaths,'createdAt':createdAt.toIso8601String(),
    'totalCost':totalCost,'completedCost':completedCost,'clientId':clientId,
    'currency':currency.code
  };
  factory Project.fromJson(Map<String,dynamic> j)=> Project(
    id:j['id'],clientName:j['clientName'],clientPhone:j['clientPhone'],location:j['location'],
    totalArea:(j['totalArea'] as num).toDouble(),buildingArea:(j['buildingArea'] as num).toDouble(),
    roomCount:j['roomCount'],description:j['description'],photoPaths:List<String>.from(j['photoPaths']??[]),
    createdAt:DateTime.parse(j['createdAt']),totalCost:(j['totalCost'] as num).toDouble(),
    completedCost:(j['completedCost'] as num).toDouble(),clientId:j['clientId'],
    currency: AppCurrencyX.fromString(j['currency'] as String?),
  );
}

class ProjectAdapter extends TypeAdapter<Project> {
  @override final typeId=3;
  @override Project read(BinaryReader r){
    final p = Project(
      id:r.readString(),clientName:r.readString(),clientPhone:r.readString(),location:r.readString(),
      totalArea:r.readDouble(),buildingArea:r.readDouble(),roomCount:r.readInt(),description:r.readString(),
      photoPaths:(r.readList() as List).cast<String>(),createdAt:DateTime.fromMillisecondsSinceEpoch(r.readInt()),
      totalCost:r.readDouble(),completedCost:r.readDouble(),clientId:r.readString()
    );
    try {
      p.currency = AppCurrency.values[r.readInt()];
    } catch (_) {
      p.currency = AppCurrency.syp;
    }
    return p;
  }
  @override void write(BinaryWriter w, Project o){
    w.writeString(o.id);w.writeString(o.clientName);w.writeString(o.clientPhone);w.writeString(o.location);
    w.writeDouble(o.totalArea);w.writeDouble(o.buildingArea);w.writeInt(o.roomCount);w.writeString(o.description);
    w.writeList(o.photoPaths);w.writeInt(o.createdAt.millisecondsSinceEpoch);w.writeDouble(o.totalCost);w.writeDouble(o.completedCost);w.writeString(o.clientId);
    w.writeInt(o.currency.index);
  }
}
