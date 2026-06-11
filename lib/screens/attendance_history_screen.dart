import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tap_attend/providers/attendance_provider.dart';
import 'package:tap_attend/models/class_session.dart';
import 'package:tap_attend/screens/session_detail_screen.dart';

class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final pastSessions = provider.pastSessions.reversed.toList(); // Newest first

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (pastSessions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              tooltip: 'Clear All History',
              onPressed: () => _confirmClearAll(context, provider),
            ),
        ],
      ),
      body: SafeArea(
        child: pastSessions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'No past sessions found.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: pastSessions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final session = pastSessions[index];
                  final attendanceRate = session.totalEnrolled > 0
                      ? (session.scannedStudents.length / session.totalEnrolled * 100).toStringAsFixed(1)
                      : '0.0';

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SessionDetailScreen(session: session),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: Theme.of(context).brightness == Brightness.light
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))]
                            : [],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.class_, color: Colors.blue),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${session.subjectCode} - ${session.subjectName}', 
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text('${session.startTime.day}/${session.startTime.month}/${session.startTime.year} • ${session.timeString}', 
                                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$attendanceRate%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: double.parse(attendanceRate) >= 50 ? Colors.green : Colors.red,
                                ),
                              ),
                              Text(
                                '${session.scannedStudents.length}/${session.totalEnrolled}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            tooltip: 'Delete Record',
                            onPressed: () {
                              _confirmDeleteSingle(context, provider, session);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _confirmDeleteSingle(BuildContext context, AttendanceProvider provider, ClassSession session) {
    final dateStr = '${session.startTime.day}/${session.startTime.month}/${session.startTime.year}';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text('Delete Session History?'),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete the attendance record for ${session.subjectName} on $dateStr?\n\nThis action cannot be undone and will delete the record permanently.',
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deletePastSession(session.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Session record deleted successfully'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, AttendanceProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gpp_maybe_outlined, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text('Clear All History?'),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently clear ALL past attendance session history from the app? This action is irreversible.',
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.clearAllPastSessions();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All attendance history cleared'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
