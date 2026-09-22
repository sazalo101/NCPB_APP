import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_multipart/multipart.dart';
import 'package:shelf_multipart/form_data.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';

import '../lib/db.dart';

final _uuid = Uuid();
final _appDb = AppDatabase();

/// In-memory session tokens: token -> username.
/// Simple and fine for an MVP; tokens reset if the server restarts,
/// meaning staff will need to log in again after a restart.
final Map<String, String> _tokens = {};

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
};

Response _json(Object data, {int status = 200}) {
  return Response(status,
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json', ..._corsHeaders});
}

Middleware _cors() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      final response = await innerHandler(request);
      return response.change(headers: _corsHeaders);
    };
  };
}

/// Returns the logged-in username if the request has a valid token,
/// or null if not authenticated.
String? _authenticate(Request req) {
  final header = req.headers['authorization'];
  if (header == null || !header.startsWith('Bearer ')) return null;
  final token = header.substring(7);
  return _tokens[token];
}

void main(List<String> args) async {
  _appDb.init();

  final router = Router();

  // --- Health check ---
  router.get('/', (Request req) {
    return _json({'status': 'ok', 'service': 'NCPB Invoice Manager API'});
  });

  // --- Auth ---

  router.post('/auth/login', (Request req) async {
    final payload = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final username = (payload['username'] ?? '').toString().trim();
    final password = (payload['password'] ?? '').toString();

    if (username.isEmpty || password.isEmpty) {
      return _json({'error': 'username and password are required'}, status: 400);
    }

    final staff = _appDb.findStaffByUsername(username);
    if (staff == null || staff['passwordHash'] != hashPassword(password)) {
      return _json({'error': 'Invalid username or password'}, status: 401);
    }

    final token = _uuid.v4();
    _tokens[token] = username;
    return _json({'token': token, 'username': username});
  });

  router.post('/auth/logout', (Request req) async {
    final header = req.headers['authorization'];
    if (header != null && header.startsWith('Bearer ')) {
      _tokens.remove(header.substring(7));
    }
    return _json({'ok': true});
  });

  // --- Customers ---

  router.get('/customers', (Request req) async {
    if (_authenticate(req) == null) {
      return _json({'error': 'Unauthorized'}, status: 401);
    }
    return _json(_appDb.getCustomers());
  });

  router.post('/customers', (Request req) async {
    if (_authenticate(req) == null) {
      return _json({'error': 'Unauthorized'}, status: 401);
    }

    final payload = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    const required = [
      'name', 'email', 'phone', 'idNumber', 'product',
      'quantity', 'direction', 'staffName'
    ];
    for (final field in required) {
      if ((payload[field] ?? '').toString().trim().isEmpty) {
        return _json({'error': '$field is required'}, status: 400);
      }
    }
    if (payload['direction'] != 'in' && payload['direction'] != 'out') {
      return _json({'error': "direction must be 'in' or 'out'"}, status: 400);
    }

    final customer = {
      'id': _uuid.v4(),
      'name': payload['name'],
      'email': payload['email'],
      'phone': payload['phone'],
      'idNumber': payload['idNumber'],
      'product': payload['product'],
      'quantity': payload['quantity'].toString(),
      'direction': payload['direction'],
      'date': payload['date'] ?? '',
      'time': payload['time'] ?? '',
      'staffName': payload['staffName'],
      'createdAt': DateTime.now().toIso8601String(),
    };

    _appDb.addCustomer(customer);
    return _json(customer, status: 201);
  });

  router.put('/customers/<id>', (Request req, String id) async {
    if (_authenticate(req) == null) {
      return _json({'error': 'Unauthorized'}, status: 401);
    }

    if (_appDb.getCustomerById(id) == null) {
      return _json({'error': 'Record not found'}, status: 404);
    }

    final payload = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    const required = [
      'name', 'email', 'phone', 'idNumber', 'product',
      'quantity', 'direction', 'staffName'
    ];
    for (final field in required) {
      if ((payload[field] ?? '').toString().trim().isEmpty) {
        return _json({'error': '$field is required'}, status: 400);
      }
    }
    if (payload['direction'] != 'in' && payload['direction'] != 'out') {
      return _json({'error': "direction must be 'in' or 'out'"}, status: 400);
    }

    final updated = {
      'name': payload['name'],
      'email': payload['email'],
      'phone': payload['phone'],
      'idNumber': payload['idNumber'],
      'product': payload['product'],
      'quantity': payload['quantity'].toString(),
      'direction': payload['direction'],
      'date': payload['date'] ?? '',
      'time': payload['time'] ?? '',
      'staffName': payload['staffName'],
    };

    _appDb.updateCustomer(id, updated);
    return _json({...updated, 'id': id});
  });

  // --- Invoices ---

  router.get('/invoices', (Request req) async {
    if (_authenticate(req) == null) {
      return _json({'error': 'Unauthorized'}, status: 401);
    }
    return _json(_appDb.getInvoices());
  });

  router.post('/invoices', (Request req) async {
    if (_authenticate(req) == null) {
      return _json({'error': 'Unauthorized'}, status: 401);
    }

    if (!req.isMultipart) {
      return _json(
          {'error': 'Expected multipart/form-data with a file field'},
          status: 400);
    }

    String? customerId;
    String? amount;
    String? dueDate;
    String? savedFileName;

    await for (final formData in req.multipartFormData) {
      switch (formData.name) {
        case 'customerId':
          customerId = await formData.part.readString();
          break;
        case 'amount':
          amount = await formData.part.readString();
          break;
        case 'dueDate':
          dueDate = await formData.part.readString();
          break;
        case 'file':
          final originalName = formData.filename ?? 'invoice.pdf';
          savedFileName = '${_uuid.v4()}-$originalName';
          final file = File('uploads/$savedFileName');
          final sink = file.openWrite();
          await formData.part.pipe(sink);
          await sink.close();
          break;
      }
    }

    if (customerId == null || amount == null || savedFileName == null) {
      return _json(
          {'error': 'customerId, amount, and file are required'},
          status: 400);
    }

    if (_appDb.getCustomerById(customerId) == null) {
      return _json({'error': 'customerId does not exist'}, status: 400);
    }

    final invoice = {
      'id': _uuid.v4(),
      'customerId': customerId,
      'amount': amount,
      'dueDate': dueDate ?? '',
      'fileName': savedFileName,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    };

    _appDb.addInvoice(invoice);
    return _json(invoice, status: 201);
  });

  // Serve uploaded invoice files (kept simple/unauthenticated for MVP so
  // links work without extra header wiring; revisit before production use)
  router.get('/uploads/<fileName>', (Request req, String fileName) async {
    final file = File('uploads/$fileName');
    if (!await file.exists()) {
      return Response.notFound(jsonEncode({'error': 'File not found'}),
          headers: {'Content-Type': 'application/json'});
    }
    final bytes = await file.readAsBytes();
    final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
    return Response.ok(bytes,
        headers: {'Content-Type': mimeType, ..._corsHeaders});
  });

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_cors())
      .addHandler(router.call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('NCPB Invoice Manager API running on http://${server.address.host}:${server.port}');
}
