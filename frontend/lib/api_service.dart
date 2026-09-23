import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  /// Backend URL.
  static const String baseUrl = 'http://192.168.75.179:8080';

  /// Session token held in memory during runtime.
  static String? token;
  static String? loggedInUsername;

  Map<String, String> get _authHeaders =>
      token == null ? {} : {'Authorization': 'Bearer $token'};

  // --- Auth ---

  Future<String> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['error'] ?? 'Login failed');
    }
    final data = jsonDecode(res.body);
    token = data['token'];
    loggedInUsername = data['username'];
    return data['username'];
  }

  Future<String> signup(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body);
      throw Exception(body['error'] ?? 'Sign up failed');
    }
    final data = jsonDecode(res.body);
    token = data['token'];
    loggedInUsername = data['username'];
    return data['username'];
  }

  Future<void> logout() async {
    if (token != null) {
      await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: _authHeaders,
      );
    }
    token = null;
    loggedInUsername = null;
  }

  // --- Clients ---

  Future<List<Client>> getClients() async {
    final res = await http.get(Uri.parse('$baseUrl/clients'), headers: _authHeaders);
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 200) throw Exception('Failed to load clients');
    final List data = jsonDecode(res.body);
    return data.map((e) => Client.fromJson(e)).toList();
  }

  Future<Client> addClient({
    String? id,
    required String name,
    required String email,
    required String phone,
    required String idNumber,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/clients'),
      headers: {'Content-Type': 'application/json', ..._authHeaders},
      body: jsonEncode({
        if (id != null && id.isNotEmpty) 'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'idNumber': idNumber,
      }),
    );
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body);
      throw Exception(body['error'] ?? 'Failed to add client');
    }
    return Client.fromJson(jsonDecode(res.body));
  }

  Future<void> updateClient({
    required String id,
    required String name,
    required String email,
    required String phone,
    required String idNumber,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/clients/$id'),
      headers: {'Content-Type': 'application/json', ..._authHeaders},
      body: jsonEncode({
        'name': name,
        'email': email,
        'phone': phone,
        'idNumber': idNumber,
      }),
    );
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['error'] ?? 'Failed to update client');
    }
  }

  Future<void> deleteClient(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/clients/$id'), headers: _authHeaders);
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 200) throw Exception('Failed to delete client');
  }

  // --- Products ---

  Future<List<Product>> getProducts() async {
    final res = await http.get(Uri.parse('$baseUrl/products'), headers: _authHeaders);
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 200) throw Exception('Failed to load products');
    final List data = jsonDecode(res.body);
    return data.map((e) => Product.fromJson(e)).toList();
  }

  Future<Product> addProduct({
    String? id,
    required String name,
    required String unit,
    required double defaultPricePerBag,
    required String description,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/products'),
      headers: {'Content-Type': 'application/json', ..._authHeaders},
      body: jsonEncode({
        if (id != null && id.isNotEmpty) 'id': id,
        'name': name,
        'unit': unit,
        'defaultPricePerBag': defaultPricePerBag,
        'description': description,
      }),
    );
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body);
      throw Exception(body['error'] ?? 'Failed to add product');
    }
    return Product.fromJson(jsonDecode(res.body));
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    required String unit,
    required double defaultPricePerBag,
    required String description,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/products/$id'),
      headers: {'Content-Type': 'application/json', ..._authHeaders},
      body: jsonEncode({
        'name': name,
        'unit': unit,
        'defaultPricePerBag': defaultPricePerBag,
        'description': description,
      }),
    );
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['error'] ?? 'Failed to update product');
    }
  }

  Future<void> deleteProduct(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/products/$id'), headers: _authHeaders);
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 200) throw Exception('Failed to delete product');
  }

  // --- Store Records ---

  Future<List<StoreRecord>> getRecords({
    String? startDate,
    String? endDate,
    String? clientId,
    String? productId,
    String? direction,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null && startDate.isNotEmpty) queryParams['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) queryParams['endDate'] = endDate;
    if (clientId != null && clientId.isNotEmpty) queryParams['clientId'] = clientId;
    if (productId != null && productId.isNotEmpty) queryParams['productId'] = productId;
    if (direction != null && direction.isNotEmpty) queryParams['direction'] = direction;

    final uri = Uri.parse('$baseUrl/records').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final res = await http.get(uri, headers: _authHeaders);
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 200) throw Exception('Failed to load records');
    final List data = jsonDecode(res.body);
    return data.map((e) => StoreRecord.fromJson(e)).toList();
  }

  Future<StoreRecord> addRecord({
    required String clientId,
    required String clientName,
    required String clientEmail,
    required String clientPhone,
    required String clientIdNumber,
    required String productId,
    required String productName,
    required double quantity,
    required String direction,
    required String date,
    required String time,
    required String staffName,
    required String notes,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/records'),
      headers: {'Content-Type': 'application/json', ..._authHeaders},
      body: jsonEncode({
        'clientId': clientId,
        'clientName': clientName,
        'clientEmail': clientEmail,
        'clientPhone': clientPhone,
        'clientIdNumber': clientIdNumber,
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'direction': direction,
        'date': date,
        'time': time,
        'staffName': staffName,
        'notes': notes,
      }),
    );
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body);
      throw Exception(body['error'] ?? 'Failed to add record');
    }
    return StoreRecord.fromJson(jsonDecode(res.body));
  }

  Future<void> updateRecord({
    required String id,
    required String clientId,
    required String clientName,
    required String clientEmail,
    required String clientPhone,
    required String clientIdNumber,
    required String productId,
    required String productName,
    required double quantity,
    required String direction,
    required String date,
    required String time,
    required String staffName,
    required String notes,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/records/$id'),
      headers: {'Content-Type': 'application/json', ..._authHeaders},
      body: jsonEncode({
        'clientId': clientId,
        'clientName': clientName,
        'clientEmail': clientEmail,
        'clientPhone': clientPhone,
        'clientIdNumber': clientIdNumber,
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'direction': direction,
        'date': date,
        'time': time,
        'staffName': staffName,
        'notes': notes,
      }),
    );
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['error'] ?? 'Failed to update record');
    }
  }

  Future<void> deleteRecord(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/records/$id'), headers: _authHeaders);
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 200) throw Exception('Failed to delete record');
  }

  // --- Fumigation Invoices ---

  Future<List<FumigationInvoice>> getFumigationInvoices() async {
    final res = await http.get(Uri.parse('$baseUrl/fumigation-invoices'), headers: _authHeaders);
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 200) throw Exception('Failed to load fumigation invoices');
    final List data = jsonDecode(res.body);
    return data.map((e) => FumigationInvoice.fromJson(e)).toList();
  }

  Future<FumigationInvoice> addFumigationInvoice({
    required String clientId,
    required String clientName,
    required String quarter,
    required double bagsCount,
    required double pricePerBag,
    required String dueDate,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/fumigation-invoices'),
      headers: {'Content-Type': 'application/json', ..._authHeaders},
      body: jsonEncode({
        'clientId': clientId,
        'clientName': clientName,
        'quarter': quarter,
        'bagsCount': bagsCount,
        'pricePerBag': pricePerBag,
        'dueDate': dueDate,
      }),
    );
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body);
      throw Exception(body['error'] ?? 'Failed to generate fumigation invoice');
    }
    return FumigationInvoice.fromJson(jsonDecode(res.body));
  }

  Future<void> updateFumigationInvoiceStatus(String id, String status) async {
    final res = await http.put(
      Uri.parse('$baseUrl/fumigation-invoices/$id/status'),
      headers: {'Content-Type': 'application/json', ..._authHeaders},
      body: jsonEncode({'status': status}),
    );
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 200) throw Exception('Failed to update invoice status');
  }

  Future<void> deleteFumigationInvoice(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/fumigation-invoices/$id'), headers: _authHeaders);
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 200) throw Exception('Failed to delete fumigation invoice');
  }

  // --- Standard Invoices ---

  String invoiceFileUrl(String fileName) => '$baseUrl/uploads/$fileName';

  Future<List<Invoice>> getInvoices() async {
    final res = await http.get(Uri.parse('$baseUrl/invoices'), headers: _authHeaders);
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 200) throw Exception('Failed to load invoices');
    final List data = jsonDecode(res.body);
    return data.map((e) => Invoice.fromJson(e)).toList();
  }

  Future<void> addInvoice({
    required String clientId,
    required String amount,
    required String dueDate,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('$baseUrl/invoices');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeaders)
      ..fields['clientId'] = clientId
      ..fields['amount'] = amount
      ..fields['dueDate'] = dueDate
      ..files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );

    final streamedResponse = await request.send();
    if (streamedResponse.statusCode == 401) throw Exception('Session expired, please log in again');
    if (streamedResponse.statusCode != 201) {
      final body = await streamedResponse.stream.bytesToString();
      String message = 'Failed to upload invoice';
      try {
        message = jsonDecode(body)['error'] ?? message;
      } catch (_) {}
      throw Exception(message);
    }
  }
}
