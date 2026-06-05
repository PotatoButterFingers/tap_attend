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
    currentSession = ClassSession(
      id: 's1',
      subjectCode: 'CS101',
      subjectName: 'Introduction to Data Structures & Algorithms',
      room: 'Lecture Hall B2, Engineering Wing',
      startTime: DateTime.now().copyWith(hour: 10, minute: 0),
      endTime: DateTime.now().copyWith(hour: 11, minute: 30),
      totalEnrolled: 48,
      previousAverageScore: 92,
      students: [
        Student(
          id: '1',
          name: 'Benjamin Miller',
          deviceId: 'tag_1',
          isVerified: true,
        ),
        Student(
          id: '2',
          name: 'Sophia Chen',
          deviceId: 'tag_2',
          isVerified: true,
        ),
        Student(
          id: '3',
          name: 'Marcus Wright',
          deviceId: 'tag_3',
          isVerified: true,
        ),
      ],
      scannedStudents: [],
    );
  }

  void loadMockSession() {
    _initMockSession();
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
          // Assume we get identifier from tag. For simulation:
          handleScannedTag('tag_1');
        },
      );
    } catch (e) {
      scanMessage = "Error initializing NFC";
      notifyListeners();
    }
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
      scanMessage = "Unrecognized Student Card";
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
