import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_service.dart';
import '../models.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final ApiService api = ApiService();

  List<Client> _clients = [];
  List<Product> _products = [];
  List<StoreRecord> _records = [];

  bool _loading = true;
  String? _error;

  // Selected for dropdown autofill
  Client? _selectedClient;
  Product? _selectedProduct;

  final _quantityController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _staffNameController = TextEditingController(text: ApiService.loggedInUsername ?? 'admin');
  final _notesController = TextEditingController();
  String _direction = 'in';

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  String? _filterDirection;

  StoreRecord? _editingRecord;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final clients = await api.getClients();
      final products = await api.getProducts();
      final records = await api.getRecords(
        startDate: _startDate == null ? null : '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}',
        endDate: _endDate == null ? null : '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}',
        direction: _filterDirection,
      );

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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      _dateController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: now);
    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      _timeController.text = '$hour:$minute';
    }
  }

  void _onClientSelected(Client? client) {
    setState(() {
      _selectedClient = client;
    });
  }

  void _onProductSelected(Product? product) {
    setState(() {
      _selectedProduct = product;
    });
  }

  void _startEdit(StoreRecord r) {
    setState(() {
      _editingRecord = r;
      _selectedClient = _clients.firstWhere((c) => c.id == r.clientId, orElse: () => Client(id: r.clientId, name: r.clientName, email: r.clientEmail, phone: r.clientPhone, idNumber: r.clientIdNumber, createdAt: ''));
      _selectedProduct = _products.firstWhere((p) => p.id == r.productId, orElse: () => Product(id: r.productId, name: r.productName, unit: 'Bag 90kg', defaultPricePerBag: 15.0, description: '', createdAt: ''));
      _quantityController.text = r.quantity.toString();
      _direction = r.direction;
      _dateController.text = r.date;
      _timeController.text = r.time;
      _staffNameController.text = r.staffName;
      _notesController.text = r.notes;
      _error = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingRecord = null;
      _selectedClient = null;
      _selectedProduct = null;
      _quantityController.clear();
      _direction = 'in';
      _dateController.clear();
      _timeController.clear();
      _staffNameController.text = ApiService.loggedInUsername ?? 'admin';
      _notesController.clear();
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_selectedClient == null) {
      setState(() => _error = 'Please select a Client ID / Client Name');
      return;
    }
    if (_selectedProduct == null) {
      setState(() => _error = 'Please select a Product ID / Grain Product');
      return;
    }
    final qty = double.tryParse(_quantityController.text.trim());
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Please enter a valid quantity of bags');
      return;
    }

    if (_dateController.text.isEmpty) {
      final now = DateTime.now();
      _dateController.text = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_editingRecord == null) {
        await api.addRecord(
          clientId: _selectedClient!.id,
          clientName: _selectedClient!.name,
          clientEmail: _selectedClient!.email,
          clientPhone: _selectedClient!.phone,
          clientIdNumber: _selectedClient!.idNumber,
          productId: _selectedProduct!.id,
          productName: _selectedProduct!.name,
          quantity: qty,
          direction: _direction,
          date: _dateController.text.trim(),
          time: _timeController.text.trim(),
          staffName: _staffNameController.text.trim(),
          notes: _notesController.text.trim(),
        );
      } else {
        await api.updateRecord(
          id: _editingRecord!.id,
          clientId: _selectedClient!.id,
          clientName: _selectedClient!.name,
          clientEmail: _selectedClient!.email,
          clientPhone: _selectedClient!.phone,
          clientIdNumber: _selectedClient!.idNumber,
          productId: _selectedProduct!.id,
          productName: _selectedProduct!.name,
          quantity: qty,
          direction: _direction,
          date: _dateController.text.trim(),
          time: _timeController.text.trim(),
          staffName: _staffNameController.text.trim(),
          notes: _notesController.text.trim(),
        );
      }

      final wasEditing = _editingRecord != null;
      _cancelEdit();
      _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasEditing ? 'Record updated' : 'Record added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _exportToCsv() async {
    final rows = <List<dynamic>>[
      ['Record ID', 'Date', 'Time', 'Client ID', 'Client Name', 'Phone', 'National ID', 'Product ID', 'Product Name', 'Quantity (Bags)', 'Direction', 'Staff Name', 'Notes'],
    ];

    for (final r in _records) {
      rows.add([
        r.id,
        r.date,
        r.time,
        r.clientId,
        r.clientName,
        r.clientPhone,
        r.clientIdNumber,
        r.productId,
        r.productName,
        r.quantity,
        r.direction.toUpperCase(),
        r.staffName,
        r.notes,
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvData);
    final Uri url = Uri.dataFromBytes(bytes, mimeType: 'text/csv');

    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not trigger export download')),
        );
      }
    }
  }

  InputDecoration _decor(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _buildForm() {
    final isEditing = _editingRecord != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isEditing ? Colors.orange.shade300 : Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(isEditing ? Icons.edit_note : Icons.note_add_outlined,
                    color: isEditing ? Colors.orange.shade800 : const Color(0xFF1E3A8A)),
                const SizedBox(width: 8),
                Text(isEditing ? 'Edit Store Record' : 'Log New Store Movement',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                if (isEditing) ...[
                  const Spacer(),
                  TextButton(onPressed: _cancelEdit, child: const Text('Cancel')),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Client Selector with Auto-fill
            DropdownButtonFormField<Client>(
              decoration: _decor('Select Client ID / Name', Icons.person_search_outlined),
              initialValue: _selectedClient,
              isExpanded: true,
              items: _clients
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.id} - ${c.name}', overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _onClientSelected,
            ),
            if (_selectedClient != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'Auto-filled: ${_selectedClient!.name} • Email: ${_selectedClient!.email} • Phone: ${_selectedClient!.phone} • ID: ${_selectedClient!.idNumber}',
                  style: TextStyle(color: Colors.blue.shade900, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Product Selector with Auto-fill
            DropdownButtonFormField<Product>(
              decoration: _decor('Select Product ID / Grain', Icons.qr_code_scanner),
              initialValue: _selectedProduct,
              isExpanded: true,
              items: _products
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text('${p.id} - ${p.name} (${p.unit})', overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _onProductSelected,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: _decor('Quantity (Bags)', Icons.numbers),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'in', label: Text('IN'), icon: Icon(Icons.arrow_downward, size: 16)),
                      ButtonSegment(value: 'out', label: Text('OUT'), icon: Icon(Icons.arrow_upward, size: 16)),
                    ],
                    selected: {_direction},
                    onSelectionChanged: (s) => setState(() => _direction = s.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateController,
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: _decor('Date', Icons.calendar_today_outlined).copyWith(suffixIcon: const Icon(Icons.arrow_drop_down)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _timeController,
                    readOnly: true,
                    onTap: _pickTime,
                    decoration: _decor('Time', Icons.access_time).copyWith(suffixIcon: const Icon(Icons.arrow_drop_down)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _staffNameController,
              decoration: _decor('Logged By (Staff)', Icons.assignment_ind_outlined),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _notesController,
              decoration: _decor('Notes / Storage Location (Optional)', Icons.sticky_note_2_outlined),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 16),

            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(isEditing ? Icons.save_outlined : Icons.add),
                label: Text(_saving ? 'Saving...' : (isEditing ? 'Update Record' : 'Log Record')),
                style: FilledButton.styleFrom(
                  backgroundColor: isEditing ? Colors.orange.shade800 : const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.filter_list, size: 20, color: Color(0xFF0F172A)),
            const SizedBox(width: 8),
            const Text('Filter Records: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: _filterDirection ?? 'all',
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Directions')),
                DropdownMenuItem(value: 'in', child: Text('IN Only')),
                DropdownMenuItem(value: 'out', child: Text('OUT Only')),
              ],
              onChanged: (val) {
                setState(() => _filterDirection = val == 'all' ? null : val);
                _loadAll();
              },
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _exportToCsv,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export Excel/CSV'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.teal.shade800,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilterBar(),
        const SizedBox(height: 12),
        _loading
            ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            : _records.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('No store records found.', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final r = _records[index];
                      final isOut = r.direction == 'out';
                      final color = isOut ? Colors.red.shade700 : Colors.green.shade700;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(isOut ? Icons.arrow_upward : Icons.arrow_downward, color: color, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text('${r.clientName} (${r.clientId})',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            isOut ? 'OUT' : 'IN',
                                            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Product: ${r.productName} (${r.productId})  •  Qty: ${r.quantity} Bags',
                                      style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Date: ${r.date} ${r.time}  •  Logged by: ${r.staffName}',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Email: ${r.clientEmail}  •  Phone: ${r.clientPhone}  •  ID: ${r.clientIdNumber}',
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _startEdit(r),
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'Edit Record',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 850;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildForm()),
                    const SizedBox(width: 20),
                    Expanded(flex: 3, child: _buildRecordList()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildForm(),
                    const SizedBox(height: 24),
                    _buildRecordList(),
                  ],
                ),
        );
      },
    );
  }
}
