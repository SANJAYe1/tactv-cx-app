import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

class SyncEngine {
  static Future<void> syncData() async {
    final supabase = Supabase.instance.client;
    final db = DatabaseHelper.instance;
    final prefs = await SharedPreferences.getInstance();
    
    String lastSync = prefs.getString('last_synced_at') ?? '1970-01-01T00:00:00.000Z';
    String currentSyncStart = DateTime.now().toIso8601String();

    try {
      // 1. PUSH Pending Local Data to Cloud
      final pushTables = {'customers': 'id', 'stbs': 'box_id', 'payments': 'id'};
      
      for (var entry in pushTables.entries) {
        String table = entry.key;
        String pkCol = entry.value;
        final pendingRecords = await db.getUnsynced(table);
        
        for (var record in pendingRecords) {
          var cloudPayload = Map<String, dynamic>.from(record);
          cloudPayload.remove('sync_status'); 
          
          await supabase.from(table).upsert(cloudPayload);
          await db.markAsSynced(table, pkCol, record[pkCol].toString());
        }
      }

      // 2. PULL Updated Data from Cloud (Watermark logic)
      final pullTables = {
        'areas': 'id',
        'packages': 'id',
        'customers': 'id',
        'stbs': 'box_id',
        'payments': 'id'
      };

      for (var entry in pullTables.entries) {
        String table = entry.key;
        String pkCol = entry.value;
        
        final updatedCloudData = await supabase
            .from(table)
            .select()
            .gt('updated_at', lastSync);
            
        for (var row in updatedCloudData) {
          await db.upsertCloudData(table, row, pkCol);
        }
      }

      // 3. Update Watermark on Success
      await prefs.setString('last_synced_at', currentSyncStart);

    } catch (e) {
      throw Exception('Sync failed: $e');
    }
  }
}