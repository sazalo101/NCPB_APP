import 'package:flutter/material.dart';
import 'api_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/products_screen.dart';
import 'screens/records_screen.dart';
import 'screens/invoices_screen.dart';
import 'screens/fumigation_screen.dart';
import 'screens/reports_screen.dart';

void main() {
  runApp(const NcpbApp());
}

class NcpbApp extends StatelessWidget {
  const NcpbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NCPB Grain Store Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
          primary: const Color(0xFF1E3A8A),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0.5,
          scrolledUnderElevation: 0,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loggedIn = ApiService.token != null;

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) {
      return LoginScreen(onLoggedIn: () => setState(() => _loggedIn = true));
    }
    return HomeScreen(onLoggedOut: () => setState(() => _loggedIn = false));
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onLoggedOut;
  const HomeScreen({super.key, required this.onLoggedOut});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final ApiService _api = ApiService();

  void _onNavigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  Future<void> _logout() async {
    await _api.logout();
    widget.onLoggedOut();
  }

  final _titles = const [
    'Main Dashboard',
    'Customers Management',
    'Grain Products',
    'Store Records Ledger',
    'Standard Invoices',
    'Fumigation Invoices',
    'Reports & Exports',
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onNavigateToTab: _onNavigateToTab),
      const ClientsScreen(),
      const ProductsScreen(),
      const RecordsScreen(),
      const InvoicesScreen(),
      const FumigationScreen(),
      const ReportsScreen(),
    ];

    final navItems = const [
      _NavItem('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
      _NavItem('Customers', Icons.people_outline, Icons.people),
      _NavItem('Products', Icons.grain_outlined, Icons.grain),
      _NavItem('Store Records', Icons.swap_vert_outlined, Icons.swap_vert),
      _NavItem('Invoices', Icons.receipt_long_outlined, Icons.receipt_long),
      _NavItem('Fumigation', Icons.cleaning_services_outlined, Icons.cleaning_services),
      _NavItem('Reports', Icons.analytics_outlined, Icons.analytics),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 850;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warehouse_outlined, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text('NCPB Store — ${_titles[_currentIndex]}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Row(
                  children: [
                    Text(
                      'Staff: ${ApiService.loggedInUsername ?? 'admin'}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      tooltip: 'Log Out',
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: isWide
              ? Row(
                  children: [
                    // Smooth, modern custom sidebar with modern scrollbar
                    Container(
                      width: 230,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(right: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Scrollbar(
                        thumbVisibility: false,
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          itemCount: navItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final item = navItems[index];
                            final selected = _currentIndex == index;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              child: ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                tileColor: selected ? const Color(0xFF1E3A8A).withOpacity(0.08) : Colors.transparent,
                                leading: Icon(
                                  selected ? item.selectedIcon : item.icon,
                                  color: selected ? const Color(0xFF1E3A8A) : Colors.grey.shade600,
                                  size: 20,
                                ),
                                title: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                    color: selected ? const Color(0xFF1E3A8A) : Colors.grey.shade800,
                                    fontSize: 14,
                                  ),
                                ),
                                onTap: () => setState(() => _currentIndex = index),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Expanded(child: screens[_currentIndex]),
                  ],
                )
              : screens[_currentIndex],
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (i) => setState(() => _currentIndex = i),
                  destinations: navItems
                      .map((item) => NavigationDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.selectedIcon),
                            label: item.label,
                          ))
                      .toList(),
                ),
        );
      },
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavItem(this.label, this.icon, this.selectedIcon);
}
