import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tap_attend/providers/attendance_provider.dart';
import 'package:tap_attend/utils/export_utils.dart';

class NfcScanScreen extends StatefulWidget {
  const NfcScanScreen({super.key});

  @override
  State<NfcScanScreen> createState() => _NfcScanScreenState();
}

class _NfcScanScreenState extends State<NfcScanScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: false);
    
    // Start NFC Scanning when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().startNfcScanning();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final session = provider.currentSession;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (session == null) {
      return const Scaffold(body: Center(child: Text("Error: No Active Session")));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(onPressed: () {
          provider.stopNfcScanning();
          Navigator.pop(context);
        }),
        title: const Text('NFC Attendance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        actions: const [
          Icon(Icons.info_outline, color: Colors.blue),
          SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            '${session.subjectCode} - ${session.room}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(session.subjectName, style: Theme.of(context).textTheme.bodyMedium),
          
          const SizedBox(height: 16),
          
          // Pulsing NFC Icon (Slightly smaller to prevent overflow)
          SizedBox(
            height: 160, // Fixed height to prevent layout shifts
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 120 + (_pulseController.value * 30),
                      height: 120 + (_pulseController.value * 30),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1 - (_pulseController.value * 0.1)),
                      ),
                    );
                  },
                ),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 95 + (_pulseController.value * 15),
                      height: 95 + (_pulseController.value * 15),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.2 - (_pulseController.value * 0.2)),
                      ),
                    );
                  },
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.wifi_tethering, color: Colors.white, size: 36),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          Text(
            provider.scanMessage ?? 'Waiting...',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Hold student\'s ID card or mobile device near the back of your phone',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // List Bottom Sheet Area
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(top: 24, left: 24, right: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: isDark ? [] : [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Scan Status', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
                      Text(
                        '${session.scannedStudents.length} / ${session.totalEnrolled} Students',
                        style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (session.scannedStudents.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('LAST STUDENT SCANNED', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Expanded(
                    child: ListView.separated(
                      itemCount: session.scannedStudents.length,
                      separatorBuilder: (context, index) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final student = session.scannedStudents[index];
                        final isLast = index == 0; // Top is last scanned

                        return Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue.withValues(alpha: 0.1),
                              child: Text(student.name[0], style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(student.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: isLast ? FontWeight.bold : FontWeight.normal)),
                                  if (isLast)
                                    Row(
                                      children: [
                                        Text(student.id, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.circle, size: 4, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        const Text('Verified', style: TextStyle(fontSize: 12, color: Colors.green)),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            if (isLast)
                              const Icon(Icons.check_circle, color: Colors.green)
                            else 
                              const Text('Just now', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            provider.stopNfcScanning();
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('End Session?'),
                                content: const Text('Do you want to export the attendance list before ending?'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context); // Close dialog
                                      provider.finishSession();
                                      Navigator.pop(context); // Close scan screen
                                    },
                                    child: const Text('Just End'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(context); // Close dialog
                                      await ExportUtils.exportSessionToCSV(session);
                                      provider.finishSession();
                                      if (context.mounted) {
                                        Navigator.pop(context); // Close scan screen
                                      }
                                    },
                                    child: const Text('Export & End'),
                                  ),
                                ],
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.withValues(alpha: 0.1),
                            foregroundColor: Colors.blue,
                            elevation: 0,
                          ),
                          child: const Text('Finish Session'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton.icon(
                        onPressed: () {
                          // Manual Override
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                            builder: (context) {
                              final absentStudents = session.students.where(
                                (s) => !session.scannedStudents.any((scanned) => scanned.id == s.id)
                              ).toList();
                              
                              return Container(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Text('Manual Attendance', style: Theme.of(context).textTheme.titleLarge),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: absentStudents.isEmpty 
                                      ? const Center(child: Text("All students present!"))
                                      : ListView.builder(
                                        itemCount: absentStudents.length,
                                        itemBuilder: (context, index) {
                                          final s = absentStudents[index];
                                          return ListTile(
                                            title: Text(s.name),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                              onPressed: () {
                                                context.read<AttendanceProvider>().manuallyMarkPresent(s.id);
                                                Navigator.pop(context); // Close sheet to re-evaluate or keep it open. Let's pop for simplicity.
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Manually recorded ${s.name}')));
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Manual'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
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
