import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:local_auth/local_auth.dart';

import 'database_helper.dart';
import 'sync_engine.dart';
import 'receipt_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://xsaownltgudcewjjdjhe.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhzYW93bmx0Z3VkY2V3ampkamhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkyMDI2MzEsImV4cCI6MjEwNDc3ODYzMX0.sfsK9Rqo9NQ2VHqzHxT0jab814Zp2HKpz2jKbfPk6dc',
  );
  // await DatabaseHelper.instance.initDb();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Check if user is already logged into Supabase
      home: Supabase.instance.client.auth.currentSession == null
          ? const CloudLoginScreen()
          : const AreaDashboardScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    try {
      final authenticated = await auth.authenticate(
        localizedReason: 'Unlock TACTV Field Manager to access offline data',
        persistAcrossBackgrounding: true,
      );
      if (authenticated) {
        setState(() => isAuthenticated = true);
      }
    } catch (e) {
      // Handle missing hardware or disabled security
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isAuthenticated) {
      return const DashboardScreen(); // Your existing dashboard UI
    }
    return Scaffold(
      body: Center(
        child: ElevatedButton.icon(
          onPressed: _authenticate,
          icon: const Icon(Icons.lock),
          label: const Text('Unlock with PIN/Biometrics'),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> customers = [];
  bool isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadLocalCustomers();
  }

  Future<void> _loadLocalCustomers() async {
    final data = await DatabaseHelper.instance.getLocalCustomers();
    setState(() {
      customers = data;
    });
  }

  Future<void> _runSync() async {
    setState(() => isSyncing = true);
    try {
      await SyncEngine.syncData();
      await _loadLocalCustomers();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
    }
    setState(() => isSyncing = false);
  }

  // NEW: Dialog to create a customer directly in the app
  void _showAddCustomerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Customer Name'),
            ),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final newCustomer = {
                  'id': const Uuid().v4(),
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'wallet_balance': 0.0,
                };

                // Save to local offline database
                await DatabaseHelper.instance.upsertCustomer(newCustomer);
                await _loadLocalCustomers(); // Refresh the screen

                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _collectCash(String customerId, String name, String phone) async {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Collect from $name'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (Rs)'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                await DatabaseHelper.instance.insertPaymentOffline({
                  'id': const Uuid().v4(),
                  'customer_id': customerId,
                  'amount': amount,
                  'collected_at': DateTime.now().toIso8601String(),
                  'sync_status': 'pending',
                });

                ReceiptService.sendWhatsAppReceipt(phone, name, amount);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save & Receipt'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TACTV Field Manager'),
        actions: [
          IconButton(
            icon: isSyncing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.sync),
            onPressed: isSyncing ? null : _runSync,
          ),
        ],
      ),
      body: customers.isEmpty
          ? const Center(child: Text('No customers yet. Tap + to add one.'))
          : ListView.builder(
              itemCount: customers.length,
              itemBuilder: (context, index) {
                final c = customers[index];
                return ListTile(
                  title: Text(c['name'] ?? 'Unnamed'),
                  subtitle: Text(c['phone'] ?? 'No phone'),
                  trailing: ElevatedButton(
                    onPressed: () => _collectCash(
                      c['id'].toString(),
                      c['name']?.toString() ?? 'Unnamed',
                      c['phone']?.toString() ?? 'No phone',
                    ),
                    child: const Text('Collect'),
                  ),
                );
              },
            ),
      // NEW: Floating action button to trigger the dialog
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomerDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CloudLoginScreen extends StatefulWidget {
  const CloudLoginScreen({super.key});

  @override
  State<CloudLoginScreen> createState() => _CloudLoginScreenState();
}

class _CloudLoginScreenState extends State<CloudLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // On success, trigger the initial first-time sync here
      // await SyncEngine.syncData();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          // MaterialPageRoute(builder: (context) => const BiometricLockScreen()),
          MaterialPageRoute(builder: (context) => const AreaDashboardScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Operator Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Operator Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    child: const Text('Login & Sync Initial Data'),
                  ),
          ],
        ),
      ),
    );
  }
}

// --- 2. DAILY OFFLINE BIOMETRIC UNLOCK ---
class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    try {
      final authenticated = await auth.authenticate(
        localizedReason: 'Unlock TACTV Field Manager',
        persistAcrossBackgrounding: true,
      );
      if (authenticated && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } catch (e) {
      // Handle missing hardware
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton.icon(
          onPressed: _authenticate,
          icon: const Icon(Icons.fingerprint),
          label: const Text('Tap to Unlock'),
        ),
      ),
    );
  }
}
