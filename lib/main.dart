import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'database_helper.dart';
import 'sync_engine.dart';
import 'receipt_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Connect to your Supabase Project
  await Supabase.initialize(
    url: 'https://xsaownltgudcewjjdjhe.supabase.co',
    anonKey: 'PASTE_YOUR_ANON_PUBLIC_KEY_HERE',
  );

  await DatabaseHelper.instance.initDb();
  runApp(
    const MaterialApp(
      home: DashboardScreen(),
      debugShowCheckedModeBanner: false,
    ),
  );
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
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Sync Complete!')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    }
    setState(() => isSyncing = false);
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
                // 1. Save payment offline immediately
                await DatabaseHelper.instance.insertPaymentOffline({
                  'id': Uuid().v4(),
                  'customer_id': customerId,
                  'amount': amount,
                  'collected_at': DateTime.now().toIso8601String(),
                  'sync_status': 'pending',
                });

                // 2. Open WhatsApp Receipt
                ReceiptService.sendWhatsAppReceipt(phone, name, amount);
                if (mounted) Navigator.pop(context);
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
      body: ListView.builder(
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final c = customers[index];
          return ListTile(
            title: Text(c['name']),
            subtitle: Text(c['phone']),
            trailing: ElevatedButton(
              onPressed: () => _collectCash(c['id'], c['name'], c['phone']),
              child: const Text('Collect'),
            ),
          );
        },
      ),
    );
  }
}
