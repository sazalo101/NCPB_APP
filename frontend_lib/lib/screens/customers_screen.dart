import 'package:flutter/material.dart';
import '../api_service.dart';
import '../models.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final ApiService api = ApiService();
  late Future<List<Customer>> _customersFuture;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _productController = TextEditingController();
  final _quantityController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _staffNameController = TextEditingController();
  String _direction = 'in';
  bool _saving = false;
  String? _error;

  // When non-null, the form is editing this record instead of creating a new one.
  Customer? _editing;

  @override
  void initState() {
    super.initState();
    _customersFuture = api.getCustomers();
  }

  void _refresh() {
    setState(() {
      _customersFuture = api.getCustomers();
    });
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

  void _startEdit(Customer c) {
    setState(() {
      _editing = c;
      _nameController.text = c.name;
      _emailController.text = c.email;
      _phoneController.text = c.phone;
      _idNumberController.text = c.idNumber;
      _productController.text = c.product;
      _quantityController.text = c.quantity;
      _dateController.text = c.date;
      _timeController.text = c.time;
      _staffNameController.text = c.staffName;
      _direction = c.direction.isEmpty ? 'in' : c.direction;
      _error = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = null;
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _idNumberController.clear();
      _productController.clear();
      _quantityController.clear();
      _dateController.clear();
      _timeController.clear();
      _staffNameController.clear();
      _direction = 'in';
      _error = null;
    });
  }

  Future<void> _submit() async {
    final requiredFields = {
      'Client name': _nameController.text,
      'Email': _emailController.text,
      'Phone': _phoneController.text,
      'ID number': _idNumberController.text,
      'Product': _productController.text,
      'Quantity': _quantityController.text,
      'Staff member': _staffNameController.text,
    };
    final missing = requiredFields.entries
        .where((e) => e.value.trim().isEmpty)
        .map((e) => e.key)
        .toList();

    if (missing.isNotEmpty) {
      setState(() => _error = 'Missing: ${missing.join(', ')}');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_editing == null) {
        await api.addCustomer(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          idNumber: _idNumberController.text.trim(),
          product: _productController.text.trim(),
          quantity: _quantityController.text.trim(),
          direction: _direction,
          date: _dateController.text.trim(),
          time: _timeController.text.trim(),
          staffName: _staffNameController.text.trim(),
        );
      } else {
        await api.updateCustomer(
          id: _editing!.id,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          idNumber: _idNumberController.text.trim(),
          product: _productController.text.trim(),
          quantity: _quantityController.text.trim(),
          direction: _direction,
          date: _dateController.text.trim(),
          time: _timeController.text.trim(),
          staffName: _staffNameController.text.trim(),
        );
      }

      final wasEditing = _editing != null;
      _cancelEdit();
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasEditing ? 'Record updated' : 'Record added'),
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

  InputDecoration _decor(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      );

  Widget _buildForm() {
    final isEditing = _editing != null;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isEditing ? Colors.orange.shade200 : Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(isEditing ? Icons.edit_note : Icons.note_add_outlined,
                    color: isEditing ? Colors.orange.shade800 : Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(isEditing ? 'Edit Record' : 'New Record',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                if (isEditing) ...[
                  const Spacer(),
                  TextButton(onPressed: _cancelEdit, child: const Text('Cancel')),
                ],
              ],
            ),
            const SizedBox(height: 18),
            TextField(controller: _nameController, decoration: _decor('Client Name', Icons.person_outline)),
            const SizedBox(height: 12),
            TextField(controller: _emailController, decoration: _decor('Email', Icons.email_outlined)),
            const SizedBox(height: 12),
            TextField(controller: _phoneController, decoration: _decor('Phone Number', Icons.phone_outlined)),
            const SizedBox(height: 12),
            TextField(controller: _idNumberController, decoration: _decor('ID Number', Icons.badge_outlined)),
            const SizedBox(height: 12),
            TextField(controller: _productController, decoration: _decor('Product', Icons.inventory_2_outlined)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: _decor('Quantity', Icons.numbers),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'in', label: Text('In'), icon: Icon(Icons.arrow_downward, size: 16)),
                      ButtonSegment(value: 'out', label: Text('Out'), icon: Icon(Icons.arrow_upward, size: 16)),
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
                    decoration: _decor('Date', Icons.calendar_today_outlined)
                        .copyWith(suffixIcon: const Icon(Icons.arrow_drop_down)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _timeController,
                    readOnly: true,
                    onTap: _pickTime,
                    decoration: _decor('Time', Icons.access_time)
                        .copyWith(suffixIcon: const Icon(Icons.arrow_drop_down)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _staffNameController,
              decoration: _decor('Logged by (staff)', Icons.assignment_ind_outlined),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(isEditing ? Icons.save_outlined : Icons.add),
                label: Text(_saving ? 'Saving...' : (isEditing ? 'Update Record' : 'Add Record')),
                style: FilledButton.styleFrom(
                  backgroundColor: isEditing ? Colors.orange.shade700 : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// product -> net running total (positive = in stock, negative = over-withdrawn)
  Map<String, double> _computeStockTotals(List<Customer> customers) {
    final totals = <String, double>{};
    for (final c in customers) {
      final qty = double.tryParse(c.quantity) ?? 0;
      final signedQty = c.direction == 'out' ? -qty : qty;
      totals[c.product] = (totals[c.product] ?? 0) + signedQty;
    }
    return totals;
  }

  /// Balance of each product immediately after each record, processed in
  /// chronological order (oldest first) so the ledger reads top-to-bottom correctly.
  Map<String, double> _computeBalancesAfterEachRecord(List<Customer> chronological) {
    final running = <String, double>{};
    final balanceAfter = <String, double>{};
    for (final c in chronological) {
      final qty = double.tryParse(c.quantity) ?? 0;
      final signedQty = c.direction == 'out' ? -qty : qty;
      running[c.product] = (running[c.product] ?? 0) + signedQty;
      balanceAfter[c.id] = running[c.product]!;
    }
    return balanceAfter;
  }

  Widget _buildStockSummary(List<Customer> customers) {
    final totals = _computeStockTotals(customers);
    if (totals.isEmpty) return const SizedBox.shrink();

    final entries = totals.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      color: Colors.blue.shade50.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize_outlined, size: 18, color: Colors.blue.shade800),
                const SizedBox(width: 8),
                Text('Current Stock (In − Out)',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue.shade900)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entries.map((e) {
                final isNegative = e.value < 0;
                final displayQty = e.value == e.value.roundToDouble()
                    ? e.value.toInt().toString()
                    : e.value.toString();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      Text(
                        displayQty,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isNegative ? Colors.red.shade700 : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Records', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Customer>>(
          future: _customersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load records.\n${snapshot.error}',
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              );
            }
            final customers = snapshot.data ?? [];
            if (customers.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('No records yet', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStockSummary(customers),
                const SizedBox(height: 16),
                _buildRecordList(customers),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecordList(List<Customer> customers) {
    // getCustomers() returns newest first; compute chronological (oldest first)
    // balances, then display newest-first as before.
    final chronological = customers.reversed.toList();
    final balances = _computeBalancesAfterEachRecord(chronological);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: customers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final c = customers[index];
        final isOut = c.direction == 'out';
        final color = isOut ? Colors.red : Colors.green;
        final balance = balances[c.id];
        final balanceText = balance == null
            ? null
            : (balance == balance.roundToDouble() ? balance.toInt().toString() : balance.toString());

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
                            child: Text(c.name,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
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
                        '${c.product}  •  Qty: ${c.quantity}${balanceText != null ? '  •  Balance after: $balanceText' : ''}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${c.date.isEmpty ? 'No date' : c.date}${c.time.isNotEmpty ? ' ${c.time}' : ''}  •  Logged by ${c.staffName}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Text('${c.email}  •  ${c.phone}  •  ID: ${c.idNumber}',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _startEdit(c),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit record',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildForm()),
                    const SizedBox(width: 20),
                    Expanded(flex: 3, child: _buildList()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildForm(),
                    const SizedBox(height: 24),
                    _buildList(),
                  ],
                ),
        );
      },
    );
  }
}
