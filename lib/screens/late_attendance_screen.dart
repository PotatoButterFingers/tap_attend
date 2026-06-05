import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tap_attend/models/class_session.dart';
import 'package:tap_attend/providers/attendance_provider.dart';

class LateAttendanceScreen extends StatefulWidget {
  final ClassSession session;

  const LateAttendanceScreen({super.key, required this.session});

  @override
  State<LateAttendanceScreen> createState() => _LateAttendanceScreenState();
}

class _LateAttendanceScreenState extends State<LateAttendanceScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late String _sessionId;
  bool _showScanner = false;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.session.id;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // Stop NFC scanning if it was active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<AttendanceProvider>();
        if (provider.activeLateSessionId == _sessionId) {
          provider.stopNfcScanning();
          provider.activeLateSessionId = null;
        }
      }
    });
    super.dispose();
  }

  void _toggleScanner(AttendanceProvider provider) {
    setState(() {
      _showScanner = !_showScanner;
    });

    if (_showScanner) {
      provider.activeLateSessionId = _sessionId;
      provider.startNfcScanning();
      _pulseController.repeat();
    } else {
      provider.stopNfcScanning();
      provider.activeLateSessionId = null;
      _pulseController.stop();
    }
  }

  void _simulateScan(AttendanceProvider provider, String tagId) {
    if (provider.isScanning) {
      provider.simulateNfcScan(tagId);
      
      // Temporary haptic or visual alert
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Simulated Scan: $tagId'),
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
          width: 200,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Retrieve the latest copy of the session from provider to reflect changes instantly
    final sessionIdx = provider.pastSessions.indexWhere((s) => s.id == _sessionId);
    final session = sessionIdx != -1 ? provider.pastSessions[sessionIdx] : widget.session;

    final absentStudents = session.students.where(
      (s) => !session.scannedStudents.any((scanned) => scanned.id == s.id),
    ).toList();
    final presentStudents = session.scannedStudents;

    final double attendanceRate = session.totalEnrolled > 0
        ? (presentStudents.length / session.totalEnrolled) * 100
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Late Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Session Summary Header Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          session.subjectCode,
                          style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Room: ${session.room} • ${session.timeString.split(' ')[0]} ${session.timeString.split(' ')[1]} ${session.timeString.split(' ')[2]}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Attendance Rate', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(
                            '${attendanceRate.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              color: attendanceRate >= 50 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Roster Ratio', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(
                            '${presentStudents.length} present / ${session.totalEnrolled} total',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Pulsing Scan Area when scanner is open
            if (_showScanner) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
                ),
                child: Column(
                  children: [
                    Text(
                      provider.scanMessage ?? 'NFC Scanner Active',
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 110,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                width: 70 + (_pulseController.value * 30),
                                height: 70 + (_pulseController.value * 30),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blue.withValues(alpha: 0.15 - (_pulseController.value * 0.15)),
                                ),
                              );
                            },
                          ),
                          Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.nfc, color: Colors.white, size: 28),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'Hold card near the device back or click a test UID below:',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    // Quick simulation buttons for active scanner
                    Wrap(
                      spacing: 8,
                      children: absentStudents.map((student) {
                        return ActionChip(
                          avatar: const Icon(Icons.phone_android, size: 12, color: Colors.blue),
                          label: Text(student.name, style: const TextStyle(fontSize: 10)),
                          onPressed: () => _simulateScan(provider, student.deviceId),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Scanner Activation Action Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _toggleScanner(provider),
                  icon: Icon(_showScanner ? Icons.stop : Icons.nfc),
                  label: Text(_showScanner ? 'Stop NFC Scanner' : 'Scan NFC Card for Late Attendance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showScanner ? Colors.red : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Students List
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      indicatorColor: Theme.of(context).primaryColor,
                      labelColor: Theme.of(context).textTheme.titleLarge?.color,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: [
                        Tab(text: 'ABSENT STUDENTS (${absentStudents.length})'),
                        Tab(text: 'PRESENT STUDENTS (${presentStudents.length})'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab 1: Absent Students
                          absentStudents.isEmpty
                              ? const Center(child: Text('All students are present!', style: TextStyle(color: Colors.grey)))
                              : ListView.separated(
                                  padding: const EdgeInsets.all(24),
                                  itemCount: absentStudents.length,
                                  separatorBuilder: (context, index) => const Divider(height: 20),
                                  itemBuilder: (context, index) {
                                    final student = absentStudents[index];
                                    return Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                                          child: Text(student.name[0], style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(student.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              Text('ID: ${student.id} • Card: ${student.deviceId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                          tooltip: 'Mark Present',
                                          onPressed: () {
                                            provider.markStudentPresentInPastSession(session.id, student.id);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Marked ${student.name} as present retrospectively')),
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),

                          // Tab 2: Present Students
                          presentStudents.isEmpty
                              ? const Center(child: Text('No students present yet.', style: TextStyle(color: Colors.grey)))
                              : ListView.separated(
                                  padding: const EdgeInsets.all(24),
                                  itemCount: presentStudents.length,
                                  separatorBuilder: (context, index) => const Divider(height: 20),
                                  itemBuilder: (context, index) {
                                    final student = presentStudents[index];
                                    return Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Colors.green.withValues(alpha: 0.1),
                                          child: Text(student.name[0], style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(student.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              Text('ID: ${student.id} • Card: ${student.deviceId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                        const Text('Recorded', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                      ],
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
