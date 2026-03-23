import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:tap_attend/models/class_session.dart';
import 'package:tap_attend/models/student.dart';

class AttendanceProvider with ChangeNotifier {
  // Mock Data
  ClassSession? currentSession;
  bool isScanning = false;
  String? scanMessage;
  Student? lastScannedStudent;

  // Load a mock session for the UI
  void loadMockSession() {
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
        Student(id: '1', name: 'Benjamin Miller', deviceId: 'tag_1', isVerified: true),
        Student(id: '2', name: 'Sophia Chen', deviceId: 'tag_2', isVerified: true),
        Student(id: '3', name: 'Marcus Wright', deviceId: 'tag_3', isVerified: true),
      ],
      scannedStudents: [],
    );
    notifyListeners();
  }

  Future<void> startNfcScanning() async {
    isScanning = true;
    scanMessage = "Ready to Scan";
    notifyListeners();

    try {
      bool isAvailable = await NfcManager.instance.checkAvailability() == NfcAvailability.enabled;
      if (!isAvailable) {
        scanMessage = "NFC is not available on this device.\nSimulating scan instead.";
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
        // Let's assume we read tag_1 for the active mock test
        handleScannedTag('tag_1'); 
      });
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

    // Find student in enrolled list
    final matchIdx = currentSession!.students.indexWhere((s) => s.deviceId == deviceId);
    if (matchIdx != -1) {
      final student = currentSession!.students[matchIdx];
      // Check if already scanned
      if (currentSession!.scannedStudents.any((s) => s.id == student.id)) {
        scanMessage = "${student.name} already recorded.";
      } else {
        final verifiedStudent = student.copyWith(scanTime: DateTime.now());
        final updatedScannedList = List<Student>.from(currentSession!.scannedStudents)..insert(0, verifiedStudent);
        currentSession = currentSession!.copyWith(scannedStudents: updatedScannedList);
        lastScannedStudent = verifiedStudent;
        scanMessage = "Successfully recorded ${student.name}";
      }
    } else {
      scanMessage = "Unrecognized Student Card";
    }
    notifyListeners();
  }
}
