import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

final _uuid = Uuid();

String hashPassword(String password) {
  return sha256.convert(utf8.encode(password)).toString();
}

/// SQLite-backed storage for NCPB Grain Store Management.
class AppDatabase {
  late Database db;

  void init() {
    Directory('data').createSync(recursive: true);
    Directory('uploads').createSync(recursive: true);
    db = sqlite3.open('data/ncpb.db');

    // 1. Staff table
    db.execute('''
      CREATE TABLE IF NOT EXISTS staff (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        passwordHash TEXT NOT NULL,
        createdAt TEXT NOT NULL
      );
    ''');

    // 2. Clients table
    db.execute('''
      CREATE TABLE IF NOT EXISTS clients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT NOT NULL,
        idNumber TEXT NOT NULL,
        createdAt TEXT NOT NULL
      );
    ''');

    // 3. Products table
    db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        defaultPricePerBag REAL NOT NULL DEFAULT 15.0,
        description TEXT,
        createdAt TEXT NOT NULL
      );
    ''');

    // 4. Store Records table
    db.execute('''
      CREATE TABLE IF NOT EXISTS records (
        id TEXT PRIMARY KEY,
        clientId TEXT NOT NULL,
        clientName TEXT NOT NULL,
        clientEmail TEXT NOT NULL,
        clientPhone TEXT NOT NULL,
        clientIdNumber TEXT NOT NULL,
        productId TEXT NOT NULL,
        productName TEXT NOT NULL,
        quantity REAL NOT NULL,
        direction TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        staffName TEXT NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL
      );
    ''');

    // 5. Fumigation Invoices table
    db.execute('''
      CREATE TABLE IF NOT EXISTS fumigation_invoices (
        id TEXT PRIMARY KEY,
        clientId TEXT NOT NULL,
        clientName TEXT NOT NULL,
        quarter TEXT NOT NULL,
        bagsCount REAL NOT NULL,
        pricePerBag REAL NOT NULL,
        totalAmount REAL NOT NULL,
        dueDate TEXT NOT NULL,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL
      );
    ''');

    // 6. Standard Invoices table
    try {
      db.select('SELECT clientId FROM invoices LIMIT 1');
    } catch (_) {
      db.execute('DROP TABLE IF EXISTS invoices');
    }

    db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id TEXT PRIMARY KEY,
        clientId TEXT NOT NULL,
        amount TEXT NOT NULL,
        dueDate TEXT,
        fileName TEXT NOT NULL,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL
      );
    ''');

    _seedAdmin();
  }

  void _seedAdmin() {
    final existing =
        db.select('SELECT id FROM staff WHERE username = ?', ['admin']);
    if (existing.isEmpty) {
      db.execute(
        'INSERT INTO staff (id, username, passwordHash, createdAt) VALUES (?, ?, ?, ?)',
        [
          _uuid.v4(),
          'admin',
          hashPassword('admin123'),
          DateTime.now().toIso8601String()
        ],
      );
      // ignore: avoid_print
      print('Seeded default staff login -> username: admin, password: admin123');
    }
  }

  // --- Staff / Auth ---

  Map<String, dynamic>? findStaffByUsername(String username) {
    final rows =
        db.select('SELECT * FROM staff WHERE username = ?', [username]);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  void addStaff(String username, String password) {
    db.execute(
      'INSERT INTO staff (id, username, passwordHash, createdAt) VALUES (?, ?, ?, ?)',
      [
        _uuid.v4(),
        username,
        hashPassword(password),
        DateTime.now().toIso8601String()
      ],
    );
  }

  // --- Clients ---

  List<Map<String, dynamic>> getClients() {
    final rows = db.select('SELECT * FROM clients ORDER BY name ASC');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Map<String, dynamic>? getClientById(String id) {
    final rows = db.select('SELECT * FROM clients WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  void addClient(Map<String, dynamic> c) {
    db.execute('''
      INSERT INTO clients (id, name, email, phone, idNumber, createdAt)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [
      c['id'],
      c['name'],
      c['email'],
      c['phone'],
      c['idNumber'],
      c['createdAt'] ?? DateTime.now().toIso8601String(),
    ]);
  }

  void updateClient(String id, Map<String, dynamic> c) {
    db.execute('''
      UPDATE clients SET name = ?, email = ?, phone = ?, idNumber = ? WHERE id = ?
    ''', [c['name'], c['email'], c['phone'], c['idNumber'], id]);
  }

  void deleteClient(String id) {
    db.execute('DELETE FROM clients WHERE id = ?', [id]);
  }

  // --- Products ---

  List<Map<String, dynamic>> getProducts() {
    final rows = db.select('SELECT * FROM products ORDER BY name ASC');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Map<String, dynamic>? getProductById(String id) {
    final rows = db.select('SELECT * FROM products WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  void addProduct(Map<String, dynamic> p) {
    db.execute('''
      INSERT INTO products (id, name, unit, defaultPricePerBag, description, createdAt)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [
      p['id'],
      p['name'],
      p['unit'] ?? 'Bag 90kg',
      p['defaultPricePerBag'] ?? 15.0,
      p['description'] ?? '',
      p['createdAt'] ?? DateTime.now().toIso8601String(),
    ]);
  }

  void updateProduct(String id, Map<String, dynamic> p) {
    db.execute('''
      UPDATE products SET name = ?, unit = ?, defaultPricePerBag = ?, description = ? WHERE id = ?
    ''', [
      p['name'],
      p['unit'] ?? 'Bag 90kg',
      p['defaultPricePerBag'] ?? 15.0,
      p['description'] ?? '',
      id,
    ]);
  }

  void deleteProduct(String id) {
    db.execute('DELETE FROM products WHERE id = ?', [id]);
  }

  // --- Store Records ---

  List<Map<String, dynamic>> getRecords({
    String? startDate,
    String? endDate,
    String? clientId,
    String? productId,
    String? direction,
  }) {
    final whereClauses = <String>[];
    final params = <Object>[];

    if (startDate != null && startDate.isNotEmpty) {
      whereClauses.add('date >= ?');
      params.add(startDate);
    }
    if (endDate != null && endDate.isNotEmpty) {
      whereClauses.add('date <= ?');
      params.add(endDate);
    }
    if (clientId != null && clientId.isNotEmpty) {
      whereClauses.add('clientId = ?');
      params.add(clientId);
    }
    if (productId != null && productId.isNotEmpty) {
      whereClauses.add('productId = ?');
      params.add(productId);
    }
    if (direction != null && direction.isNotEmpty) {
      whereClauses.add('direction = ?');
      params.add(direction);
    }

    final whereStr = whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';
    final rows = db.select('SELECT * FROM records $whereStr ORDER BY date DESC, time DESC, createdAt DESC', params);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Map<String, dynamic>? getRecordById(String id) {
    final rows = db.select('SELECT * FROM records WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  void addRecord(Map<String, dynamic> r) {
    db.execute('''
      INSERT INTO records (
        id, clientId, clientName, clientEmail, clientPhone, clientIdNumber,
        productId, productName, quantity, direction, date, time, staffName, notes, createdAt
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      r['id'],
      r['clientId'],
      r['clientName'],
      r['clientEmail'],
      r['clientPhone'],
      r['clientIdNumber'],
      r['productId'],
      r['productName'],
      r['quantity'],
      r['direction'],
      r['date'],
      r['time'],
      r['staffName'],
      r['notes'] ?? '',
      r['createdAt'] ?? DateTime.now().toIso8601String(),
    ]);
  }

  void updateRecord(String id, Map<String, dynamic> r) {
    db.execute('''
      UPDATE records SET
        clientId = ?, clientName = ?, clientEmail = ?, clientPhone = ?, clientIdNumber = ?,
        productId = ?, productName = ?, quantity = ?, direction = ?, date = ?, time = ?,
        staffName = ?, notes = ?
      WHERE id = ?
    ''', [
      r['clientId'],
      r['clientName'],
      r['clientEmail'],
      r['clientPhone'],
      r['clientIdNumber'],
      r['productId'],
      r['productName'],
      r['quantity'],
      r['direction'],
      r['date'],
      r['time'],
      r['staffName'],
      r['notes'] ?? '',
      id,
    ]);
  }

  void deleteRecord(String id) {
    db.execute('DELETE FROM records WHERE id = ?', [id]);
  }

  // --- Fumigation Invoices ---

  List<Map<String, dynamic>> getFumigationInvoices() {
    final rows = db.select('SELECT * FROM fumigation_invoices ORDER BY createdAt DESC');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  void addFumigationInvoice(Map<String, dynamic> inv) {
    db.execute('''
      INSERT INTO fumigation_invoices (
        id, clientId, clientName, quarter, bagsCount, pricePerBag, totalAmount, dueDate, status, createdAt
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      inv['id'],
      inv['clientId'],
      inv['clientName'],
      inv['quarter'],
      inv['bagsCount'],
      inv['pricePerBag'],
      inv['totalAmount'],
      inv['dueDate'],
      inv['status'] ?? 'pending',
      inv['createdAt'] ?? DateTime.now().toIso8601String(),
    ]);
  }

  void updateFumigationInvoiceStatus(String id, String status) {
    db.execute('UPDATE fumigation_invoices SET status = ? WHERE id = ?', [status, id]);
  }

  void deleteFumigationInvoice(String id) {
    db.execute('DELETE FROM fumigation_invoices WHERE id = ?', [id]);
  }

  // --- Standard Invoices ---

  List<Map<String, dynamic>> getInvoices() {
    final rows = db.select('''
      SELECT invoices.*, clients.name as clientName, clients.email as clientEmail
      FROM invoices
      LEFT JOIN clients ON invoices.clientId = clients.id
      ORDER BY invoices.createdAt DESC
    ''');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  void addInvoice(Map<String, dynamic> inv) {
    db.execute('''
      INSERT INTO invoices (id, clientId, amount, dueDate, fileName, status, createdAt)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [
      inv['id'],
      inv['clientId'],
      inv['amount'],
      inv['dueDate'],
      inv['fileName'],
      inv['status'],
      inv['createdAt'],
    ]);
  }

  void deleteInvoice(String id) {
    db.execute('DELETE FROM invoices WHERE id = ?', [id]);
  }
}
