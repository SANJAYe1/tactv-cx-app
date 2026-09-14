import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'database_helper.dart';

// --- MODULE A: Area/Village Dashboard ---
class AreaDashboardScreen extends StatefulWidget {
  const AreaDashboardScreen({super.key});

  @override
  State<AreaDashboardScreen> createState() => _AreaDashboardScreenState();
}

class _AreaDashboardScreenState extends State<AreaDashboardScreen> {
  List<Map<String, dynamic>> areas = [];
  bool isSyncing = false; // Add this
  
  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    final data = await DatabaseHelper.instance.getAreas();
    setState(() => areas = data);
  }

  // Add this method
  Future<void> _runSync() async {
    setState(() => isSyncing = true);
    try {
      await SyncEngine.syncData();
      await _loadAreas(); // Refresh UI
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync Complete!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    setState(() => isSyncing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Operating Areas'),
        actions: [
          // Add the sync button here
          IconButton(
            icon: isSyncing ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.sync),
            onPressed: isSyncing ? null : _runSync,
          )
        ],
    ),
      body: ListView.builder(
        itemCount: areas.length,
        itemBuilder: (context, index) {
          final area = areas[index];
          return ListTile(
            leading: const Icon(Icons.location_on),
            title: Text(area['name']?.toString() ?? 'Unknown Area'),
            subtitle: Text('${area['customer_count']} Active Customers'),
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
          );
        },
      ),
    );
  }
}

// --- MODULE B: Customer Roster by Area ---
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