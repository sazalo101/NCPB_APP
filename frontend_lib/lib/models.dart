class Customer {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String idNumber;
  final String product;
  final String quantity;
  final String direction; // 'in' or 'out'
  final String date;
  final String time;
  final String staffName;
  final String createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.idNumber,
    required this.product,
    required this.quantity,
    required this.direction,
    required this.date,
    required this.time,
    required this.staffName,
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'] ?? '',
        idNumber: json['idNumber'] ?? '',
        product: json['product'] ?? '',
        quantity: json['quantity']?.toString() ?? '',
        direction: json['direction'] ?? '',
        date: json['date'] ?? '',
        time: json['time'] ?? '',
        staffName: json['staffName'] ?? '',
        createdAt: json['createdAt'] ?? '',
      );
}

class Invoice {
  final String id;
  final String customerId;
  final String customerName;
  final String amount;
  final String dueDate;
  final String fileName;
  final String status;

  Invoice({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.amount,
    required this.dueDate,
    required this.fileName,
    required this.status,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: json['id'] ?? '',
        customerId: json['customerId'] ?? '',
        customerName: json['customerName'] ?? 'Unknown',
        amount: json['amount']?.toString() ?? '0',
        dueDate: json['dueDate'] ?? '',
        fileName: json['fileName'] ?? '',
        status: json['status'] ?? 'pending',
      );
}
