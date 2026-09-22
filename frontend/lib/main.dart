import 'package:flutter/material.dart';
import 'api_service.dart';
import 'screens/login_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/invoices_screen.dart';

void main() {
  runApp(const NcpbApp());
}

class NcpbApp extends StatelessWidget {
  const NcpbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NCPB Store Records',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
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
  bool _loggedIn = false;

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
  int _index = 0;
  final ApiService _api = ApiService();

  final _screens = const [
    CustomersScreen(),
    InvoicesScreen(),
  ];

  final _titles = const ['Store Records', 'Invoices'];

  Future<void> _logout() async {
    await _api.logout();
    widget.onLoggedOut();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        final destinations = const [
          NavigationRailDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: Text('Records')),
          NavigationRailDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: Text('Invoices')),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text('NCPB — ${_titles[_index]}'),
            actions: [
              IconButton(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                tooltip: 'Log out',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: isWide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: (i) => setState(() => _index = i),
                      labelType: NavigationRailLabelType.all,
                      destinations: destinations,
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: _screens[_index]),
                  ],
                )
              : _screens[_index],
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Records'),
                    NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Invoices'),
                  ],
                ),
        );
      },
    );
  }
}
