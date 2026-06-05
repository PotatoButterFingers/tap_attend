import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tap_attend/providers/attendance_provider.dart';
import 'package:tap_attend/models/class_session.dart';
import 'package:tap_attend/models/student.dart';
import 'package:tap_attend/utils/export_utils.dart';

class SessionDetailScreen extends StatefulWidget {
  final ClassSession session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  String _searchQuery = '';
  String _filter = 'All'; // 'All', 'Present', 'Absent'

  void _confirmClearAll(BuildContext context, AttendanceProvider provider, String sessionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Clear All Attendance?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to clear all attendance records for this session?\n\nThis will mark all students as absent in the database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.clearAllSessionAttendance(sessionId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All student attendance cleared for this session'),
                  backgroundColor: Colors.redAccent,
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

  void _confirmRemoveIndividual(BuildContext context, AttendanceProvider provider, String sessionId, Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_remove_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text('Remove Attendance?'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove attendance for ${student.name}?\n\nThis will change their status to absent in the database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.removeStudentAttendance(sessionId, student.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed attendance for ${student.name}'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final session = provider.pastSessions.firstWhere(
      (s) => s.id == widget.session.id,
      orElse: () => widget.session,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final presentStudentIds = session.scannedStudents.map((s) => s.id).toSet();
    final totalStudents = session.students.length;
    final presentCount = session.scannedStudents.length;
    final absentCount = totalStudents - presentCount;
    final attendanceRate = totalStudents > 0
        ? (presentCount / totalStudents * 100).toStringAsFixed(1)
        : '0.0';

    // Build lists of present and absent student info
    List<Map<String, dynamic>> studentList = [];
    for (var student in session.students) {
      bool isPresent = presentStudentIds.contains(student.id);
      DateTime? scanTime;
      if (isPresent) {
        // Find scan time from scannedStudents list
        final scannedInfo = session.scannedStudents.firstWhere((s) => s.id == student.id);
        scanTime = scannedInfo.scanTime;
      }

      studentList.add({
        'student': student,
        'isPresent': isPresent,
        'scanTime': scanTime,
      });
    }

    // Apply Filter (All, Present, Absent)
    if (_filter == 'Present') {
      studentList = studentList.where((item) => item['isPresent'] == true).toList();
    } else if (_filter == 'Absent') {
      studentList = studentList.where((item) => item['isPresent'] == false).toList();
    }

    // Apply Search Query
    if (_searchQuery.isNotEmpty) {
      studentList = studentList.where((item) {
        final s = item['student'] as Student;
        return s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            s.id.contains(_searchQuery);
      }).toList();
    }

    // Sort: Present first (sorted by scan time if available), then Absent alphabetically
    studentList.sort((a, b) {
      final aPresent = a['isPresent'] as bool;
      final bPresent = b['isPresent'] as bool;
      if (aPresent && !bPresent) return -1;
      if (!aPresent && bPresent) return 1;
      
      // If both present, sort by scanTime (earliest first or latest first? Let's do earliest first)
      if (aPresent && bPresent) {
        final aTime = a['scanTime'] as DateTime?;
        final bTime = b['scanTime'] as DateTime?;
        if (aTime != null && bTime != null) {
          return aTime.compareTo(bTime);
        }
      }
      
      // Otherwise sort alphabetically by name
      final aStudent = a['student'] as Student;
      final bStudent = b['student'] as Student;
      return aStudent.name.compareTo(bStudent.name);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.blue),
            tooltip: 'Export CSV',
            onPressed: () async {
              await ExportUtils.exportSessionToCSV(session);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Attendance report generated successfully!')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            tooltip: 'Clear All Attendance',
            onPressed: presentCount == 0
                ? null
                : () => _confirmClearAll(context, provider, session.id),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Metadata Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isDark ? [] : [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            session.subjectCode,
                            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        Text(
                          '${session.startTime.day}/${session.startTime.month}/${session.startTime.year}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      session.subjectName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(session.room, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${session.startTime.hour.toString().padLeft(2, '0')}:${session.startTime.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Attendance', '$attendanceRate%', Colors.blue),
                        _buildStatItem('Present', '$presentCount', Colors.green),
                        _buildStatItem('Absent', '$absentCount', Colors.red),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Search Bar & Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name or ID...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _buildFilterChip('All', totalStudents),
                      const SizedBox(width: 8),
                      _buildFilterChip('Present', presentCount),
                      const SizedBox(width: 8),
                      _buildFilterChip('Absent', absentCount),
                    ],
                  ),
                ],
              ),
            ),

            // Students List
            Expanded(
              child: studentList.isEmpty
                  ? const Center(child: Text('No students found.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: studentList.length,
                      separatorBuilder: (context, index) => const Divider(height: 16),
                      itemBuilder: (context, index) {
                        final item = studentList[index];
                        final student = item['student'] as Student;
                        final isPresent = item['isPresent'] as bool;
                        final scanTime = item['scanTime'] as DateTime?;

                        String trailingText = 'Absent';
                        Color trailingColor = Colors.red;
                        if (isPresent) {
                          if (scanTime != null) {
                            final hourStr = scanTime.hour.toString().padLeft(2, '0');
                            final minStr = scanTime.minute.toString().padLeft(2, '0');
                            trailingText = '$hourStr:$minStr';
                          } else {
                            trailingText = 'Present';
                          }
                          trailingColor = Colors.green;
                        }

                        return Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: (isPresent ? Colors.green : Colors.red).withValues(alpha: 0.1),
                              child: Text(
                                student.name[0],
                                style: TextStyle(
                                  color: isPresent ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ID: ${student.id}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: trailingColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    trailingText,
                                    style: TextStyle(
                                      color: trailingColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (isPresent) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Remove attendance',
                                    onPressed: () => _confirmRemoveIndividual(context, provider, session.id, student),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _filter == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filter = label;
          });
        }
      },
      selectedColor: Colors.blue.withValues(alpha: 0.2),
      checkmarkColor: Colors.blue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : (isDark ? Colors.grey[400] : Colors.grey[700]),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.transparent,
          width: 1,
        ),
      ),
    );
  }
}
