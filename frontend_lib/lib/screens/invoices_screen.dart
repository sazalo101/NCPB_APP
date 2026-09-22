import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_service.dart';
import '../models.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final ApiService api = ApiService();
  late Future<List<Invoice>> _invoicesFuture;
  late Future<List<Customer>> _customersFuture;

  Customer? _selectedCustomer;
  final _amountController = TextEditingController();
  final _dueDateController = TextEditingController();
  PlatformFile? _pickedFile;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _invoicesFuture = api.getInvoices();
    _customersFuture = api.getCustomers();
  }

  void _refresh() {
    setState(() {
      _invoicesFuture = api.getInvoices();
      _customersFuture = api.getCustomers();
    });
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      _dueDateController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, // required so bytes are available on Web too
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Future<void> _uploadInvoice() async {
    if (_selectedCustomer == null) {
      setState(() => _error = 'Select a customer');
      return;
    }
    if (_amountController.text.trim().isEmpty) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    if (_pickedFile == null || _pickedFile!.bytes == null) {
      setState(() => _error = 'Choose a PDF file');
      return;
    }

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      await api.addInvoice(
        customerId: _selectedCustomer!.id,
        amount: _amountController.text.trim(),
        dueDate: _dueDateController.text.trim(),
        fileBytes: _pickedFile!.bytes!,
        fileName: _pickedFile!.name,
      );

      _amountController.clear();
      _dueDateController.clear();
      setState(() {
        _pickedFile = null;
        _selectedCustomer = null;
      });
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice uploaded'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploading = false);
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
                Icon(Icons.upload_file_outlined, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text('Upload Invoice', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 18),
            FutureBuilder<List<Customer>>(
              future: _customersFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final customers = snapshot.data!;
                if (customers.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('No customers yet — add one on the Records tab first.'),
                  );
                }
                return DropdownButtonFormField<Customer>(
                  decoration: _decor('Customer', Icons.person_outline),
                  value: _selectedCustomer,
                  isExpanded: true,
                  items: customers
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.name, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedCustomer = value),
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: _decor('Amount', Icons.attach_money),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dueDateController,
              readOnly: true,
              onTap: _pickDueDate,
              decoration: _decor('Due Date', Icons.calendar_today_outlined)
                  .copyWith(suffixIcon: const Icon(Icons.arrow_drop_down)),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _pickedFile != null ? Colors.blue.shade200 : Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  color: _pickedFile != null ? Colors.blue.shade50 : null,
                ),
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined,
                        color: _pickedFile != null ? Colors.blue.shade700 : Colors.grey.shade500),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _pickedFile?.name ?? 'Tap to choose a PDF invoice',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _pickedFile != null ? Colors.blue.shade900 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                onPressed: _uploading ? null : _uploadInvoice,
                icon: _uploading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload),
                label: Text(_uploading ? 'Uploading...' : 'Upload Invoice'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
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
            const Text('Invoices', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Invoice>>(
          future: _invoicesFuture,
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
                child: Text('Could not load invoices.\n${snapshot.error}',
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              );
            }
            final invoices = snapshot.data ?? [];
            if (invoices.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('No invoices yet', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: invoices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final inv = invoices[index];
                final isPending = inv.status == 'pending';
                final statusColor = isPending ? Colors.orange : Colors.green;
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.picture_as_pdf_outlined, color: Colors.blue.shade700),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(inv.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('Amount: ${inv.amount}${inv.dueDate.isNotEmpty ? '  •  Due: ${inv.dueDate}' : ''}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final url = Uri.parse(api.invoiceFileUrl(inv.fileName));
                            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Could not open invoice file')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.open_in_new, size: 20),
                          tooltip: 'View invoice',
                        ),
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
                      ],
                    ),
                  ),
                );
              },
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
