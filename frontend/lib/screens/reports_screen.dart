import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_service.dart';
import '../models.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ApiService api = ApiService();

  List<Client> _clients = [];
  List<Product> _products = [];
  List<StoreRecord> _records = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final clients = await api.getClients();
      final products = await api.getProducts();
      final records = await api.getRecords();

      if (mounted) {
        setState(() {
          _clients = clients;
          _products = products;
          _records = records;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _exportReportToCsv() async {
    final rows = <List<dynamic>>[
      ['--- STORE INVENTORY SUMMARY REPORT ---'],
      ['Export Date', DateTime.now().toIso8601String()],
      [],
      ['PRODUCT MOVEMENTS & STOCK SUMMARY'],
      ['Product ID', 'Product Name', 'Unit', 'Total IN (Bags)', 'Total OUT (Bags)', 'Net Stock (Bags)'],
    ];

    for (final p in _products) {
      final pRecords = _records.where((r) => r.productId == p.id);
      final inQty = pRecords.where((r) => r.direction == 'in').fold(0.0, (sum, item) => sum + item.quantity);
      final outQty = pRecords.where((r) => r.direction == 'out').fold(0.0, (sum, item) => sum + item.quantity);
      final net = inQty - outQty;

      rows.add([p.id, p.name, p.unit, inQty, outQty, net]);
    }

    rows.add([]);
    rows.add(['CUSTOMER GRAIN STORAGE BALANCES']);
    rows.add(['Client ID', 'Client Name', 'Phone', 'National ID', 'Current Stored Bags']);

    for (final c in _clients) {
      final cRecords = _records.where((r) => r.clientId == c.id);
      final inQty = cRecords.where((r) => r.direction == 'in').fold(0.0, (sum, item) => sum + item.quantity);
      final outQty = cRecords.where((r) => r.direction == 'out').fold(0.0, (sum, item) => sum + item.quantity);
      final net = inQty - outQty;

      rows.add([c.id, c.name, c.phone, c.idNumber, net < 0 ? 0 : net]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvData);
    final Uri url = Uri.dataFromBytes(bytes, mimeType: 'text/csv');

    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not trigger report download')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Inventory & Stock Movement Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Text('Comprehensive breakdown of grain product movements and customer storage ledgers', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                ],
              ),
              FilledButton.icon(
                onPressed: _exportReportToCsv,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export Full Excel/CSV'),
                style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade800),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Product movements card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade300)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, color: Colors.blue.shade800),
                      const SizedBox(width: 8),
                      const Text('Product Stock Movements Summary', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_products.isEmpty)
                    Text('No products available', style: TextStyle(color: Colors.grey.shade600))
                  else
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(2.5),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(1.5),
                        4: FlexColumnWidth(1.5),
                        5: FlexColumnWidth(1.5),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade100),
                          children: const [
                            Padding(padding: EdgeInsets.all(10), child: Text('Product ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Total IN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Total OUT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Net Stock', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)))),
                          ],
                        ),
                        ..._products.map((p) {
                          final pRecords = _records.where((r) => r.productId == p.id);
                          final inQty = pRecords.where((r) => r.direction == 'in').fold(0.0, (sum, item) => sum + item.quantity);
                          final outQty = pRecords.where((r) => r.direction == 'out').fold(0.0, (sum, item) => sum + item.quantity);
                          final net = inQty - outQty;

                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(10), child: Text(p.id, style: const TextStyle(fontWeight: FontWeight.w600))),
                              Padding(padding: const EdgeInsets.all(10), child: Text(p.name)),
                              Padding(padding: const EdgeInsets.all(10), child: Text(p.unit)),
                              Padding(padding: const EdgeInsets.all(10), child: Text('${inQty.toInt()} Bags', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                              Padding(padding: const EdgeInsets.all(10), child: Text('${outQty.toInt()} Bags', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                              Padding(padding: const EdgeInsets.all(10), child: Text('${net.toInt()} Bags', style: const TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold))),
                            ],
                          );
                        }),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Customer Inventory Breakdown
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade300)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people_outline, color: Colors.indigo.shade800),
                      const SizedBox(width: 8),
                      const Text('Customer Warehouse Storage Balances', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_clients.isEmpty)
                    Text('No clients registered', style: TextStyle(color: Colors.grey.shade600))
                  else
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(2.5),
                        2: FlexColumnWidth(1.8),
                        3: FlexColumnWidth(1.8),
                        4: FlexColumnWidth(1.8),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade100),
                          children: const [
                            Padding(padding: EdgeInsets.all(10), child: Text('Client ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Client Name', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(10), child: Text('National ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Current Stored Stock', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))),
                          ],
                        ),
                        ..._clients.map((c) {
                          final cRecords = _records.where((r) => r.clientId == c.id);
                          final inQty = cRecords.where((r) => r.direction == 'in').fold(0.0, (sum, item) => sum + item.quantity);
                          final outQty = cRecords.where((r) => r.direction == 'out').fold(0.0, (sum, item) => sum + item.quantity);
                          final net = inQty - outQty;

                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(10), child: Text(c.id, style: const TextStyle(fontWeight: FontWeight.w600))),
                              Padding(padding: const EdgeInsets.all(10), child: Text(c.name)),
                              Padding(padding: const EdgeInsets.all(10), child: Text(c.phone)),
                              Padding(padding: const EdgeInsets.all(10), child: Text(c.idNumber)),
                              Padding(padding: const EdgeInsets.all(10), child: Text('${net < 0 ? 0 : net.toInt()} Bags', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold))),
                            ],
                          );
                        }),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
