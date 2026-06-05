import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:tap_attend/providers/attendance_provider.dart';
import 'package:tap_attend/models/student.dart';

enum RegistrationStep { scanning, unrecognizedPrompt, formEntry, alreadyRegistered }

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

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _startNfcScan();
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
      bool isAvailable =
          await NfcManager.instance.checkAvailability() ==
          NfcAvailability.enabled;
      if (!isAvailable) {
        // Fallback: Show simulation scanner
        return;
      }

      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          final uid = _extractUid(tag);
          if (uid != null) {
            _handleDiscoveredUid(uid);
          }
        },
      );
    } catch (_) {
      // Handle NFC error quietly
    }
  }

  void _stopNfcScan() {
    if (!_isScanningActive) return;
    _isScanningActive = false;
    NfcManager.instance.stopSession();
  }

  String? _extractUid(NfcTag tag) {
    // ignore: invalid_use_of_protected_member
    final Map<dynamic, dynamic> data = tag.data as Map<dynamic, dynamic>;
    List<dynamic>? identifier;

    if (data.containsKey('nfca')) {
      identifier = (data['nfca'] as Map?)?['identifier'];
    } else if (data.containsKey('mifareultralight')) {
      identifier = (data['mifareultralight'] as Map?)?['identifier'];
    } else if (data.containsKey('nfcb')) {
      identifier = (data['nfcb'] as Map?)?['identifier'];
    } else if (data.containsKey('nfcv')) {
      identifier = (data['nfcv'] as Map?)?['identifier'];
    } else if (data.containsKey('nfcf')) {
      identifier = (data['nfcf'] as Map?)?['identifier'];
    } else if (data.containsKey('isodep')) {
      identifier = (data['isodep'] as Map?)?['identifier'];
    }

    if (identifier != null) {
      return identifier
          .map((e) => (e as int).toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(':');
    }
    return null;
  }

  void _handleDiscoveredUid(String uid) {
    _stopNfcScan();
    final provider = context.read<AttendanceProvider>();
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
            provider.isServerOnline
                ? 'Registered ${_nameController.text} and synced to server!'
                : 'Registered locally. Will sync when online.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      _resetScanner();
    }
  }

  // Simulate NFC scan for emulator testing
  void _simulateScan(String mockUid) {
    _handleDiscoveredUid(mockUid);
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
                  color: (provider.isServerOnline ? Colors.green : Colors.orange)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (provider.isServerOnline ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      provider.isServerOnline ? Icons.cloud_done : Icons.cloud_off,
                      color: provider.isServerOnline ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      provider.isServerOnline
                          ? 'Connected: Synced to XAMPP'
                          : 'Offline: Saving to Pending Queue',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: provider.isServerOnline ? Colors.green : Colors.orange,
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

        // Simulator button for testing
        OutlinedButton.icon(
          onPressed: () {
            // Generate a random UID for testing (or a fixed tag index)
            final randomId = 'MOCK:${DateTime.now().millisecond}';
            _simulateScan(randomId);
          },
          icon: const Icon(Icons.developer_mode),
          label: const Text('Simulate Tag Scan (Emulator)'),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            // Simulate scanning an already registered card (tag_1)
            _simulateScan('tag_1');
          },
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Simulate Scan: Existing Student'),
        ),
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
              keyboardType: TextInputType.number,
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
              initialValue: _selectedClassCode,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.school_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'CS101', child: Text('CS101 - Computer Science 101')),
                DropdownMenuItem(value: 'CS202', child: Text('CS202 - Advanced Algorithms')),
                DropdownMenuItem(value: 'CS303', child: Text('CS303 - Data Structures')),
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
}
