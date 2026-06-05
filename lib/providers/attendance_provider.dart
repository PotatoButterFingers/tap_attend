import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_attend/models/class_session.dart';
import 'package:tap_attend/models/student.dart';
import 'package:tap_attend/models/lecturer.dart';

class AttendanceProvider with ChangeNotifier {
  // Mock Data
  ClassSession? currentSession;
  List<ClassSession> pastSessions = [];
  bool isScanning = false;
  String? scanMessage;
  Student? lastScannedStudent;
  Lecturer? lecturer = Lecturer(
    name: 'Dr. Robert Smith',
    department: 'Dept. of Computer Science',
    email: 'robert.smith@university.edu',
    phone: '+1 (555) 123-4567',
    office: 'Engineering Bldg, Room 402',
  );

  AttendanceProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load lecturer profile
    final lecturerJson = prefs.getString('lecturer');
    if (lecturerJson != null) {
      lecturer = Lecturer.fromJson(jsonDecode(lecturerJson));
    }

    // Load past sessions
    final pastSessionsJson = prefs.getStringList('pastSessions');
    if (pastSessionsJson != null) {
      pastSessions = pastSessionsJson
          .map((e) => ClassSession.fromJson(jsonDecode(e)))
          .toList();
    }

    // Load active session
    final currentSessionJson = prefs.getString('currentSession');
    if (currentSessionJson != null) {
      currentSession = ClassSession.fromJson(jsonDecode(currentSessionJson));
    } else {
      _initMockSession();
    }
    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    if (currentSession != null) {
      await prefs.setString(
        'currentSession',
        jsonEncode(currentSession!.toJson()),
      );
    } else {
      await prefs.remove('currentSession');
    }

    if (lecturer != null) {
      await prefs.setString(
        'lecturer',
        jsonEncode(lecturer!.toJson()),
      );
    }

    final pastSessionsJson = pastSessions
        .map((e) => jsonEncode(e.toJson()))
        .toList();
    await prefs.setStringList('pastSessions', pastSessionsJson);
  }

  Future<void> updateLecturer(Lecturer updated) async {
    lecturer = updated;
    await _saveData();
    notifyListeners();
  }

  void _initMockSession() {
    loadSessionByCode('CS101');
  }

  void loadMockSession() {
    loadSessionByCode('CS101');
  }

  void loadSessionByCode(String subjectCode) {
    if (subjectCode == 'CS202') {
      currentSession = ClassSession(
        id: 's2',
        subjectCode: 'CS202',
        subjectName: 'Advanced Algorithms',
        room: 'Hall A, Main Building',
        startTime: DateTime.now().copyWith(hour: 13, minute: 30),
        endTime: DateTime.now().copyWith(hour: 15, minute: 0),
        totalEnrolled: 32,
        previousAverageScore: 88,
        students: [
          Student(
            id: '201',
            name: 'Emma Watson',
            deviceId: 'tag_4',
            isVerified: true,
          ),
          Student(
            id: '202',
            name: 'Liam Neeson',
            deviceId: 'tag_5',
            isVerified: true,
          ),
          Student(
            id: '203',
            name: 'Olivia Wilde',
            deviceId: 'tag_6',
            isVerified: true,
          ),
        ],
        scannedStudents: [],
      );
    } else if (subjectCode == 'CS303') {
      currentSession = ClassSession(
        id: 's3',
        subjectCode: 'CS303',
        subjectName: 'Data Structures',
        room: 'Lab 1, Engineering Building',
        startTime: DateTime.now().copyWith(hour: 15, minute: 15),
        endTime: DateTime.now().copyWith(hour: 16, minute: 45),
        totalEnrolled: 45,
        previousAverageScore: 90,
        students: [
          Student(
            id: '301',
            name: 'Noah Centineo',
            deviceId: 'tag_7',
            isVerified: true,
          ),
          Student(
            id: '302',
            name: 'Ava DuVernay',
            deviceId: 'tag_8',
            isVerified: true,
          ),
          Student(
            id: '303',
            name: 'Lucas Hedges',
            deviceId: 'tag_9',
            isVerified: true,
          ),
        ],
        scannedStudents: [],
      );
    } else {
      // Default to CS101 (Computer Science 101)
      currentSession = ClassSession(
        id: 's1',
        subjectCode: 'CS101',
        subjectName: 'Computer Science 101',
        room: 'Lab 3, Engineering Building',
        startTime: DateTime.now().copyWith(hour: 10, minute: 0),
        endTime: DateTime.now().copyWith(hour: 11, minute: 30),
        totalEnrolled: 48,
        previousAverageScore: 92,
        students: [
          Student(
            id: '101',
            name: 'Benjamin Miller',
            deviceId: 'tag_1',
            isVerified: true,
          ),
          Student(
            id: '102',
            name: 'Sophia Chen',
            deviceId: 'tag_2',
            isVerified: true,
          ),
          Student(
            id: '103',
            name: 'Marcus Wright',
            deviceId: 'tag_3',
            isVerified: true,
          ),
        ],
        scannedStudents: [],
      );
    }
    _saveData();
    notifyListeners();
  }

  void finishSession() {
    if (currentSession != null) {
      pastSessions.add(currentSession!);
      currentSession = null;
      _saveData();
      notifyListeners();
    }
  }

  Future<void> startNfcScanning() async {
    isScanning = true;
    scanMessage = "Ready to Scan";
    notifyListeners();

    try {
      bool isAvailable =
          await NfcManager.instance.checkAvailability() ==
          NfcAvailability.enabled;
      if (!isAvailable) {
        scanMessage =
            "NFC is not available on this device.\nSimulating scan instead.";
        notifyListeners();
        // Emulate a scan on unsupported devices after a delay for testing purposes
        Future.delayed(const Duration(seconds: 3), () {
          if (isScanning) simulateNfcScan('tag_1');
        });
        return;
      }

      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          final uid = _extractTagUid(tag);
          if (uid != null) {
            handleScannedTag(uid);
          } else {
            scanMessage = "Failed to parse card ID";
            notifyListeners();
          }
        },
      );
    } catch (e) {
      scanMessage = "Error initializing NFC";
      notifyListeners();
    }
  }

  String? _extractTagUid(NfcTag tag) {
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

  void stopNfcScanning() {
    isScanning = false;
    scanMessage = null;
    NfcManager.instance.stopSession();
    notifyListeners();
  }

  void simulateNfcScan(String tagId) {
    if (!isScanning) return;
    handleScannedTag(tagId);
  }

  void handleScannedTag(String deviceId) {
    if (currentSession == null) return;

    final matchIdx = currentSession!.students.indexWhere(
      (s) => s.deviceId == deviceId,
    );
    if (matchIdx != -1) {
      _markStudentPresent(currentSession!.students[matchIdx]);
    } else {
      scanMessage = "Unrecognized Student Card\nUID: $deviceId";
      notifyListeners();
    }
  }

  void manuallyMarkPresent(String studentId) {
    if (currentSession == null) return;
    final matchIdx = currentSession!.students.indexWhere(
      (s) => s.id == studentId,
    );
    if (matchIdx != -1) {
      _markStudentPresent(currentSession!.students[matchIdx]);
    }
  }

  void _markStudentPresent(Student student) {
    if (currentSession!.scannedStudents.any((s) => s.id == student.id)) {
      scanMessage = "${student.name} already recorded.";
    } else {
      final verifiedStudent = student.copyWith(scanTime: DateTime.now());
      final updatedScannedList = List<Student>.from(
        currentSession!.scannedStudents,
      )..insert(0, verifiedStudent);
      currentSession = currentSession!.copyWith(
        scannedStudents: updatedScannedList,
      );
      lastScannedStudent = verifiedStudent;
      scanMessage = "Successfully recorded ${student.name}";
      _saveData();
    }
    notifyListeners();
  }
}
