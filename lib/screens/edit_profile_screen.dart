import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
  late TextEditingController _cardUidController;
  bool _isSaving = false;

  static const MethodChannel _nfcChannel = MethodChannel('com.example.tap_attend/nfc');
  static const EventChannel _nfcEventChannel = EventChannel('com.example.tap_attend/nfc_events');
  StreamSubscription? _nfcSubscription;
  bool _isScanningActive = false;

  Future<void> _startNfcSession() async {
    if (_isScanningActive) return;
    _isScanningActive = true;
    try {
      if (Platform.isAndroid) {
        await _nfcChannel.invokeMethod('startNfc');
        _nfcSubscription?.cancel();
        _nfcSubscription = _nfcEventChannel.receiveBroadcastStream().listen((dynamic uid) {
          if (uid is String) {
            _stopNfcSession();
            if (mounted) {
              setState(() {
                _cardUidController.text = uid;
              });
              Navigator.of(context, rootNavigator: true).pop(); // Dismiss dialog if open
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('NFC card scanned: $uid'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _stopNfcSession() async {
    if (!_isScanningActive) return;
    _isScanningActive = false;
    try {
      _nfcSubscription?.cancel();
      if (Platform.isAndroid) {
        await _nfcChannel.invokeMethod('stopNfc');
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    final lecturer = context.read<AttendanceProvider>().lecturer;
    _nameController = TextEditingController(text: lecturer?.name);
    _deptController = TextEditingController(text: lecturer?.department);
    _emailController = TextEditingController(text: lecturer?.email);
    _phoneController = TextEditingController(text: lecturer?.phone);
    _officeController = TextEditingController(text: lecturer?.office);
    _cardUidController = TextEditingController(text: lecturer?.cardUid);
  }

  @override
  void dispose() {
    _stopNfcSession();
    _nameController.dispose();
    _deptController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _officeController.dispose();
    _cardUidController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      final provider = context.read<AttendanceProvider>();
      final currentLecturer = provider.lecturer;
      if (currentLecturer != null) {
        final cardUidText = _cardUidController.text.trim();
        final updated = currentLecturer.copyWith(
          name: _nameController.text.trim(),
          department: _deptController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          office: _officeController.text.trim(),
          cardUid: cardUidText.isEmpty ? null : cardUidText,
        );

        final synced = await provider.updateLecturer(updated);

        if (mounted) {
          setState(() {
            _isSaving = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(synced 
                ? 'Profile updated and synced with database!' 
                : 'Profile updated locally (will sync when online).'),
              backgroundColor: synced ? Colors.green : Colors.orange,
            ),
          );
          Navigator.pop(context);
        }
      }
    }
  }

  void _showScanCardDialog() {
    String status = "Ready to Scan.\nHold your NFC card to the back of your phone.";
    
    _startNfcSession();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              _stopNfcSession();
            }
          },
          child: AlertDialog(
            title: const Text('Scan NFC Card'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.nfc, size: 64, color: Colors.blue),
                const SizedBox(height: 16),
                Text(
                  status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    _stopNfcSession();
                    Navigator.pop(context);
                    if (mounted) {
                      setState(() {
                        _cardUidController.text = 'lecturer_card_1';
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Simulated scan: lecturer_card_1'),
                          backgroundColor: Colors.amber,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Simulate Scan'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _stopNfcSession();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
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
                  enabled: !_isSaving,
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
                  enabled: !_isSaving,
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
                  enabled: !_isSaving,
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
                  enabled: !_isSaving,
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
                  enabled: !_isSaving,
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
                const SizedBox(height: 16),

                Text('NFC Card UID', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cardUidController,
                        enabled: false,
                        decoration: const InputDecoration(
                          hintText: 'No card registered. Tap "Scan" to register.',
                          prefixIcon: Icon(Icons.nfc),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_cardUidController.text.isNotEmpty) ...[
                      OutlinedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () {
                                setState(() {
                                  _cardUidController.clear();
                                });
                              },
                        icon: const Icon(Icons.clear, color: Colors.red),
                        label: const Text('Clear', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _showScanCardDialog,
                      icon: const Icon(Icons.sensors),
                      label: const Text('Scan'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
