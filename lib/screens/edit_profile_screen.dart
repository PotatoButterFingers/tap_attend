import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tap_attend/models/lecturer.dart';
import 'package:tap_attend/providers/attendance_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _deptController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _officeController;

  @override
  void initState() {
    super.initState();
    final lecturer = context.read<AttendanceProvider>().lecturer;
    _nameController = TextEditingController(text: lecturer?.name);
    _deptController = TextEditingController(text: lecturer?.department);
    _emailController = TextEditingController(text: lecturer?.email);
    _phoneController = TextEditingController(text: lecturer?.phone);
    _officeController = TextEditingController(text: lecturer?.office);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _deptController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _officeController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      final updated = Lecturer(
        name: _nameController.text.trim(),
        department: _deptController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        office: _officeController.text.trim(),
      );
      context.read<AttendanceProvider>().updateLecturer(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Full Name', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Dr. Robert Smith',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                Text('Department', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _deptController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Dept. of Computer Science',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your department';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                Text('Email Address', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. robert.smith@university.edu',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                Text('Phone Number', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. +1 (555) 123-4567',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                Text('Office Location', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _officeController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Engineering Bldg, Room 402',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your office location';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                
                ElevatedButton(
                  onPressed: _handleSave,
                  child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
