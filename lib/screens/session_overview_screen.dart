import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tap_attend/providers/attendance_provider.dart';
import 'package:tap_attend/screens/nfc_scan_screen.dart';

class SessionOverviewScreen extends StatelessWidget {
  const SessionOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AttendanceProvider>().currentSession;

    if (session == null) {
      return const Scaffold(body: Center(child: Text("Loading...")));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school, color: Colors.blue),
            SizedBox(width: 8),
            Text('TapAttend Pro', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
        actions: const [
          CircleAvatar(
            backgroundColor: Colors.blueAccent,
            radius: 14,
            child: Icon(Icons.person, size: 16, color: Colors.white),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('LIVE SESSION', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${session.subjectCode}: Session 14',
               style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
               textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              session.subjectName,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Session Information Card
            Text('Session Information', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _buildInfoRow(context, Icons.book, 'SUBJECT', '${session.subjectCode} - ${session.subjectName}'),
                  const Divider(height: 32),
                  _buildInfoRow(context, Icons.access_time, 'TIME', session.timeString),
                  const Divider(height: 32),
                  _buildInfoRow(context, Icons.location_on_outlined, 'ROOM', session.room),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const NfcScanScreen()));
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Attendance Recording', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Once started, place student NFC cards against the back of this device to record attendance. All data is stored locally and synced automatically.',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Bottom Stats
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        Text('Enrolled Students', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                        const SizedBox(height: 8),
                        Text('${session.totalEnrolled}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        Text('Previous Average', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                        const SizedBox(height: 8),
                        Text('${session.previousAverageScore}%', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Theme.of(context).primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
