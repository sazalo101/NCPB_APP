import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

final _uuid = Uuid();

String hashPassword(String password) {
  return sha256.convert(utf8.encode(password)).toString();
}

/// SQLite-backed storage. Data persists in data/ncpb.db between restarts.
class AppDatabase {
  late Database db;

  void init() {
    Directory('data').createSync(recursive: true);
    Directory('uploads').createSync(recursive: true);
    db = sqlite3.open('data/ncpb.db');

    db.execute('''
      CREATE TABLE IF NOT EXISTS staff (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        passwordHash TEXT NOT NULL,
        createdAt TEXT NOT NULL
      );
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT NOT NULL,
        idNumber TEXT NOT NULL,
        product TEXT NOT NULL,
        quantity TEXT NOT NULL,
        direction TEXT NOT NULL,
        date TEXT,
        time TEXT,
        staffName TEXT NOT NULL,
        createdAt TEXT NOT NULL
      );
    ''');

    // Migration for databases created before the "time" column existed.
    try {
      db.execute('ALTER TABLE customers ADD COLUMN time TEXT;');
    } catch (_) {
      // Column already exists — fine, ignore.
    }

    db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id TEXT PRIMARY KEY,
        customerId TEXT NOT NULL,
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
      print('Seeded default login -> username: admin  password: admin123');
      // ignore: avoid_print
      print('Change this before real use (see README).');
    }
  }

  // --- Staff / auth ---

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

  // --- Customers ---

  List<Map<String, dynamic>> getCustomers() {
    final rows = db.select('SELECT * FROM customers ORDER BY createdAt DESC');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Map<String, dynamic>? getCustomerById(String id) {
    final rows = db.select('SELECT * FROM customers WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  void addCustomer(Map<String, dynamic> c) {
    db.execute('''
      INSERT INTO customers
        (id, name, email, phone, idNumber, product, quantity, direction, date, time, staffName, createdAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      c['id'],
      c['name'],
      c['email'],
      c['phone'],
      c['idNumber'],
      c['product'],
      c['quantity'],
      c['direction'],
      c['date'],
      c['time'],
      c['staffName'],
      c['createdAt'],
    ]);
  }

  void updateCustomer(String id, Map<String, dynamic> c) {
    db.execute('''
      UPDATE customers SET
        name = ?, email = ?, phone = ?, idNumber = ?, product = ?,
        quantity = ?, direction = ?, date = ?, time = ?, staffName = ?
      WHERE id = ?
    ''', [
      c['name'],
      c['email'],
      c['phone'],
      c['idNumber'],
      c['product'],
      c['quantity'],
      c['direction'],
      c['date'],
      c['time'],
      c['staffName'],
      id,
    ]);
  }

  // --- Invoices ---

  List<Map<String, dynamic>> getInvoices() {
    final rows = db.select('''
      SELECT invoices.*, customers.name as customerName, customers.email as customerEmail
      FROM invoices
      LEFT JOIN customers ON invoices.customerId = customers.id
      ORDER BY invoices.createdAt DESC
    ''');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  void addInvoice(Map<String, dynamic> inv) {
    db.execute('''
      INSERT INTO invoices (id, customerId, amount, dueDate, fileName, status, createdAt)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [
      inv['id'],
      inv['customerId'],
      inv['amount'],
      inv['dueDate'],
      inv['fileName'],
      inv['status'],
      inv['createdAt'],
    ]);
  }
}
