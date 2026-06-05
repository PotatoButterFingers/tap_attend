import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tap_attend/providers/attendance_provider.dart';

class SyncQueueScreen extends StatefulWidget {
  const SyncQueueScreen({super.key});

  @override
  State<SyncQueueScreen> createState() => _SyncQueueScreenState();
}

class _SyncQueueScreenState extends State<SyncQueueScreen> {
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    // Test server connectivity as soon as the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().checkServerConnection();
    });
  }

  Future<void> _handleSyncNow(AttendanceProvider provider) async {
    setState(() {
      _isSyncing = true;
    });

    // Test connectivity first
    final isOnline = await provider.checkServerConnection();
    
    if (!isOnline) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot reach XAMPP server. Please start Apache/MySQL and verify the IP.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // Run sync execution
    await provider.syncAllPendingData();

    // Small delay to feel premium
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() {
        _isSyncing = false;
      });

      final totalPending = provider.pendingRegistrations.length +
          provider.pendingDeletions.length +
          provider.unsyncedSessionIds.length;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            totalPending == 0
                ? 'All pending records successfully uploaded to server!'
                : 'Synced some records. $totalPending items still pending.',
          ),
          backgroundColor: totalPending == 0 ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final int pendingRegsCount = provider.pendingRegistrations.length;
    final int pendingDelsCount = provider.pendingDeletions.length;
    final int pendingAttendanceCount = provider.unsyncedSessionIds.length;
    final int totalPending = pendingRegsCount + pendingDelsCount + pendingAttendanceCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Queue Status', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Server Connectivity Status Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isDark ? [] : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'XAMPP Server Status',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        // Connection Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: provider.isServerConnectionActive
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: provider.isServerConnectionActive ? Colors.green : Colors.red,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                provider.isServerConnectionActive ? 'ONLINE' : 'OFFLINE',
                                style: TextStyle(
                                  color: provider.isServerConnectionActive ? Colors.green : Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      provider.isServerConnectionActive
                          ? 'Connected to local XAMPP server at http://${provider.serverIp}. Scans and registrations sync instantly.'
                          : 'Cannot reach XAMPP server at http://${provider.serverIp}. Attendance data and registrations are safely queued locally and will sync when the server becomes online.',
                      style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
                    ),
                    const Divider(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _isSyncing 
                            ? null 
                            : () => provider.checkServerConnection(),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Test Connection & Auto-Sync', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                          foregroundColor: Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Sync Queue Actions Card
              if (totalPending > 0) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sync_problem, color: Colors.orange, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$totalPending Items Pending Sync',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Data is safely stored locally. Connect to the server to upload.',
                              style: TextStyle(fontSize: 11, color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: (provider.isServerConnectionActive && !_isSyncing)
                            ? () => _handleSyncNow(provider)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Sync Now', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // Queue Details
              if (totalPending == 0)
                _buildAllSyncedWidget()
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pending Sync Details', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    
                    if (pendingAttendanceCount > 0)
                      _buildPendingCategory(
                        title: 'PENDING ATTENDANCE REPORTS',
                        count: pendingAttendanceCount,
                        color: Colors.blue,
                        icon: Icons.history,
                        items: provider.unsyncedSessionIds.map((id) {
                          final sessionIdx = provider.pastSessions.indexWhere((s) => s.id == id);
                          final name = sessionIdx != -1
                              ? '${provider.pastSessions[sessionIdx].subjectCode}: ${provider.pastSessions[sessionIdx].scannedStudents.length} present'
                              : 'Session ID: $id';
                          return name;
                        }).toList(),
                      ),
                    
                    if (pendingRegsCount > 0)
                      _buildPendingCategory(
                        title: 'PENDING STUDENT REGISTRATIONS',
                        count: pendingRegsCount,
                        color: Colors.green,
                        icon: Icons.person_add,
                        items: provider.pendingRegistrations.map((reg) {
                          return '${reg['name']} (ID: ${reg['id']}) enrolled in ${reg['subjectCode']}';
                        }).toList(),
                      ),
                    
                    if (pendingDelsCount > 0)
                      _buildPendingCategory(
                        title: 'PENDING STUDENT DELETIONS',
                        count: pendingDelsCount,
                        color: Colors.red,
                        icon: Icons.person_remove,
                        items: provider.pendingDeletions.map((id) {
                          return 'Student ID: $id';
                        }).toList(),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllSyncedWidget() {
    return Column(
      children: [
        const SizedBox(height: 48),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cloud_done, color: Colors.green, size: 64),
        ),
        const SizedBox(height: 24),
        const Text(
          'All Systems Synced',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'All student registrations, student deletions, and class attendance logs are fully up-to-date with your local XAMPP server.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Back to Settings'),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingCategory({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required List<String> items,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '$count',
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 16),
            itemBuilder: (context, index) {
              return Text(
                items[index],
                style: const TextStyle(fontSize: 13, height: 1.4),
              );
            },
          ),
        ],
      ),
    );
  }
}
