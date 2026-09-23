import 'package:flutter/material.dart';
import '../api_service.dart';
import '../models.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ApiService api = ApiService();
  late Future<List<Product>> _productsFuture;

  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _unitController = TextEditingController(text: 'Bag 90kg');
  final _priceController = TextEditingController(text: '15.0');
  final _descController = TextEditingController();

  Product? _editingProduct;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _productsFuture = api.getProducts();
    });
  }

  void _startEdit(Product p) {
    setState(() {
      _editingProduct = p;
      _idController.text = p.id;
      _nameController.text = p.name;
      _unitController.text = p.unit;
      _priceController.text = p.defaultPricePerBag.toString();
      _descController.text = p.description;
      _error = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingProduct = null;
      _idController.clear();
      _nameController.clear();
      _unitController.text = 'Bag 90kg';
      _priceController.text = '15.0';
      _descController.clear();
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Product Name is required');
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price < 0) {
      setState(() => _error = 'Please enter a valid default fumigation price');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_editingProduct == null) {
        await api.addProduct(
          id: _idController.text.trim(),
          name: _nameController.text.trim(),
          unit: _unitController.text.trim(),
          defaultPricePerBag: price,
          description: _descController.text.trim(),
        );
      } else {
        await api.updateProduct(
          id: _editingProduct!.id,
          name: _nameController.text.trim(),
          unit: _unitController.text.trim(),
          defaultPricePerBag: price,
          description: _descController.text.trim(),
        );
      }

      final wasEditing = _editingProduct != null;
      _cancelEdit();
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasEditing ? 'Product updated successfully' : 'Product added successfully'),
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

  Future<void> _deleteProduct(Product p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete product "${p.name}" (${p.id})?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await api.deleteProduct(p.id);
        _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted'), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
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
    final isEditing = _editingProduct != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isEditing ? Colors.teal.shade400 : Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(isEditing ? Icons.edit_note : Icons.add_box_outlined,
                    color: isEditing ? Colors.teal.shade900 : const Color(0xFF1E3A8A)),
                const SizedBox(width: 8),
                Text(isEditing ? 'Edit Product' : 'Add New Grain Product',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                if (isEditing) ...[
                  const Spacer(),
                  TextButton(onPressed: _cancelEdit, child: const Text('Cancel')),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (!isEditing) ...[
              TextField(
                controller: _idController,
                decoration: _decor('Product ID (Optional, e.g. PRD-101)', Icons.qr_code),
              ),
              const SizedBox(height: 12),
            ],
            TextField(controller: _nameController, decoration: _decor('Product Name (e.g. White Maize) *', Icons.grain)),
            const SizedBox(height: 12),
            TextField(controller: _unitController, decoration: _decor('Packaging Unit (e.g. Bag 90kg)', Icons.all_inbox_outlined)),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: _decor('Default Fumigation Price/Bag (KES)', Icons.attach_money),
            ),
            const SizedBox(height: 12),
            TextField(controller: _descController, decoration: _decor('Description / Notes', Icons.notes_outlined)),
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
                label: Text(_saving ? 'Saving...' : (isEditing ? 'Update Product' : 'Save Product')),
                style: FilledButton.styleFrom(
                  backgroundColor: isEditing ? Colors.teal.shade900 : const Color(0xFF1E3A8A),
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
            const Text('Registered Grain Products', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Product>>(
          future: _productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load products.\n${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              );
            }

            final products = snapshot.data ?? [];
            if (products.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('No products added yet.', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = products[index];
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
                      decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.grain, color: Colors.teal.shade800),
                    ),
                    title: Row(
                      children: [
                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Text(p.id, style: TextStyle(color: Colors.teal.shade900, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('Unit: ${p.unit}  •  Default Rate: KES ${p.defaultPricePerBag}/bag${p.description.isNotEmpty ? '  •  ${p.description}' : ''}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _startEdit(p),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Edit Product',
                        ),
                        IconButton(
                          onPressed: () => _deleteProduct(p),
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          tooltip: 'Delete Product',
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
