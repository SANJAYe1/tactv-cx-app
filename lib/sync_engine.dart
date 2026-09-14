import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

class SyncEngine {
  static Future<void> syncData() async {
    final supabase = Supabase.instance.client;
    final db = DatabaseHelper.instance;
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Get Watermark Timestamp
    String lastSync = prefs.getString('last_synced_at') ?? '1970-01-01T00:00:00.000Z';
    String currentSyncStart = DateTime.now().toIso8601String();

    try {
      // 2. PUSH Pending Local Data to Cloud
      final tablesToPush = ['customers', 'payments', 'service_tickets'];
      
      for (String table in tablesToPush) {
        final pendingRecords = await db.getUnsynced(table);
        for (var record in pendingRecords) {
          var cloudPayload = Map<String, dynamic>.from(record);
          cloudPayload.remove('sync_status'); 
          
          await supabase.from(table).upsert(cloudPayload);
          await db.markAsSynced(table, record['id']);
        }
      }

      // 3. PULL Updated Data from Cloud (Watermark logic)
      final updatedCustomers = await supabase
          .from('customers')
          .select()
          .gt('updated_at', lastSync);
          
      for (var c in updatedCustomers) {
        await db.upsertCloudData('customers', c, 'id');
      }

      // 4. Update Watermark on Success
      await prefs.setString('last_synced_at', currentSyncStart);

    } catch (e) {
      throw Exception('Sync failed: $e');
    }
  }
}