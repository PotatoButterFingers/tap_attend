import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tap_attend/providers/attendance_provider.dart';
import 'package:tap_attend/screens/session_overview_screen.dart';
import 'package:tap_attend/screens/card_registration_screen.dart';
import 'package:tap_attend/screens/late_attendance_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _selectedDate = DateTime(2023, 10, 23); // Simulated "today" date
  final DateTime _mockToday = DateTime(2023, 10, 23);

  String _formatDisplayDate(DateTime date) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    final day = date.day;
    
    String suffix = 'th';
    if (day == 1 || day == 21 || day == 31) {
      suffix = 'st';
    } else if (day == 2 || day == 22) {
      suffix = 'nd';
    } else if (day == 3 || day == 23) {
      suffix = 'rd';
    }
    
    return '$weekday, $month $day$suffix, ${date.year}';
  }

  void _handleClassTap(BuildContext context, String subjectCode, String subjectName) {
    final provider = context.read<AttendanceProvider>();
    
    final selectedDateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final mockTodayOnly = DateTime(_mockToday.year, _mockToday.month, _mockToday.day);
    
    if (selectedDateOnly.isBefore(mockTodayOnly)) {
      // Past session: Retrieve or create, and open late attendance screen
      final session = provider.getOrCreatePastSession(subjectCode, _selectedDate);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LateAttendanceScreen(session: session),
        ),
      );
    } else if (selectedDateOnly.isAfter(mockTodayOnly)) {
      // Future session: warn user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot record attendance for a future class date.'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      // Today (Oct 23, 2023): Active recording flow
      provider.loadSessionByCode(subjectCode);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SessionOverviewScreen()),
      );
    }
  }

  Widget _buildDynamicScheduleCard(
    BuildContext context, {
    required String subjectCode,
    required String subject,
    required String time,
    required String location,
  }) {
    final provider = context.watch<AttendanceProvider>();
    
    final selectedDateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final mockTodayOnly = DateTime(_mockToday.year, _mockToday.month, _mockToday.day);
    
    String tag;
    Color tagColor;
    
    if (selectedDateOnly.isBefore(mockTodayOnly)) {
      final existingIdx = provider.pastSessions.indexWhere((s) => 
        s.subjectCode == subjectCode &&
        s.startTime.year == _selectedDate.year &&
        s.startTime.month == _selectedDate.month &&
        s.startTime.day == _selectedDate.day
      );
      if (existingIdx != -1) {
        final session = provider.pastSessions[existingIdx];
        tag = 'RECORDED (${session.scannedStudents.length}/${session.totalEnrolled})';
        tagColor = Colors.green;
      } else {
        tag = 'NO RECORD';
        tagColor = Colors.redAccent;
      }
    } else if (selectedDateOnly.isAfter(mockTodayOnly)) {
      tag = 'FUTURE SESSION';
      tagColor = Colors.grey;
    } else {
      tag = 'TODAY - LIVE';
      tagColor = Colors.blue;
    }
    
    return _buildScheduleCard(
      context,
      subject: subject,
      time: time,
      location: location,
      tag: tag,
      tagColor: tagColor,
      onTap: () => _handleClassTap(context, subjectCode, subject),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lecturerName = context.watch<AttendanceProvider>().lecturer?.name ?? 'Lecturer';
    final isWeekend = _selectedDate.weekday == DateTime.saturday || _selectedDate.weekday == DateTime.sunday;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bool isShowingToday = _selectedDate.year == _mockToday.year &&
        _selectedDate.month == _mockToday.month &&
        _selectedDate.day == _mockToday.day;

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
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text('Academic Portal', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.nfc, color: Colors.blue),
                    tooltip: 'Card Registration',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CardRegistrationScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.calendar_month),
                    tooltip: 'Select Date',
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2022),
                        lastDate: DateTime(2028),
                      );
                      if (picked != null && picked != _selectedDate) {
                        setState(() {
                          _selectedDate = picked;
                        });
                      }
                    },
                  ),
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
              
              // Dynamic Date Display
              Row(
                children: [
                  Text(_formatDisplayDate(_selectedDate), style: Theme.of(context).textTheme.bodyMedium),
                  if (!isShowingToday) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = _mockToday;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Reset to Today',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor, 
                            fontSize: 10, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
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
                  Text(
                    isShowingToday ? "Today's Schedule" : "Schedule for Selected Date",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (!isWeekend)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '3 Classes',
                        style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Schedule Items
              if (isWeekend) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
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
                    children: [
                      Icon(Icons.weekend_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'No Classes Scheduled',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enjoy your weekend! Teaching sessions are only scheduled from Monday to Friday.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _buildDynamicScheduleCard(
                  context,
                  subjectCode: 'CS101',
                  subject: 'Computer Science 101',
                  time: '10:00 AM - 11:30 AM',
                  location: 'Lab 3 • Engineering Building',
                ),
                _buildDynamicScheduleCard(
                  context,
                  subjectCode: 'CS202',
                  subject: 'Advanced Algorithms',
                  time: '01:30 PM - 03:00 PM',
                  location: 'Hall A • Main Building',
                ),
                _buildDynamicScheduleCard(
                  context,
                  subjectCode: 'CS303',
                  subject: 'Data Structures',
                  time: '03:15 PM - 04:45 PM',
                  location: 'Lab 1 • Engineering Building',
                ),
              ],
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
                Expanded(
                  child: Text(
                    subject, 
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
