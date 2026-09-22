import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  /// Backend address.
  /// - Flutter WEB, same machine as backend: localhost is fine.
  /// - ANDROID EMULATOR: use 10.0.2.2 instead of localhost.
  /// - Physical Android device: use your machine's LAN IP, e.g. http://192.168.1.50:8080
  static const String baseUrl = 'http://192.168.75.179:8080';

  /// Session token, held in memory for the lifetime of the app run.
  static String? token;

  Map<String, String> get _authHeaders =>
      token == null ? {} : {'Authorization': 'Bearer $token'};

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
  }

  Future<List<Customer>> getCustomers() async {
    final res = await http.get(Uri.parse('$baseUrl/customers'), headers: _authHeaders);
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 200) throw Exception('Failed to load customers');
    final List data = jsonDecode(res.body);
    return data.map((e) => Customer.fromJson(e)).toList();
  }

  Future<Customer> addCustomer({
    required String name,
    required String email,
    required String phone,
    required String idNumber,
    required String product,
    required String quantity,
    required String direction,
    required String date,
    required String time,
    required String staffName,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/customers'),
      headers: {'Content-Type': 'application/json', ..._authHeaders},
      body: jsonEncode({
        'name': name,
        'email': email,
        'phone': phone,
        'idNumber': idNumber,
        'product': product,
        'quantity': quantity,
        'direction': direction,
        'date': date,
        'time': time,
        'staffName': staffName,
      }),
    );
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body);
      throw Exception(body['error'] ?? 'Failed to add customer');
    }
    return Customer.fromJson(jsonDecode(res.body));
  }

  Future<void> updateCustomer({
    required String id,
    required String name,
    required String email,
    required String phone,
    required String idNumber,
    required String product,
    required String quantity,
    required String direction,
    required String date,
    required String time,
    required String staffName,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/customers/$id'),
      headers: {'Content-Type': 'application/json', ..._authHeaders},
      body: jsonEncode({
        'name': name,
        'email': email,
        'phone': phone,
        'idNumber': idNumber,
        'product': product,
        'quantity': quantity,
        'direction': direction,
        'date': date,
        'time': time,
        'staffName': staffName,
      }),
    );
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['error'] ?? 'Failed to update record');
    }
  }

  /// Direct URL to view/download an uploaded invoice PDF.
  String invoiceFileUrl(String fileName) => '$baseUrl/uploads/$fileName';

  Future<List<Invoice>> getInvoices() async {
    final res = await http.get(Uri.parse('$baseUrl/invoices'), headers: _authHeaders);
    if (res.statusCode == 401) throw Exception('Session expired, please log in again');
    if (res.statusCode != 200) throw Exception('Failed to load invoices');
    final List data = jsonDecode(res.body);
    return data.map((e) => Invoice.fromJson(e)).toList();
  }

  Future<void> addInvoice({
    required String customerId,
    required String amount,
    required String dueDate,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('$baseUrl/invoices');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeaders)
      ..fields['customerId'] = customerId
      ..fields['amount'] = amount
      ..fields['dueDate'] = dueDate
      ..files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );

    final streamedResponse = await request.send();
    if (streamedResponse.statusCode == 401) {
      throw Exception('Session expired, please log in again');
    }
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
