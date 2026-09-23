import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../api_service.dart';
import '../models.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int tabIndex)? onNavigateToTab;
  const DashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService api = ApiService();
  bool _loading = true;
  String? _error;

  List<Client> _clients = [];
  List<Product> _products = [];
  List<StoreRecord> _records = [];
  List<FumigationInvoice> _fumigationInvoices = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        api.getClients(),
        api.getProducts(),
        api.getRecords(),
        api.getFumigationInvoices(),
      ]);

      if (mounted) {
        setState(() {
          _clients = results[0] as List<Client>;
          _products = results[1] as List<Product>;
          _records = results[2] as List<StoreRecord>;
          _fumigationInvoices = results[3] as List<FumigationInvoice>;
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

  /// Calculates net stock per product
  Map<String, double> _computeProductStock() {
    final map = <String, double>{};
    for (final r in _records) {
      final name = r.productName.isEmpty ? 'Unknown Product' : r.productName;
      final val = r.direction == 'out' ? -r.quantity : r.quantity;
      map[name] = (map[name] ?? 0) + val;
    }
    return map;
  }

  double get _totalBagsInStock {
    final map = _computeProductStock();
    return map.values.fold(0.0, (prev, element) => prev + element);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 15)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final productStock = _computeProductStock();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dashboard Overview',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time grain stock management & quick actions',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
              IconButton(
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Data',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 550 ? 2 : 1);
              return GridView.count(
                crossAxisCount: crossCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 2.2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildKpiCard(
                    title: 'Total Stock (Bags)',
                    value: _totalBagsInStock.toInt().toString(),
                    icon: Icons.inventory_2_outlined,
                    color: Colors.blue.shade700,
                    bgColor: Colors.blue.shade50,
                  ),
                  _buildKpiCard(
                    title: 'Active Clients',
                    value: _clients.length.toString(),
                    icon: Icons.people_alt_outlined,
                    color: Colors.indigo.shade700,
                    bgColor: Colors.indigo.shade50,
                  ),
                  _buildKpiCard(
                    title: 'Grain Products',
                    value: _products.length.toString(),
                    icon: Icons.category_outlined,
                    color: Colors.teal.shade700,
                    bgColor: Colors.teal.shade50,
                  ),
                  _buildKpiCard(
                    title: 'Pending Fumigation',
                    value: _fumigationInvoices.where((i) => i.status == 'pending').length.toString(),
                    icon: Icons.description_outlined,
                    color: Colors.orange.shade800,
                    bgColor: Colors.orange.shade50,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Quick Tools Grid (Compact & Modern)
          const Text(
            'Quick Tools',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          _buildQuickToolsGrid(),
          const SizedBox(height: 24),

          // Charts & Analytics Section
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 850;
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildStockBarChartCard(productStock)),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: _buildRecentActivityCard()),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStockBarChartCard(productStock),
                        const SizedBox(height: 16),
                        _buildRecentActivityCard(),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact, sleek, modern Quick Tools Action Bar
  Widget _buildQuickToolsGrid() {
    final tools = [
      _QuickToolItem('Customers', Icons.person_add_outlined, Colors.indigo, 1),
      _QuickToolItem('Products', Icons.add_box_outlined, Colors.teal, 2),
      _QuickToolItem('Record Movement', Icons.swap_vert_outlined, Colors.blue, 3),
      _QuickToolItem('Fumigation Invoice', Icons.receipt_long_outlined, Colors.orange, 5),
      _QuickToolItem('Reports & Export', Icons.analytics_outlined, Colors.purple, 6),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 800 ? 5 : (constraints.maxWidth > 500 ? 3 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tools.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.5,
          ),
          itemBuilder: (context, index) {
            final tool = tools[index];
            return InkWell(
              onTap: () {
                if (widget.onNavigateToTab != null) {
                  widget.onNavigateToTab!(tool.tabIndex);
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tool.icon, size: 18, color: tool.color),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tool.label,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStockBarChartCard(Map<String, double> stockMap) {
    final entries = stockMap.entries.toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_outlined, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                const Text('Stock Balance per Grain Product',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 20),
            if (entries.isEmpty)
              Container(
                height: 180,
                alignment: Alignment.center,
                child: Text('No product records available', style: TextStyle(color: Colors.grey.shade500)),
              )
            else
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2).clamp(10, 10000),
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (val, meta) => Text(
                            val.toInt().toString(),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            final idx = val.toInt();
                            if (idx >= 0 && idx < entries.length) {
                              final name = entries[idx].key;
                              final shortName = name.length > 8 ? '${name.substring(0, 7)}..' : name;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(shortName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
                    borderData: FlBorderData(show: false),
                    barGroups: entries.asMap().entries.map((e) {
                      final stockValue = e.value.value;
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: stockValue < 0 ? 0 : stockValue,
                            color: const Color(0xFF1E3A8A),
                            width: 22,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    final recent = _records.take(5).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_outlined, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                const Text('Recent Store Transactions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 16),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text('No store records logged yet.', style: TextStyle(color: Colors.grey.shade500)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recent.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final r = recent[index];
                  final isOut = r.direction == 'out';
                  final color = isOut ? Colors.red.shade700 : Colors.green.shade700;

                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isOut ? Icons.arrow_upward : Icons.arrow_downward,
                          color: color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.clientName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text('${r.productName} • ${r.quantity} Bags', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text(r.date, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickToolItem {
  final String label;
  final IconData icon;
  final Color color;
  final int tabIndex;

  _QuickToolItem(this.label, this.icon, this.color, this.tabIndex);
}
