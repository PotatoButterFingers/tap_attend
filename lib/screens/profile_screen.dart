import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tap_attend/providers/attendance_provider.dart';
import 'package:tap_attend/screens/edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool isDark = brightness == Brightness.dark;
    
    final lecturer = context.watch<AttendanceProvider>().lecturer;
    final String name = lecturer?.name ?? 'Dr. Robert Smith';
    final String dept = lecturer?.department ?? 'Dept. of Computer Science';
    final String email = lecturer?.email ?? 'robert.smith@university.edu';
    final String phone = lecturer?.phone ?? '+1 (555) 123-4567';
    final String office = lecturer?.office ?? 'Engineering Bldg, Room 402';

    // Get initials for Avatar
    String initials = '';
    if (name.isNotEmpty) {
      final parts = name.split(' ');
      // Handle "Dr. Robert Smith" -> RS or R
      final filterParts = parts.where((p) => !p.toLowerCase().contains('dr') && !p.toLowerCase().contains('prof')).toList();
      if (filterParts.isNotEmpty) {
        initials = filterParts.map((e) => e[0]).take(2).join().toUpperCase();
      } else {
        initials = parts.map((e) => e[0]).take(2).join().toUpperCase();
      }
    }
    if (initials.isEmpty) initials = 'DR';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue,
                child: Text(
                  initials,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                dept,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark ? [] : [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.email, color: Colors.grey),
                      title: const Text('Email'),
                      subtitle: Text(email),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.phone, color: Colors.grey),
                      title: const Text('Phone'),
                      subtitle: Text(phone),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.location_on, color: Colors.grey),
                      title: const Text('Office'),
                      subtitle: Text(office),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Edit Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
