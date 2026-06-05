import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tap_attend/providers/attendance_provider.dart';
import 'package:tap_attend/screens/session_overview_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lecturerName = context.watch<AttendanceProvider>().lecturer?.name ?? 'Lecturer';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Profile
              Row(
                children: [
                  const CircleAvatar(
                    // User image placeholder
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text('Academic Portal', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.calendar_month), onPressed: () {}),
                ],
              ),
              const SizedBox(height: 24),
              
              // Greeting
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
                  children: [
                    const TextSpan(text: 'Good Morning, '),
                    TextSpan(text: lecturerName, style: TextStyle(color: Theme.of(context).primaryColor)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('Monday, October 23rd, 2023', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),

              // Stats Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.people, color: Colors.white),
                          SizedBox(height: 12),
                          Text('Total Students', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          SizedBox(height: 4),
                          Text('142', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.timer, color: Theme.of(context).primaryColor),
                          const SizedBox(height: 12),
                          Text('Teaching Hours', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '6.5h', 
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Schedule List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Today\'s Schedule', style: Theme.of(context).textTheme.titleLarge),
                  TextButton(onPressed: () {}, child: const Text('4 Classes')),
                ],
              ),
              const SizedBox(height: 16),

              // Schedule Items
              _buildScheduleCard(
                context,
                subject: 'Computer Science 101',
                time: '10:00 AM - 11:30 AM',
                location: 'Lab 3 • Engineering Building',
                tag: 'UPCOMING',
                onTap: () {
                  context.read<AttendanceProvider>().loadSessionByCode('CS101');
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionOverviewScreen()));
                },
              ),
              _buildScheduleCard(
                context,
                subject: 'Advanced Algorithms',
                time: '01:30 PM - 03:00 PM',
                location: 'Hall A • Main Building',
                tag: 'POSTGRADUATE',
                tagColor: Colors.orange,
                onTap: () {
                  context.read<AttendanceProvider>().loadSessionByCode('CS202');
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionOverviewScreen()));
                },
              ),
              _buildScheduleCard(
                context,
                subject: 'Data Structures',
                time: '03:15 PM - 04:45 PM',
                location: 'Lab 1 • Engineering Building',
                tag: 'UNDERGRADUATE',
                tagColor: Colors.purple,
                onTap: () {
                  context.read<AttendanceProvider>().loadSessionByCode('CS303');
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionOverviewScreen()));
                },
              ),
              _buildScheduleCard(
                context,
                subject: 'Faculty Meeting',
                time: '05:00 PM - 06:00 PM',
                location: 'Conference Room 4',
                tag: 'SEMINAR',
                tagColor: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(
    BuildContext context, {
    required String subject,
    required String time,
    required String location,
    required String tag,
    Color tagColor = Colors.blue,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: Theme.of(context).brightness == Brightness.light
             ? [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]
             : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tag, 
              style: TextStyle(color: tagColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(subject, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(time, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(location, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
