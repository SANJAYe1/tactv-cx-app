import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'sync_engine.dart';

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