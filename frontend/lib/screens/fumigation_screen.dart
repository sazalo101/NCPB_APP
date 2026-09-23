import 'package:flutter/material.dart';
import '../api_service.dart';
import '../models.dart';

class FumigationScreen extends StatefulWidget {
  const FumigationScreen({super.key});

  @override
  State<FumigationScreen> createState() => _FumigationScreenState();
}

class _FumigationScreenState extends State<FumigationScreen> {
  final ApiService api = ApiService();

  List<Client> _clients = [];
  List<StoreRecord> _records = [];
  List<FumigationInvoice> _invoices = [];

  bool _loading = true;
  String? _error;

  Client? _selectedClient;
  String _selectedQuarter = 'Q1 2026';
  final _pricePerBagController = TextEditingController(text: '15.0');
  final _dueDateController = TextEditingController();
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final clients = await api.getClients();
      final records = await api.getRecords();
      final invoices = await api.getFumigationInvoices();

      if (mounted) {
        setState(() {
          _clients = clients;
          _records = records;
          _invoices = invoices;
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

  /// Calculates net stored bags for a specific client
  double _calculateCustomerStoredBags(String clientId) {
    double total = 0.0;
    for (final r in _records.where((rec) => rec.clientId == clientId)) {
      if (r.direction == 'in') {
        total += r.quantity;
      } else if (r.direction == 'out') {
        total -= r.quantity;
      }
    }
    return total < 0 ? 0.0 : total;
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      _dueDateController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _generateInvoice() async {
    if (_selectedClient == null) {
      setState(() => _error = 'Please select a Client');
      return;
    }

    final rate = double.tryParse(_pricePerBagController.text.trim());
    if (rate == null || rate < 0) {
      setState(() => _error = 'Please enter a valid price per bag');
      return;
    }

    final bags = _calculateCustomerStoredBags(_selectedClient!.id);
    if (bags <= 0) {
      setState(() => _error = 'Selected client has 0 stored bags in warehouse. Cannot issue fumigation invoice.');
      return;
    }

    if (_dueDateController.text.isEmpty) {
      final defaultDue = DateTime.now().add(const Duration(days: 30));
      _dueDateController.text = '${defaultDue.year}-${defaultDue.month.toString().padLeft(2, '0')}-${defaultDue.day.toString().padLeft(2, '0')}';
    }

    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      final inv = await api.addFumigationInvoice(
        clientId: _selectedClient!.id,
        clientName: _selectedClient!.name,
        quarter: _selectedQuarter,
        bagsCount: bags,
        pricePerBag: rate,
        dueDate: _dueDateController.text.trim(),
      );

      _loadData();
      if (mounted) {
        _showInvoiceReceiptModal(inv);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _showInvoiceReceiptModal(FumigationInvoice inv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long_outlined, color: Color(0xFF1E3A8A)),
            const SizedBox(width: 10),
            Text('Fumigation Invoice (${inv.id})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Container(
          width: 450,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('NATIONAL CEREALS AND PRODUCE BOARD',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
              const Text('Quarterly Grain Fumigation Assessment Receipt',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const Divider(height: 24),
              _receiptRow('Invoice ID:', inv.id),
              _receiptRow('Client Name:', inv.clientName),
              _receiptRow('Quarter Period:', inv.quarter),
              _receiptRow('Stored Bags Balance:', '${inv.bagsCount.toInt()} Bags'),
              _receiptRow('Rate per Bag:', 'KES ${inv.pricePerBag}'),
              const Divider(height: 20),
              _receiptRow('Total Amount Due:', 'KES ${inv.totalAmount.toStringAsFixed(2)}', isBold: true),
              _receiptRow('Payment Due Date:', inv.dueDate),
              _receiptRow('Status:', inv.status.toUpperCase(), isStatus: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invoice sent to print queue'), backgroundColor: Colors.green),
              );
            },
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print Receipt'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool isBold = false, bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold || isStatus ? FontWeight.bold : FontWeight.w500,
              color: isStatus
                  ? (value == 'PAID' ? Colors.green.shade800 : Colors.orange.shade800)
                  : (isBold ? const Color(0xFF1E3A8A) : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decor(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _buildForm() {
    final storedBags = _selectedClient == null ? 0.0 : _calculateCustomerStoredBags(_selectedClient!.id);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.cleaning_services_outlined, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                const Text('Generate Fumigation Invoice', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),

            // Select Client
            DropdownButtonFormField<Client>(
              decoration: _decor('Select Client', Icons.person_search_outlined),
              initialValue: _selectedClient,
              isExpanded: true,
              items: _clients
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.name} (${c.id})', overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (c) => setState(() => _selectedClient = c),
            ),
            const SizedBox(height: 12),

            if (_selectedClient != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Current Stored Stock:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('${storedBags.toInt()} Bags',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.orange.shade900)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Select Quarter
            DropdownButtonFormField<String>(
              decoration: _decor('Quarter Period', Icons.date_range_outlined),
              initialValue: _selectedQuarter,
              items: const [
                DropdownMenuItem(value: 'Q1 2026', child: Text('Q1 2026 (Jan - Mar)')),
                DropdownMenuItem(value: 'Q2 2026', child: Text('Q2 2026 (Apr - Jun)')),
                DropdownMenuItem(value: 'Q3 2026', child: Text('Q3 2026 (Jul - Sep)')),
                DropdownMenuItem(value: 'Q4 2026', child: Text('Q4 2026 (Oct - Dec)')),
              ],
              onChanged: (q) => setState(() => _selectedQuarter = q ?? 'Q1 2026'),
            ),
            const SizedBox(height: 12),

            // Price per bag (Editable)
            TextField(
              controller: _pricePerBagController,
              keyboardType: TextInputType.number,
              decoration: _decor('Price Per Bag (KES) *Editable*', Icons.attach_money),
            ),
            const SizedBox(height: 12),

            // Due date
            TextField(
              controller: _dueDateController,
              readOnly: true,
              onTap: _pickDueDate,
              decoration: _decor('Due Date', Icons.calendar_today_outlined).copyWith(suffixIcon: const Icon(Icons.arrow_drop_down)),
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
                onPressed: _generating ? null : _generateInvoice,
                icon: _generating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.receipt_long),
                label: Text(_generating ? 'Calculating...' : 'Issue Fumigation Invoice'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Fumigation Invoices History', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 8),
        _loading
            ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            : _invoices.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.description_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('No fumigation invoices issued yet.', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _invoices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final inv = _invoices[index];
                      final isPending = inv.status == 'pending';
                      final statusColor = isPending ? Colors.orange.shade800 : Colors.green.shade800;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.receipt, color: Colors.orange.shade900),
                          ),
                          title: Row(
                            children: [
                              Text(inv.clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Text('(${inv.quarter})', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Bags: ${inv.bagsCount.toInt()}  •  Rate: KES ${inv.pricePerBag}/bag  •  Total: KES ${inv.totalAmount.toStringAsFixed(2)}\nDue Date: ${inv.dueDate}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  inv.status.toUpperCase(),
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                onPressed: () => _showInvoiceReceiptModal(inv),
                                icon: const Icon(Icons.visibility_outlined, size: 20),
                                tooltip: 'View Receipt',
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
                    Expanded(flex: 3, child: _buildInvoiceList()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildForm(),
                    const SizedBox(height: 24),
                    _buildInvoiceList(),
                  ],
                ),
        );
      },
    );
  }
}
