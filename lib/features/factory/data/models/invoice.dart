import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/currency.dart';

/// Req #9: dual-type factory invoices.
@HiveType(typeId: 17)
enum InvoiceType { @HiveField(0) standard, @HiveField(1) paymentOnly }

class InvoiceTypeAdapter extends TypeAdapter<InvoiceType> {
  @override final typeId = 17;
  @override InvoiceType read(BinaryReader r) {
    final i = r.readInt();
    if (i < 0 || i >= InvoiceType.values.length) return InvoiceType.standard;
    return InvoiceType.values[i];
  }
  @override void write(BinaryWriter w, InvoiceType o) => w.writeInt(o.index);
}

/// Req #8/#9: one line inside a standard (multi-item) invoice draft.
@HiveType(typeId: 16)
class InvoiceItem extends HiveObject {
  @HiveField(0) String productId;
  @HiveField(1) String productName;
  @HiveField(2) double quantity;
  @HiveField(3) double unitPrice;
  @HiveField(4) String unit;

  InvoiceItem({
    required this.productId, required this.productName,
    required this.quantity, required this.unitPrice, this.unit = 'قطعة',
  });

  double get lineTotal => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
    'productId': productId, 'productName': productName,
    'quantity': quantity, 'unitPrice': unitPrice, 'unit': unit,
  };
  factory InvoiceItem.fromJson(Map<String, dynamic> j) => InvoiceItem(
    productId: j['productId'], productName: j['productName'],
    quantity: (j['quantity'] as num).toDouble(),
    unitPrice: (j['unitPrice'] as num).toDouble(),
    unit: j['unit'] ?? 'قطعة',
  );
}

class InvoiceItemAdapter extends TypeAdapter<InvoiceItem> {
  @override final typeId = 16;
  @override InvoiceItem read(BinaryReader r) => InvoiceItem(
    productId: r.readString(), productName: r.readString(),
    quantity: r.readDouble(), unitPrice: r.readDouble(), unit: r.readString(),
  );
  @override void write(BinaryWriter w, InvoiceItem o) {
    w.writeString(o.productId); w.writeString(o.productName);
    w.writeDouble(o.quantity); w.writeDouble(o.unitPrice); w.writeString(o.unit);
  }
}

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
  /// Req #9
  @HiveField(15) InvoiceType type;
  /// Multi-item lines for standard invoices (empty for legacy single-product rows).
  @HiveField(16) List<InvoiceItem> items;
  /// Notes / settlement reason (esp. payment-only invoices).
  @HiveField(17) String notes;

  Invoice({
    String? id, required this.customerId, required this.customerName, required this.customerPhone,
    required this.deliveryAddress, required this.productId, required this.productName,
    required this.quantity, required this.unitPrice, required this.totalPrice,
    required this.downPayment, DateTime? createdAt, String? invoiceNumber,
    this.currency = AppCurrency.syp,
    this.type = InvoiceType.standard,
    List<InvoiceItem>? items,
    this.notes = '',
  }) : id = id ?? const Uuid().v4(),
        remainingBalance = totalPrice - downPayment,
        createdAt = createdAt ?? DateTime.now(),
        invoiceNumber = invoiceNumber ?? 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        items = items ?? [];

  /// Payment-only factory: creates a direct settlement invoice (no products).
  factory Invoice.paymentOnly({
    String? id,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required double amount,
    AppCurrency currency = AppCurrency.syp,
    String notes = '',
    DateTime? createdAt,
    String? invoiceNumber,
  }) {
    return Invoice(
      id: id,
      customerId: customerId, customerName: customerName, customerPhone: customerPhone,
      deliveryAddress: '', productId: '', productName: 'دفعة مالية',
      quantity: 0, unitPrice: 0, totalPrice: amount, downPayment: amount,
      createdAt: createdAt, invoiceNumber: invoiceNumber,
      currency: currency, type: InvoiceType.paymentOnly, items: [], notes: notes,
    )..remainingBalance = 0;
  }

  bool get isPaymentOnly => type == InvoiceType.paymentOnly;

  /// Effective lines: prefer [items] when present, else legacy single row.
  List<InvoiceItem> get effectiveItems {
    if (items.isNotEmpty) return items;
    if (isPaymentOnly) return [];
    if (productId.isEmpty) return [];
    return [InvoiceItem(productId: productId, productName: productName, quantity: quantity, unitPrice: unitPrice)];
  }

  void recalc() {
    if (isPaymentOnly) {
      remainingBalance = 0;
      return;
    }
    if (items.isNotEmpty) {
      totalPrice = items.fold(0.0, (s, e) => s + e.lineTotal);
    }
    remainingBalance = totalPrice - downPayment;
  }

  Map<String,dynamic> toJson()=> {
    'id':id,'customerId':customerId,'customerName':customerName,'customerPhone':customerPhone,
    'deliveryAddress':deliveryAddress,'productId':productId,'productName':productName,
    'quantity':quantity,'unitPrice':unitPrice,'totalPrice':totalPrice,'downPayment':downPayment,
    'remainingBalance':remainingBalance,'createdAt':createdAt.toIso8601String(),'invoiceNumber':invoiceNumber,
    'currency':currency.code,'type':type.index,
    'items':items.map((e)=> e.toJson()).toList(),'notes':notes,
  };
  factory Invoice.fromJson(Map<String,dynamic> j)=> Invoice(
    id: j['id'], customerId: j['customerId'], customerName: j['customerName'], customerPhone: j['customerPhone'],
    deliveryAddress: j['deliveryAddress'] ?? '', productId: j['productId'] ?? '', productName: j['productName'] ?? '',
    quantity: (j['quantity'] as num).toDouble(), unitPrice: (j['unitPrice'] as num).toDouble(),
    totalPrice: (j['totalPrice'] as num).toDouble(), downPayment: (j['downPayment'] as num).toDouble(),
    createdAt: DateTime.parse(j['createdAt']), invoiceNumber: j['invoiceNumber'],
    currency: AppCurrencyX.fromString(j['currency'] as String?),
    type: InvoiceType.values[((j['type'] as num?)?.toInt() ?? 0).clamp(0, InvoiceType.values.length - 1)],
    items: ((j['items'] as List?) ?? []).map((e)=> InvoiceItem.fromJson(Map<String,dynamic>.from(e as Map))).toList(),
    notes: j['notes'] as String? ?? '',
  )..remainingBalance = (j['remainingBalance'] as num?)?.toDouble() ?? ((j['totalPrice'] as num).toDouble() - (j['downPayment'] as num).toDouble());
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
    InvoiceType type = InvoiceType.standard;
    List<InvoiceItem> items = [];
    String notes = '';
    try {
      final ti = r.readInt();
      type = (ti >= 0 && ti < InvoiceType.values.length) ? InvoiceType.values[ti] : InvoiceType.standard;
    } catch (_) {
      type = InvoiceType.standard;
    }
    try {
      items = (r.readList() as List).cast<InvoiceItem>();
    } catch (_) {
      items = [];
    }
    try {
      notes = r.readString();
    } catch (_) {
      notes = '';
    }
    final inv = Invoice(id:id,customerId:customerId,customerName:customerName,customerPhone:customerPhone,deliveryAddress:deliveryAddress,productId:productId,productName:productName,quantity:quantity,unitPrice:unitPrice,totalPrice:totalPrice,downPayment:downPayment,createdAt:createdAt,invoiceNumber:invoiceNumber,currency:currency,type:type,items:items,notes:notes);
    inv.recalc();
    // Preserve stored remaining for payment-only (0) — recalc already handles it.
    return inv;
  }
  @override void write(BinaryWriter w, Invoice o){
    w.writeString(o.id);w.writeString(o.customerId);w.writeString(o.customerName);w.writeString(o.customerPhone);
    w.writeString(o.deliveryAddress);w.writeString(o.productId);w.writeString(o.productName);
    w.writeDouble(o.quantity);w.writeDouble(o.unitPrice);w.writeDouble(o.totalPrice);w.writeDouble(o.downPayment);
    w.writeInt(o.createdAt.millisecondsSinceEpoch);w.writeString(o.invoiceNumber);
    w.writeInt(o.currency.index);
    w.writeInt(o.type.index);
    w.writeList(o.items);
    w.writeString(o.notes);
  }
}
