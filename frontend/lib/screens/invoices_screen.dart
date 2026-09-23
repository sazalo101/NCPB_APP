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
  late Future<List<Client>> _clientsFuture;

  Client? _selectedClient;
  final _amountController = TextEditingController();
  final _dueDateController = TextEditingController();
  PlatformFile? _pickedFile;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _invoicesFuture = api.getInvoices();
      _clientsFuture = api.getClients();
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
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Future<void> _uploadInvoice() async {
    if (_selectedClient == null) {
      setState(() => _error = 'Select a client');
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
        clientId: _selectedClient!.id,
        amount: _amountController.text.trim(),
        dueDate: _dueDateController.text.trim(),
        fileBytes: _pickedFile!.bytes!,
        fileName: _pickedFile!.name,
      );

      _amountController.clear();
      _dueDateController.clear();
      setState(() {
        _pickedFile = null;
        _selectedClient = null;
      });
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Standard invoice uploaded'), backgroundColor: Colors.green),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                Icon(Icons.upload_file_outlined, color: const Color(0xFF1E3A8A)),
                const SizedBox(width: 8),
                const Text('Upload Standard Invoice', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Client>>(
              future: _clientsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final clients = snapshot.data!;
                if (clients.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('No registered clients yet — add one on the Customers tab first.'),
                  );
                }
                return DropdownButtonFormField<Client>(
                  decoration: _decor('Client', Icons.person_outline),
                  initialValue: _selectedClient,
                  isExpanded: true,
                  items: clients
                      .map((c) => DropdownMenuItem(value: c, child: Text('${c.name} (${c.id})', overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedClient = value),
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: _decor('Amount (KES)', Icons.attach_money),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dueDateController,
              readOnly: true,
              onTap: _pickDueDate,
              decoration: _decor('Due Date', Icons.calendar_today_outlined).copyWith(suffixIcon: const Icon(Icons.arrow_drop_down)),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _pickedFile != null ? const Color(0xFF1E3A8A) : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  color: _pickedFile != null ? Colors.blue.shade50 : null,
                ),
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined,
                        color: _pickedFile != null ? const Color(0xFF1E3A8A) : Colors.grey.shade500),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _pickedFile?.name ?? 'Tap to choose a PDF invoice file',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _pickedFile != null ? const Color(0xFF1E3A8A) : Colors.grey.shade600,
                          fontWeight: _pickedFile != null ? FontWeight.bold : FontWeight.normal,
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
                label: Text(_uploading ? 'Uploading...' : 'Upload Invoice PDF'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
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
            const Text('Uploaded Invoices', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
                      Text('No uploaded invoices yet.', style: TextStyle(color: Colors.grey.shade600)),
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
                final statusColor = isPending ? Colors.orange.shade800 : Colors.green.shade800;
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
                          child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF1E3A8A)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(inv.clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text('Amount: KES ${inv.amount}${inv.dueDate.isNotEmpty ? '  •  Due: ${inv.dueDate}' : ''}',
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
                          tooltip: 'View PDF Invoice',
                        ),
                        const SizedBox(width: 4),
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
        final isWide = constraints.maxWidth > 850;
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
