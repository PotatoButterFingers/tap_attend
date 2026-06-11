import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tap_attend/providers/attendance_provider.dart';
import 'package:tap_attend/models/student.dart';

enum RegistrationStep { scanning, unrecognizedPrompt, formEntry, alreadyRegistered, lecturerCard }

class CardRegistrationScreen extends StatefulWidget {
  const CardRegistrationScreen({super.key});

  @override
  State<CardRegistrationScreen> createState() => _CardRegistrationScreenState();
}

class _CardRegistrationScreenState extends State<CardRegistrationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  RegistrationStep _step = RegistrationStep.scanning;
  String _scannedUid = '';
  Student? _existingStudent;
  String? _existingClassCode;

  // Form Fields
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  String _selectedClassCode = 'CS101'; // Default

  bool _isScanningActive = false;

  static const MethodChannel _nfcChannel = MethodChannel('com.example.tap_attend/nfc');
  static const EventChannel _nfcEventChannel = EventChannel('com.example.tap_attend/nfc_events');
  StreamSubscription? _nfcSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _startNfcScan();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().checkServerConnection();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _nameController.dispose();
    _idController.dispose();
    _stopNfcScan();
    super.dispose();
  }

  Future<void> _startNfcScan() async {
    if (_isScanningActive) return;
    _isScanningActive = true;

    try {
      if (Platform.isAndroid) {
        await _nfcChannel.invokeMethod('startNfc');
        _nfcSubscription?.cancel();
        _nfcSubscription = _nfcEventChannel.receiveBroadcastStream().listen((dynamic uid) {
          if (uid is String) {
            _handleDiscoveredUid(uid);
          }
        });
      }
    } catch (_) {
      // Handle NFC error quietly
    }
  }

  void _stopNfcScan() {
    if (!_isScanningActive) return;
    _isScanningActive = false;
    _nfcSubscription?.cancel();
    if (Platform.isAndroid) {
      _nfcChannel.invokeMethod('stopNfc').catchError((_) {});
    }
  }

  String _normalizeUid(String uid) {
    return uid.trim().replaceAll(':', '').replaceAll(' ', '').replaceAll('-', '').toUpperCase();
  }

  void _handleDiscoveredUid(String uid) {
    _stopNfcScan();
    final provider = context.read<AttendanceProvider>();

    final normalizedScanned = _normalizeUid(uid);
    final lecturerCard = provider.lecturer?.cardUid;
    final nfcLoginCard = provider.nfcLoginCardUid;

    debugPrint("CardRegistrationScreen: Scanned UID: $normalizedScanned");
    debugPrint("CardRegistrationScreen: Lecturer Profile Card UID: ${lecturerCard != null ? _normalizeUid(lecturerCard) : null}");
    debugPrint("CardRegistrationScreen: Lecturer Login Card UID: $nfcLoginCard");

    final isLecturerCard = (lecturerCard != null && _normalizeUid(lecturerCard) == normalizedScanned) ||
                           (nfcLoginCard != null && _normalizeUid(nfcLoginCard) == normalizedScanned);

    if (isLecturerCard) {
      setState(() {
        _scannedUid = uid;
        _step = RegistrationStep.lecturerCard;
      });
      return;
    }

    final student = provider.checkCardRegistration(uid);

    setState(() {
      _scannedUid = uid;
      if (student != null) {
        _existingStudent = student;
        _existingClassCode = provider.customStudentSubjectCodes[student.id] ??
            _inferClassCodeFromStudentId(student.id);
        _step = RegistrationStep.alreadyRegistered;
      } else {
        _step = RegistrationStep.unrecognizedPrompt;
      }
    });
  }

  // Returns class code from student mock IDs (1XX -> CS101, 2XX -> CS202, 3XX -> CS303)
  String _inferClassCodeFromStudentId(String id) {
    if (id.startsWith('1')) return 'CS101';
    if (id.startsWith('2')) return 'CS202';
    if (id.startsWith('3')) return 'CS303';
    return 'CS101';
  }

  void _resetScanner() {
    setState(() {
      _step = RegistrationStep.scanning;
      _scannedUid = '';
      _existingStudent = null;
      _existingClassCode = null;
      _nameController.clear();
      _idController.clear();
      _selectedClassCode = 'CS101';
    });
    _startNfcScan();
  }

  void _handleRegister() {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<AttendanceProvider>();
      
      provider.registerNewStudent(
        id: _idController.text.trim(),
        name: _nameController.text.trim(),
        cardUid: _scannedUid,
        subjectCode: _selectedClassCode,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.isServerConnectionActive
                ? 'Registered ${_nameController.text} and synced to server!'
                : 'Registered locally. Will sync when online.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      _resetScanner();
    }
  }


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Registration', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Online/Offline status card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: (provider.isServerConnectionActive ? Colors.green : Colors.orange)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (provider.isServerConnectionActive ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      provider.isServerConnectionActive ? Icons.cloud_done : Icons.cloud_off,
                      color: provider.isServerConnectionActive ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      provider.isServerConnectionActive
                          ? 'Connected: Synced to XAMPP'
                          : 'Offline: Saving to Pending Queue',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: provider.isServerConnectionActive ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Build content based on current registration step
              _buildStepContent(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(bool isDark) {
    switch (_step) {
      case RegistrationStep.scanning:
        return _buildScanningWidget();
      case RegistrationStep.unrecognizedPrompt:
        return _buildUnrecognizedPromptWidget();
      case RegistrationStep.formEntry:
        return _buildFormEntryWidget();
      case RegistrationStep.alreadyRegistered:
        return _buildAlreadyRegisteredWidget();
      case RegistrationStep.lecturerCard:
        return _buildLecturerCardWidget();
    }
  }

  Widget _buildScanningWidget() {
    return Column(
      children: [
        const Text(
          'Place card near the back of your phone to scan',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 48),
        
        // Pulsing animation
        SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 110 + (_pulseController.value * 40),
                    height: 110 + (_pulseController.value * 40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1 - (_pulseController.value * 0.1)),
                    ),
                  );
                },
              ),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.nfc, color: Colors.white, size: 40),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildUnrecognizedPromptWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.help_outline, color: Colors.orange, size: 48),
          const SizedBox(height: 16),
          const Text(
            'New Card Detected',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'UID: $_scannedUid',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'monospace', color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          const Text(
            'This card is not registered to any student in the directory. Is this a new student card?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetScanner,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('No, Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _step = RegistrationStep.formEntry;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Yes, Register'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormEntryWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Register Student Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Card UID: $_scannedUid',
              style: const TextStyle(fontFamily: 'monospace', color: Colors.grey, fontSize: 12),
            ),
            const Divider(height: 32),
            
            Text('Student Name', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Enter student full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter student name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            Text('Student ID / Matrix Number', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _idController,
              decoration: const InputDecoration(
                hintText: 'e.g. 104, 204, 304',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              keyboardType: TextInputType.text,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter student ID';
                }
                // Check if ID is already registered
                final provider = context.read<AttendanceProvider>();
                if (provider.allStudentsInDirectory.any((s) => s.id == value.trim())) {
                  return 'This Student ID is already registered';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            Text('Class Enrollment', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedClassCode,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.school_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'CS101',
                  child: Text(
                    'CS101 - Computer Science 101',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'CS202',
                  child: Text(
                    'CS202 - Advanced Algorithms',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'CS303',
                  child: Text(
                    'CS303 - Data Structures',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedClassCode = value;
                  });
                }
              },
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetScanner,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleRegister,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Register'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlreadyRegisteredWidget() {
    final s = _existingStudent!;
    final classLabel = _existingClassCode == 'CS101'
        ? 'Computer Science 101'
        : _existingClassCode == 'CS202'
            ? 'Advanced Algorithms'
            : 'Data Structures';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 56),
          const SizedBox(height: 16),
          const Text(
            'Card Already Registered',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'UID: $_scannedUid',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'monospace', color: Colors.grey, fontSize: 12),
          ),
          const Divider(height: 32),
          
          ListTile(
            title: const Text('STUDENT NAME', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
            subtitle: Text(s.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            title: const Text('STUDENT ID', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
            subtitle: Text(s.id, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            title: const Text('ENROLLED CLASS', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
            subtitle: Text('$_existingClassCode - $classLabel', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _resetScanner,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Scan Another Card'),
          ),
        ],
      ),
    );
  }

  Widget _buildLecturerCardWidget() {
    final lecturer = context.read<AttendanceProvider>().lecturer!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.admin_panel_settings, color: Colors.blue, size: 56),
          const SizedBox(height: 16),
          const Text(
            'Lecturer Card Detected',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'UID: $_scannedUid',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'monospace', color: Colors.grey, fontSize: 12),
          ),
          const Divider(height: 32),
          
          ListTile(
            title: const Text('LECTURER NAME', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
            subtitle: Text(lecturer.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            title: const Text('DEPARTMENT', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
            subtitle: Text(lecturer.department, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),
          const Text(
            'This card is registered to you (the logged-in Lecturer) and cannot be assigned to a student.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orange, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _resetScanner,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Scan Another Card'),
          ),
        ],
      ),
    );
  }
}
