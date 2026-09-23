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

/// Returns the logged-in username if the request has a valid token, or null if not.
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
    return _json({'status': 'ok', 'service': 'NCPB Grain Store API'});
  });

  // --- Auth ---

  router.post('/auth/login', (Request req) async {
    final payload = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final username = (payload['username'] ?? '').toString().trim();
    final password = (payload['password'] ?? '').toString();

    if (username.isEmpty || password.isEmpty) {
      return _json({'error': 'Username and password are required'}, status: 400);
    }

    final staff = _appDb.findStaffByUsername(username);
    if (staff == null || staff['passwordHash'] != hashPassword(password)) {
      return _json({'error': 'Invalid username or password'}, status: 401);
    }

    final token = _uuid.v4();
    _tokens[token] = username;
    return _json({'token': token, 'username': username});
  });

  router.post('/auth/signup', (Request req) async {
    final payload = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final username = (payload['username'] ?? '').toString().trim();
    final password = (payload['password'] ?? '').toString();

    if (username.isEmpty || password.isEmpty) {
      return _json({'error': 'Username and password are required'}, status: 400);
    }

    final existing = _appDb.findStaffByUsername(username);
    if (existing != null) {
      return _json({'error': 'Username already exists'}, status: 400);
    }

    _appDb.addStaff(username, password);

    final token = _uuid.v4();
    _tokens[token] = username;
    return _json({'token': token, 'username': username}, status: 201);
  });

  router.post('/auth/logout', (Request req) async {
    final header = req.headers['authorization'];
    if (header != null && header.startsWith('Bearer ')) {
      _tokens.remove(header.substring(7));
    }
    return _json({'ok': true});
  });

  // --- Clients ---

  router.get('/clients', (Request req) async {
    if (_authenticate(req) == null) return _json({'error': 'Unauthorized'}, status: 401);
    return _json(_appDb.getClients());
  });

  router.post('/clients', (Request req) async {
    if (_authenticate(req) == null) return _json({'error': 'Unauthorized'}, status: 401);
    final p = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    final id = (p['id'] ?? '').toString().trim().isEmpty
        ? 'CL-${1000 + _appDb.getClients().length + 1}'
        : p['id'].toString().trim();

    final client = {
      'id': id,
      'name': (p['name'] ?? '').toString().trim(),
      'email': (p['email'] ?? '').toString().trim(),
      'phone': (p['phone'] ?? '').toString().trim(),
      'idNumber': (p['idNumber'] ?? '').toString().trim(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (client['name'].toString().isEmpty) {
      return _json({'error': 'Client name is required'}, status: 400);
    }

    _appDb.addClient(client);
    return _json(client, status: 201);
  });

  router.put('/clients/<id>', (Request req, String id) async {
    if (_authenticate(req) == null) return _json({'error': 'Unauthorized'}, status: 401);
    final p = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    final updated = {
      'name': (p['name'] ?? '').toString().trim(),
      'email': (p['email'] ?? '').toString().trim(),
      'phone': (p['phone'] ?? '').toString().trim(),
      'idNumber': (p['idNumber'] ?? '').toString().trim(),
    };

    _appDb.updateClient(id, updated);
    return _json({'id': id, ...updated});
  });

  router.delete('/clients/<id>', (Request req, String id) async {
    if (_authenticate(req) == null) return _json({'error': 'Unauthorized'}, status: 401);
    _appDb.deleteClient(id);
    return _json({'ok': true});
  });

  // --- Products ---

  router.get('/products', (Request req) async {
    if (_authenticate(req) == null) return _json({'error': 'Unauthorized'}, status: 401);
    return _json(_appDb.getProducts());
  });

  router.post('/products', (Request req) async {
    if (_authenticate(req) == null) return _json({'error': 'Unauthorized'}, status: 401);
    final p = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    final id = (p['id'] ?? '').toString().trim().isEmpty
        ? 'PRD-${100 + _appDb.getProducts().length + 1}'
        : p['id'].toString().trim();

    final product = {
      'id': id,
      'name': (p['name'] ?? '').toString().trim(),
      'unit': (p['unit'] ?? 'Bag 90kg').toString().trim(),
      'defaultPricePerBag': double.tryParse(p['defaultPricePerBag']?.toString() ?? '') ?? 15.0,
      'description': (p['description'] ?? '').toString().trim(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (product['name'].toString().isEmpty) {
      return _json({'error': 'Product name is required'}, status: 400);
    }

    _appDb.addProduct(product);
    return _json(product, status: 201);
  });

  router.put('/products/<id>', (Request req, String id) async {
    if (_authenticate(req) == null) return _json({'error': 'Unauthorized'}, status: 401);
    final p = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    final updated = {
      'name': (p['name'] ?? '').toString().trim(),
      'unit': (p['unit'] ?? 'Bag 90kg').toString().trim(),
      'defaultPricePerBag': double.tryParse(p['defaultPricePerBag']?.toString() ?? '') ?? 15.0,
      'description': (p['description'] ?? '').toString().trim(),
    };

    _appDb.updateProduct(id, updated);
    return _json({'id': id, ...updated});
  });

  router.delete('/products/<id>', (Request req, String id) async {
    if (_authenticate(req) == null) return _json({'error': 'Unauthorized'}, status: 401);
    _appDb.deleteProduct(id);
    return _json({'ok': true});
  });

  // --- Store Records (with filters) ---

  router.get('/records', (Request req) async {
    if (_authenticate(req) == null) return _json({'error': 'Unauthorized'}, status: 401);

    final params = req.url.queryParameters;
    final startDate = params['startDate'];
    final endDate = params['endDate'];
    final clientId = params['clientId'];
    final productId = params['productId'];
    final direction = params['direction'];

    return _json(_appDb.getRecords(
      startDate: startDate,
      endDate: endDate,
      clientId: clientId,
      productId: productId,
      direction: direction,
    ));
  });

  router.post('/records', (Request req) async {
    if (_authenticate(req) == null) return _json({'error': 'Unauthorized'}, status: 401);
    final p = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    final record = {
      'id': _uuid.v4(),
      'clientId': (p['clientId'] ?? '').toString().trim(),
      'clientName': (p['clientName'] ?? '').toString().trim(),
      'clientEmail': (p['clientEmail'] ?? '').toString().trim(),
      'clientPhone': (p['clientPhone'] ?? '').toString().trim(),
      'clientIdNumber': (p['clientIdNumber'] ?? '').toString().trim(),
      'productId': (p['productId'] ?? '').toString().trim(),
      'productName': (p['productName'] ?? '').toString().trim(),
      'quantity': double.tryParse(p['quantity']?.toString() ?? '') ?? 0.0,
      'direction': p['direction'] == 'out' ? 'out' : 'in',
      'date': (p['date'] ?? '').toString().trim(),
      'time': (p['time'] ?? '').toString().trim(),
      'staffName': (p['staffName'] ?? '').toString().trim(),
      'notes': (p['notes'] ?? '').toString().trim(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (record['clientId'].toString().isEmpty || record['productId'].toString().isEmpty) {
      return _json({'error': 'Client ID and Product ID are required'}, status: 400);
    }

    _appDb.addRecord(record);
    return _json(record, status: 201);
  });

  router.put('/records/<id>', (Request req, String id) async {
    if (_authenticate(req) == null) return _json({'error': 'Unauthorized'}, status: 401);
    final p = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    final updated = {
      'clientId': (p['clientId'] ?? '').toString().trim(),
      'clientName': (p['clientName'] ?? '').toString().trim(),
      'clientEmail': (p['clientEmail'] ?? '').toString().trim(),
      'clientPhone': (p['clientPhone'] ?? '').toString().trim(),
      'clientIdNumber': (p['clientIdNumber'] ?? '').toString().trim(),
      'productId': (p['productId'] ?? '').toString().trim(),
      'productName': (p['productName'] ?? '').toString().trim(),
      'quantity': double.tryParse(p['quantity']?.toString() ?? '') ?? 0.0,
      'direction': p['direction'] == 'out' ? 'out' : 'in',
      'date': (p['date'] ?? '').toString().trim(),
      'time': (p['time'] ?? '').toString().trim(),
      'staffName': (p['staffName'] ?? '').toString().trim(),
      'notes': (p['notes'] ?? '').toString().trim(),
    };

    _appDb.updateRecord(id, updated);
    return _json({'id': id, ...updated});
  });

  router.delete('/records/<id>', (Request req, String id) async {
    if (_authenticate(req) == null) return _json({'error': 'Unauthorized'}, status: 401);
    _appDb.deleteRecord(id);
    return _json({'ok': true});
  });

  // --- Fumigation Invoices ---

  router.get('/fumigation-invoices', (Request req) async {
    if (_authenticate(req) == null) return _json({'error': 'Unauthorized'}, status: 401);
    return _json(_appDb.getFumigationInvoices());
  });

  router.post('/fumigation-invoices', (Request req) async {
    if (_authenticate(req) == null) return _json({'error': 'Unauthorized'}, status: 401);
    final p = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    final bags = double.tryParse(p['bagsCount']?.toString() ?? '') ?? 0.0;
    final rate = double.tryParse(p['pricePerBag']?.toString() ?? '') ?? 15.0;
    final total = bags * rate;

    final invoice = {
      'id': 'FUM-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
      'clientId': (p['clientId'] ?? '').toString().trim(),
      'clientName': (p['clientName'] ?? '').toString().trim(),
      'quarter': (p['quarter'] ?? 'Q1').toString().trim(),
      'bagsCount': bags,
      'pricePerBag': rate,
      'totalAmount': total,
      'dueDate': (p['dueDate'] ?? '').toString().trim(),
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    };

    _appDb.addFumigationInvoice(invoice);
    return _json(invoice, status: 201);
  });

  router.put('/fumigation-invoices/<id>/status', (Request req, String id) async {
    if (_authenticate(req) == null) return _json({'error': 'Unauthorized'}, status: 401);
    final p = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final status = p['status'] ?? 'paid';
    _appDb.updateFumigationInvoiceStatus(id, status);
    return _json({'id': id, 'status': status});
  });

  router.delete('/fumigation-invoices/<id>', (Request req, String id) async {
    if (_authenticate(req) == null) return _json({'error': 'Unauthorized'}, status: 401);
    _appDb.deleteFumigationInvoice(id);
    return _json({'ok': true});
  });

  // --- Standard Invoices ---

  router.get('/invoices', (Request req) async {
    if (_authenticate(req) == null) return _json({'error': 'Unauthorized'}, status: 401);
    return _json(_appDb.getInvoices());
  });

  router.post('/invoices', (Request req) async {
    if (_authenticate(req) == null) return _json({'error': 'Unauthorized'}, status: 401);
    if (!req.isMultipart) return _json({'error': 'Expected multipart/form-data'}, status: 400);

    String? clientId;
    String? amount;
    String? dueDate;
    String? savedFileName;

    await for (final formData in req.multipartFormData) {
      switch (formData.name) {
        case 'clientId':
        case 'customerId':
          clientId = await formData.part.readString();
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

    if (clientId == null || amount == null || savedFileName == null) {
      return _json({'error': 'clientId, amount, and file are required'}, status: 400);
    }

    final invoice = {
      'id': _uuid.v4(),
      'clientId': clientId,
      'amount': amount,
      'dueDate': dueDate ?? '',
      'fileName': savedFileName,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    };

    _appDb.addInvoice(invoice);
    return _json(invoice, status: 201);
  });

  router.get('/uploads/<fileName>', (Request req, String fileName) async {
    final file = File('uploads/$fileName');
    if (!await file.exists()) {
      return Response.notFound(jsonEncode({'error': 'File not found'}),
          headers: {'Content-Type': 'application/json'});
    }
    final bytes = await file.readAsBytes();
    final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
    return Response.ok(bytes, headers: {'Content-Type': mimeType, ..._corsHeaders});
  });

  Middleware _errorHandler() {
    return (Handler innerHandler) {
      return (Request request) async {
        try {
          return await innerHandler(request);
        } catch (e, stack) {
          print('Server Error: $e\n$stack');
          return _json({'error': 'Server error: $e'}, status: 500);
        }
      };
    };
  }

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_cors())
      .addMiddleware(_errorHandler())
      .addHandler(router.call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('NCPB Grain Store API running on http://${server.address.host}:${server.port}');
}
