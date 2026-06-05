import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
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
    
    try {
      NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          if (Platform.isAndroid) NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          // ignore: invalid_use_of_protected_member
          final Map<dynamic, dynamic> data = tag.data as Map<dynamic, dynamic>;
          List<dynamic>? identifier;

          // 1. Dynamic check: search all keys that contain a Map and have 'identifier'
          for (final value in data.values) {
            if (value is Map && value.containsKey('identifier')) {
              final id = value['identifier'];
              if (id is List) {
                identifier = id;
                break;
              }
            }
          }

          // 2. Explicit fallbacks
          if (identifier == null) {
            if (data.containsKey('nfca')) {
              identifier = (data['nfca'] as Map?)?['identifier'];
            } else if (data.containsKey('mifareclassic')) {
              identifier = (data['mifareclassic'] as Map?)?['identifier'];
            } else if (data.containsKey('mifareultralight')) {
              identifier = (data['mifareultralight'] as Map?)?['identifier'];
            } else if (data.containsKey('mifare')) {
              identifier = (data['mifare'] as Map?)?['identifier'];
            } else if (data.containsKey('nfcb')) {
              identifier = (data['nfcb'] as Map?)?['identifier'];
            } else if (data.containsKey('nfcv')) {
              identifier = (data['nfcv'] as Map?)?['identifier'];
            } else if (data.containsKey('nfcf')) {
              identifier = (data['nfcf'] as Map?)?['identifier'];
            } else if (data.containsKey('isodep')) {
              identifier = (data['isodep'] as Map?)?['identifier'];
            } else if (data.containsKey('ndef')) {
              identifier = (data['ndef'] as Map?)?['identifier'];
            }
          }

          String? scannedUid;
          if (identifier != null) {
            scannedUid = identifier
                .map((e) => (e as int).toRadixString(16).padLeft(2, '0').toUpperCase())
                .join(':');
          }

          if (scannedUid != null) {
            NfcManager.instance.stopSession();
            if (mounted) {
              setState(() {
                _cardUidController.text = scannedUid!;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('NFC card scanned: $scannedUid'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        },
      );
    } catch (_) {}

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
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
                  NfcManager.instance.stopSession();
                  Navigator.pop(context);
                  _cardUidController.text = 'lecturer_card_99';
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Simulated scan: lecturer_card_99'),
                      backgroundColor: Colors.amber,
                    ),
                  );
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
                NfcManager.instance.stopSession();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
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
