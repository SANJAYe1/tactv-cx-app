import 'package:supabase_flutter/supabase_flutter.dart';

import 'database_helper.dart';

class SyncEngine {
  static Future<void> syncData() async {
    final supabase = Supabase.instance.client;
    final dbHelper = DatabaseHelper.instance;

    try {
      // 1. PULL Customers from Cloud Database
      final cloudCustomers = await supabase.from('customers').select();
      for (var customer in cloudCustomers) {
        await dbHelper.upsertCustomer(customer);
      }

      // 2. PUSH Offline Cash Collections to Cloud Database
      final unsyncedPayments = await dbHelper.getUnsyncedPayments();
      for (var localPayment in unsyncedPayments) {
        var cloudPayload = Map<String, dynamic>.from(localPayment);
        cloudPayload.remove(
          'sync_status',
        ); // Remove local tracking column before sending

        await supabase.from('payments').upsert(cloudPayload);
        await dbHelper.markPaymentAsSynced(localPayment['id']);
      }
    } catch (e) {
      throw Exception('Sync failed. Check internet connection.: $e');
    }
  }
}
