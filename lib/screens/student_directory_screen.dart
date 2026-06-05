import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tap_attend/models/student.dart';
import 'package:tap_attend/providers/attendance_provider.dart';

class StudentDirectoryScreen extends StatefulWidget {
  const StudentDirectoryScreen({super.key});

  @override
  State<StudentDirectoryScreen> createState() => _StudentDirectoryScreenState();
}

class _StudentDirectoryScreenState extends State<StudentDirectoryScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    
    // Gather unique students across all sessions for a comprehensive list
    final Map<String, Student> uniqueStudents = {};
    if (provider.currentSession != null) {
      for (var s in provider.currentSession!.students) {
        uniqueStudents[s.id] = s;
      }
    }
    for (var session in provider.pastSessions) {
      for (var s in session.students) {
        uniqueStudents[s.id] = s;
      }
    }
    
    List<Student> displayStudents = uniqueStudents.values.toList();
    
    if (_searchQuery.isNotEmpty) {
      displayStudents = displayStudents.where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    
    // Sort alphabetically
    displayStudents.sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Directory'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name...',
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
            ),
            Expanded(
              child: displayStudents.isEmpty
                ? const Center(child: Text('No students found.'))
                : ListView.builder(
                    itemCount: displayStudents.length,
                    itemBuilder: (context, index) {
                      final student = displayStudents[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          child: Text(
                            student.name.substring(0, 1),
                            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('ID: ${student.id} | NFC Tag: ${student.deviceId}'),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
