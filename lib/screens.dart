import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'sync_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<ScaffoldState> rootScaffoldKey = GlobalKey<ScaffoldState>();

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  // The operational modules assigned to the sidebar
  final List<Widget> _screens = [
    const DashboardStatsScreen(),     // 0: Landing
    const AreaDashboardScreen(),      // 1: Areas (Already built)
    const Center(child: Text('Global Users List Coming Soon')), // 2: Users
    const Center(child: Text('Hardware Inventory Coming Soon')), // 3: STBs
    const Center(child: Text('Payment Ledger Coming Soon')),     // 4: Payments
    const ProfileSecurityScreen(),    // 5: Profile & Security
    const Center(child: Text('About TACTV Field App v1.0.0')),   // 6: About
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    Navigator.pop(context); // Close the drawer automatically
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: rootScaffoldKey, // <-- ADD THIS LINE
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              accountName: Text('Operator Name'),
              accountEmail: Text('operator1@tactv.com'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.blue),
              ),
              decoration: BoxDecoration(color: Colors.blue),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard & Stats'),
              selected: _selectedIndex == 0,
              onTap: () => _onItemTapped(0),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Areas & Villages'),
              selected: _selectedIndex == 1,
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('All Customers'),
              selected: _selectedIndex == 2,
              onTap: () => _onItemTapped(2),
            ),
            ListTile(
              leading: const Icon(Icons.router),
              title: const Text('STB Inventory'),
              selected: _selectedIndex == 3,
              onTap: () => _onItemTapped(3),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Payment History'),
              selected: _selectedIndex == 4,
              onTap: () => _onItemTapped(4),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Profile & Security'),
              selected: _selectedIndex == 5,
              onTap: () => _onItemTapped(5),
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About'),
              selected: _selectedIndex == 6,
              onTap: () => _onItemTapped(6),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MODULE A: Area/Village Dashboard ---
class AreaDashboardScreen extends StatefulWidget {
  const AreaDashboardScreen({super.key});

  @override
  State<AreaDashboardScreen> createState() => _AreaDashboardScreenState();
}

class _AreaDashboardScreenState extends State<AreaDashboardScreen> {
  List<Map<String, dynamic>> areas = [];
  bool isSyncing = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    try {
      final data = await DatabaseHelper.instance.getAreas();
      if (mounted) setState(() => areas = data);
    } catch (e) {
      if (mounted) setState(() => errorMessage = 'DB Load Error: $e');
    }
  }

  Future<void> _runSync() async {
    setState(() {
      isSyncing = true;
      errorMessage = ''; // Clear old errors
    });
    
    try {
      await SyncEngine.syncData();
      await _loadAreas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync Complete!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) setState(() => errorMessage = 'Sync Error: $e');
    } finally {
      if (mounted) setState(() => isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operating Areas'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: isSyncing 
                ? const Center(
                    child: SizedBox(
                      width: 20, height: 20, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    )
                  )
                : IconButton(
                    icon: const Icon(Icons.sync),
                    onPressed: _runSync,
                  ),
          )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(errorMessage, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    if (areas.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No areas found.', style: TextStyle(fontSize: 18, color: Colors.grey)),
            Text('Tap the sync button to download data.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: areas.length,
      itemBuilder: (context, index) {
        final area = areas[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.location_on, color: Colors.blue),
            title: Text(area['name']?.toString() ?? 'Unknown Area', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${area['customer_count'] ?? 0} Active Customers'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerListScreen(
                    areaId: area['id'].toString(),
                    areaName: area['name'].toString(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// --- DEFAULT LANDING: Dashboard Stats ---
class DashboardStatsScreen extends StatelessWidget {
  const DashboardStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Overview'),
       leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
        ),),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Collections', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              color: Colors.green.shade50,
              child: const ListTile(
                leading: Icon(Icons.currency_rupee, color: Colors.green, size: 40),
                title: Text('Rs. 0.00', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                subtitle: Text('Collected Today'),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Operations Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildStatCard('Active STBs', '0', Icons.router, Colors.blue)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Pending Dues', 'Rs. 0', Icons.warning, Colors.orange)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// --- PROFILE & SECURITY MODULE ---
class ProfileSecurityScreen extends StatefulWidget {
  const ProfileSecurityScreen({super.key});

  @override
  State<ProfileSecurityScreen> createState() => _ProfileSecurityScreenState();
}

class _ProfileSecurityScreenState extends State<ProfileSecurityScreen> {
  bool _useFingerprint = false;
  bool _usePin = false;

  @override
  void initState() {
    super.initState();
    _loadSecurityPreferences();
  }

  Future<void> _loadSecurityPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useFingerprint = prefs.getBool('use_fingerprint') ?? false;
      _usePin = prefs.getBool('use_pin') ?? false;
    });
  }

  Future<void> _togglePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    _loadSecurityPreferences();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Security'), leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
        ),),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.person, size: 50),
            title: Text('Operator Name', style: TextStyle(fontSize: 20)),
            subtitle: Text('operator1@tactv.com\nEmp ID: TACTV-909'),
            isThreeLine: true,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Offline Security Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          SwitchListTile(
            title: const Text('Enable Fingerprint/Face Unlock'),
            subtitle: const Text('Require biometrics when opening app'),
            value: _useFingerprint,
            onChanged: (val) => _togglePreference('use_fingerprint', val),
          ),
          SwitchListTile(
            title: const Text('Enable PIN Lock'),
            subtitle: const Text('Require 4-digit PIN when opening app'),
            value: _usePin,
            onChanged: (val) => _togglePreference('use_pin', val),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('Change Cloud Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset link sent.')));
            },
          ),
        ],
      ),
    );
  }
}
class CustomerListScreen extends StatefulWidget {
  final String areaId;
  final String areaName;
  const CustomerListScreen({super.key, required this.areaId, required this.areaName});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  List<Map<String, dynamic>> customers = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final data = await DatabaseHelper.instance.getCustomersByArea(widget.areaId);
    setState(() => customers = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Customers: ${widget.areaName}')),
      body: ListView.builder(
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final c = customers[index];
          final double due = (c['total_monthly_due'] as num?)?.toDouble() ?? 0.0;
          final double wallet = (c['wallet_balance'] as num?)?.toDouble() ?? 0.0;
          final double pending = due - wallet;

          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(c['name']?.toString() ?? 'Unknown'),
            subtitle: Text('Pending: Rs. ${pending > 0 ? pending : 0}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: c)),
              ).then((_) => _loadCustomers()); // Refresh on return
            },
          );
        },
      ),
    );
  }
}

// --- MODULE C: Asset & Payment Management ---
class CustomerDetailScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  List<Map<String, dynamic>> stbs = [];

  @override
  void initState() {
    super.initState();
    _loadSTBs();
  }

  Future<void> _loadSTBs() async {
    final data = await DatabaseHelper.instance.getCustomerSTBs(widget.customer['id'].toString());
    setState(() => stbs = data);
  }

  void _processPayment() async {
    // Scaffold UI for payment collection
    // Includes local insert into 'payments' and updating 'wallet_balance' in 'customers'
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.customer['name'].toString())),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Phone: ${widget.customer['phone']}', style: const TextStyle(fontSize: 16)),
                ElevatedButton.icon(
                  onPressed: _processPayment,
                  icon: const Icon(Icons.payment),
                  label: const Text('Collect Cash'),
                ),
              ],
            ),
          ),
          const Divider(),
          const Text('Assigned STBs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Expanded(
            child: ListView.builder(
              itemCount: stbs.length,
              itemBuilder: (context, index) {
                final box = stbs[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text('Box ID: ${box['box_id']}'),
                    subtitle: Text('Package: ${box['package_name']} (Rs. ${box['monthly_price']})'),
                    trailing: Chip(label: Text(box['status'].toString().toUpperCase())),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}