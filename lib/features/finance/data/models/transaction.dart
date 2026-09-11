import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/currency.dart';

@HiveType(typeId: 9)
enum TransactionType { @HiveField(0) debit, @HiveField(1) credit, @HiveField(2) payment }
class TransactionTypeAdapter extends TypeAdapter<TransactionType> {
  @override final typeId=9; @override TransactionType read(BinaryReader r)=> TransactionType.values[r.readInt()];
  @override void write(BinaryWriter w, TransactionType o)=> w.writeInt(o.index);
}
@HiveType(typeId: 10)
enum TransactionParty { @HiveField(0) client, @HiveField(1) master, @HiveField(2) worker, @HiveField(3) supplier }
class TransactionPartyAdapter extends TypeAdapter<TransactionParty> {
  @override final typeId=10; @override TransactionParty read(BinaryReader r)=> TransactionParty.values[r.readInt()];
  @override void write(BinaryWriter w, TransactionParty o)=> w.writeInt(o.index);
}

@HiveType(typeId: 7)
class TransactionEntry extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String partyId; // customerId / master phone / worker id / supplier phone
  @HiveField(2) String partyName;
  @HiveField(3) TransactionParty party;
  @HiveField(4) TransactionType type;
  @HiveField(5) double amount;
  @HiveField(6) String source; // e.g. "Invoice #INV-102 Remaining Balance"
  @HiveField(7) String reason;
  @HiveField(8) String? relatedId; // invoiceId / procedureId / projectId
  @HiveField(9) DateTime createdAt;
  @HiveField(10) String? projectId;
  @HiveField(11) AppCurrency currency;
  @HiveField(12) String? partyPhone;

  TransactionEntry({
    String? id, required this.partyId, required this.partyName, required this.party,
    required this.type, required this.amount, required this.source, required this.reason,
    this.relatedId, DateTime? createdAt, this.projectId,
    this.currency = AppCurrency.syp, this.partyPhone,
  }) : id=id??const Uuid().v4(), createdAt=createdAt??DateTime.now();

  Map<String,dynamic> toJson()=> {
    'id':id,'partyId':partyId,'partyName':partyName,'party':party.index,'type':type.index,
    'amount':amount,'source':source,'reason':reason,'relatedId':relatedId,'createdAt':createdAt.toIso8601String(),'projectId':projectId,
    'currency':currency.code,'partyPhone':partyPhone
  };
  factory TransactionEntry.fromJson(Map<String,dynamic> j)=> TransactionEntry(
    id:j['id'],partyId:j['partyId'],partyName:j['partyName'],party:TransactionParty.values[j['party']],
    type:TransactionType.values[j['type']],amount:(j['amount'] as num).toDouble(),source:j['source'],reason:j['reason'],
    relatedId:j['relatedId'],createdAt:DateTime.parse(j['createdAt']),projectId:j['projectId'],
    currency: AppCurrencyX.fromString(j['currency'] as String?), partyPhone: j['partyPhone'] as String?
  );
}

class TransactionEntryAdapter extends TypeAdapter<TransactionEntry> {
  @override final typeId=7;
  @override TransactionEntry read(BinaryReader r){
    final id = r.readString();
    final partyId = r.readString();
    final partyName = r.readString();
    final party = TransactionParty.values[r.readInt()];
    final type = TransactionType.values[r.readInt()];
    final amount = r.readDouble();
    final source = r.readString();
    final reason = r.readString();
    final relatedId = r.readBool()?r.readString():null;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(r.readInt());
    final projectId = r.readBool()?r.readString():null;
    // Backward-compatible: old boxes have no currency/phone trailing fields.
    AppCurrency currency = AppCurrency.syp;
    String? partyPhone;
    try {
      currency = AppCurrency.values[r.readInt()];
    } catch (_) {
      currency = AppCurrency.syp;
    }
    try {
      final hasPhone = r.readBool();
      if (hasPhone) partyPhone = r.readString();
    } catch (_) {
      partyPhone = null;
    }
    return TransactionEntry(
      id:id,partyId:partyId,partyName:partyName,party:party,
      type:type,amount:amount,source:source,reason:reason,
      relatedId:relatedId,createdAt:createdAt,projectId:projectId,
      currency: currency, partyPhone: partyPhone,
    );
  }
  @override void write(BinaryWriter w, TransactionEntry o){
    w.writeString(o.id);w.writeString(o.partyId);w.writeString(o.partyName);w.writeInt(o.party.index);
    w.writeInt(o.type.index);w.writeDouble(o.amount);w.writeString(o.source);w.writeString(o.reason);
    w.writeBool(o.relatedId!=null);if(o.relatedId!=null) w.writeString(o.relatedId!);
    w.writeInt(o.createdAt.millisecondsSinceEpoch);w.writeBool(o.projectId!=null);if(o.projectId!=null) w.writeString(o.projectId!);
    w.writeInt(o.currency.index);
    w.writeBool(o.partyPhone!=null);if(o.partyPhone!=null) w.writeString(o.partyPhone!);
  }
}
