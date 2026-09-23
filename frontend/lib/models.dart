class Client {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String idNumber;
  final String createdAt;

  Client({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.idNumber,
    required this.createdAt,
  });

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'] ?? '',
        idNumber: json['idNumber'] ?? '',
        createdAt: json['createdAt'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'idNumber': idNumber,
        'createdAt': createdAt,
      };
}

class Product {
  final String id;
  final String name;
  final String unit;
  final double defaultPricePerBag;
  final String description;
  final String createdAt;

  Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.defaultPricePerBag,
    required this.description,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        unit: json['unit'] ?? 'Bag 90kg',
        defaultPricePerBag: (json['defaultPricePerBag'] is num)
            ? (json['defaultPricePerBag'] as num).toDouble()
            : (double.tryParse(json['defaultPricePerBag']?.toString() ?? '') ?? 15.0),
        description: json['description'] ?? '',
        createdAt: json['createdAt'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'defaultPricePerBag': defaultPricePerBag,
        'description': description,
        'createdAt': createdAt,
      };
}

class StoreRecord {
  final String id;
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String clientPhone;
  final String clientIdNumber;
  final String productId;
  final String productName;
  final double quantity;
  final String direction; // 'in' or 'out'
  final String date;
  final String time;
  final String staffName;
  final String notes;
  final String createdAt;

  StoreRecord({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.clientPhone,
    required this.clientIdNumber,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.direction,
    required this.date,
    required this.time,
    required this.staffName,
    required this.notes,
    required this.createdAt,
  });

  factory StoreRecord.fromJson(Map<String, dynamic> json) => StoreRecord(
        id: json['id'] ?? '',
        clientId: json['clientId'] ?? '',
        clientName: json['clientName'] ?? '',
        clientEmail: json['clientEmail'] ?? '',
        clientPhone: json['clientPhone'] ?? '',
        clientIdNumber: json['clientIdNumber'] ?? '',
        productId: json['productId'] ?? '',
        productName: json['productName'] ?? '',
        quantity: (json['quantity'] is num)
            ? (json['quantity'] as num).toDouble()
            : (double.tryParse(json['quantity']?.toString() ?? '') ?? 0.0),
        direction: json['direction'] ?? 'in',
        date: json['date'] ?? '',
        time: json['time'] ?? '',
        staffName: json['staffName'] ?? '',
        notes: json['notes'] ?? '',
        createdAt: json['createdAt'] ?? '',
      );
}

class FumigationInvoice {
  final String id;
  final String clientId;
  final String clientName;
  final String quarter;
  final double bagsCount;
  final double pricePerBag;
  final double totalAmount;
  final String dueDate;
  final String status; // 'pending' or 'paid'
  final String createdAt;

  FumigationInvoice({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.quarter,
    required this.bagsCount,
    required this.pricePerBag,
    required this.totalAmount,
    required this.dueDate,
    required this.status,
    required this.createdAt,
  });

  factory FumigationInvoice.fromJson(Map<String, dynamic> json) => FumigationInvoice(
        id: json['id'] ?? '',
        clientId: json['clientId'] ?? '',
        clientName: json['clientName'] ?? '',
        quarter: json['quarter'] ?? '',
        bagsCount: (json['bagsCount'] is num)
            ? (json['bagsCount'] as num).toDouble()
            : (double.tryParse(json['bagsCount']?.toString() ?? '') ?? 0.0),
        pricePerBag: (json['pricePerBag'] is num)
            ? (json['pricePerBag'] as num).toDouble()
            : (double.tryParse(json['pricePerBag']?.toString() ?? '') ?? 0.0),
        totalAmount: (json['totalAmount'] is num)
            ? (json['totalAmount'] as num).toDouble()
            : (double.tryParse(json['totalAmount']?.toString() ?? '') ?? 0.0),
        dueDate: json['dueDate'] ?? '',
        status: json['status'] ?? 'pending',
        createdAt: json['createdAt'] ?? '',
      );
}

class Invoice {
  final String id;
  final String clientId;
  final String clientName;
  final String amount;
  final String dueDate;
  final String fileName;
  final String status;

  Invoice({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.amount,
    required this.dueDate,
    required this.fileName,
    required this.status,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: json['id'] ?? '',
        clientId: json['clientId'] ?? '',
        clientName: json['clientName'] ?? 'Unknown',
        amount: json['amount']?.toString() ?? '0',
        dueDate: json['dueDate'] ?? '',
        fileName: json['fileName'] ?? '',
        status: json['status'] ?? 'pending',
      );
}
