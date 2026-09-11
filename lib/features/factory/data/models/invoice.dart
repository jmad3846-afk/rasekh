import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/currency.dart';

@HiveType(typeId: 2)
class Invoice extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String customerId;
  @HiveField(2) String customerName;
  @HiveField(3) String customerPhone;
  @HiveField(4) String deliveryAddress;
  @HiveField(5) String productId;
  @HiveField(6) String productName;
  @HiveField(7) double quantity;
  @HiveField(8) double unitPrice;
  @HiveField(9) double totalPrice;
  @HiveField(10) double downPayment;
  @HiveField(11) double remainingBalance;
  @HiveField(12) DateTime createdAt;
  @HiveField(13) String invoiceNumber; // INV-102
  @HiveField(14) AppCurrency currency;

  Invoice({
    String? id, required this.customerId, required this.customerName, required this.customerPhone,
    required this.deliveryAddress, required this.productId, required this.productName,
    required this.quantity, required this.unitPrice, required this.totalPrice,
    required this.downPayment, DateTime? createdAt, String? invoiceNumber,
    this.currency = AppCurrency.syp,
  }) : id = id ?? const Uuid().v4(),
       remainingBalance = totalPrice - downPayment,
       createdAt = createdAt ?? DateTime.now(),
       invoiceNumber = invoiceNumber ?? 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

  void recalc() {
    remainingBalance = totalPrice - downPayment;
  }

  Map<String,dynamic> toJson()=> {
    'id':id,'customerId':customerId,'customerName':customerName,'customerPhone':customerPhone,
    'deliveryAddress':deliveryAddress,'productId':productId,'productName':productName,
    'quantity':quantity,'unitPrice':unitPrice,'totalPrice':totalPrice,'downPayment':downPayment,
    'remainingBalance':remainingBalance,'createdAt':createdAt.toIso8601String(),'invoiceNumber':invoiceNumber,
    'currency':currency.code
  };
  factory Invoice.fromJson(Map<String,dynamic> j)=> Invoice(
    id: j['id'], customerId: j['customerId'], customerName: j['customerName'], customerPhone: j['customerPhone'],
    deliveryAddress: j['deliveryAddress'], productId: j['productId'], productName: j['productName'],
    quantity: (j['quantity'] as num).toDouble(), unitPrice: (j['unitPrice'] as num).toDouble(),
    totalPrice: (j['totalPrice'] as num).toDouble(), downPayment: (j['downPayment'] as num).toDouble(),
    createdAt: DateTime.parse(j['createdAt']), invoiceNumber: j['invoiceNumber'],
    currency: AppCurrencyX.fromString(j['currency'] as String?),
  );
}

class InvoiceAdapter extends TypeAdapter<Invoice> {
  @override final typeId=2;
  @override Invoice read(BinaryReader r){
    final id=r.readString(); final customerId=r.readString(); final customerName=r.readString();
    final customerPhone=r.readString(); final deliveryAddress=r.readString();
    final productId=r.readString(); final productName=r.readString();
    final quantity=r.readDouble(); final unitPrice=r.readDouble(); final totalPrice=r.readDouble();
    final downPayment=r.readDouble(); final createdAt=DateTime.fromMillisecondsSinceEpoch(r.readInt());
    final invoiceNumber=r.readString();
    AppCurrency currency = AppCurrency.syp;
    try {
      currency = AppCurrency.values[r.readInt()];
    } catch (_) {
      currency = AppCurrency.syp;
    }
    return Invoice(id:id,customerId:customerId,customerName:customerName,customerPhone:customerPhone,deliveryAddress:deliveryAddress,productId:productId,productName:productName,quantity:quantity,unitPrice:unitPrice,totalPrice:totalPrice,downPayment:downPayment,createdAt:createdAt,invoiceNumber:invoiceNumber,currency:currency);
  }
  @override void write(BinaryWriter w, Invoice o){
    w.writeString(o.id);w.writeString(o.customerId);w.writeString(o.customerName);w.writeString(o.customerPhone);
    w.writeString(o.deliveryAddress);w.writeString(o.productId);w.writeString(o.productName);
    w.writeDouble(o.quantity);w.writeDouble(o.unitPrice);w.writeDouble(o.totalPrice);w.writeDouble(o.downPayment);
    w.writeInt(o.createdAt.millisecondsSinceEpoch);w.writeString(o.invoiceNumber);
    w.writeInt(o.currency.index);
  }
}
