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

  // Sync Queues and Custom Local Data
  List<Student> customStudents = [];
  Map<String, String> customStudentSubjectCodes = {}; // Maps student.id -> subjectCode
  List<Map<String, dynamic>> pendingRegistrations = []; // Queue for offline registrations: {id, name, cardUid, subjectCode}
  List<String> pendingDeletions = []; // Queue for offline deletions: studentId
  List<String> unsyncedSessionIds = []; // Queue for offline finished session IDs
  List<String> deletedStudentIds = []; // Local deleted student IDs
  bool isServerOnline = true; // Simulated connection state (User can toggle in Sync Screen)
  String? activeLateSessionId; // If set, NFC scans record late attendance for this past session instead of currentSession

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

    // Load custom students
    final customStudentsJson = prefs.getStringList('customStudents');
    if (customStudentsJson != null) {
      customStudents = customStudentsJson
          .map((e) => Student.fromJson(jsonDecode(e)))
          .toList();
    }

    // Load custom student subject codes
    final customStudentSubjectCodesJson = prefs.getString('customStudentSubjectCodes');
    if (customStudentSubjectCodesJson != null) {
      customStudentSubjectCodes = Map<String, String>.from(jsonDecode(customStudentSubjectCodesJson));
    }

    // Load pending queues
    final pendingRegistrationsJson = prefs.getStringList('pendingRegistrations');
    if (pendingRegistrationsJson != null) {
      pendingRegistrations = pendingRegistrationsJson
          .map((e) => Map<String, dynamic>.from(jsonDecode(e)))
          .toList();
    }

    pendingDeletions = prefs.getStringList('pendingDeletions') ?? [];
    unsyncedSessionIds = prefs.getStringList('unsyncedSessionIds') ?? [];
    deletedStudentIds = prefs.getStringList('deletedStudentIds') ?? [];
    isServerOnline = prefs.getBool('isServerOnline') ?? true;

    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (currentSession != null) {
      await prefs.setString('currentSession', jsonEncode(currentSession!.toJson()));
    } else {
      await prefs.remove('currentSession');
    }

    if (lecturer != null) {
      await prefs.setString('lecturer', jsonEncode(lecturer!.toJson()));
    }

    final pastSessionsJson = pastSessions
        .map((e) => jsonEncode(e.toJson()))
        .toList();
    await prefs.setStringList('pastSessions', pastSessionsJson);

    final customStudentsJson = customStudents
        .map((e) => jsonEncode(e.toJson()))
        .toList();
    await prefs.setStringList('customStudents', customStudentsJson);

    await prefs.setString('customStudentSubjectCodes', jsonEncode(customStudentSubjectCodes));

    final pendingRegistrationsJson = pendingRegistrations
        .map((e) => jsonEncode(e))
        .toList();
    await prefs.setStringList('pendingRegistrations', pendingRegistrationsJson);

    await prefs.setStringList('pendingDeletions', pendingDeletions);
    await prefs.setStringList('unsyncedSessionIds', unsyncedSessionIds);
    await prefs.setStringList('deletedStudentIds', deletedStudentIds);
    await prefs.setBool('isServerOnline', isServerOnline);
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

  // Gets the initial hardcoded class roster
  List<Student> getDefaultStudents(String subjectCode) {
    if (subjectCode == 'CS101') {
      return [
        Student(id: '101', name: 'Benjamin Miller', deviceId: 'tag_1', isVerified: true),
        Student(id: '102', name: 'Sophia Chen', deviceId: 'tag_2', isVerified: true),
        Student(id: '103', name: 'Marcus Wright', deviceId: 'tag_3', isVerified: true),
      ];
    } else if (subjectCode == 'CS202') {
      return [
        Student(id: '201', name: 'Emma Watson', deviceId: 'tag_4', isVerified: true),
        Student(id: '202', name: 'Liam Neeson', deviceId: 'tag_5', isVerified: true),
        Student(id: '203', name: 'Olivia Wilde', deviceId: 'tag_6', isVerified: true),
      ];
    } else if (subjectCode == 'CS303') {
      return [
        Student(id: '301', name: 'Noah Centineo', deviceId: 'tag_7', isVerified: true),
        Student(id: '302', name: 'Ava DuVernay', deviceId: 'tag_8', isVerified: true),
        Student(id: '303', name: 'Lucas Hedges', deviceId: 'tag_9', isVerified: true),
      ];
    }
    return [];
  }

  // Get master list of all unique active students in the directory
  List<Student> get allStudentsInDirectory {
    final list = [
      ...getDefaultStudents('CS101'),
      ...getDefaultStudents('CS202'),
      ...getDefaultStudents('CS303'),
      ...customStudents,
    ];
    
    // Filter out deleted students
    final filteredList = list.where((s) => !deletedStudentIds.contains(s.id)).toList();
    
    // De-duplicate by ID
    final Map<String, Student> unique = {};
    for (var s in filteredList) {
      unique[s.id] = s;
    }
    return unique.values.toList();
  }

  void loadSessionByCode(String subjectCode) {
    // 1. Load default students
    final defaultList = getDefaultStudents(subjectCode);
    
    // 2. Load custom students enrolled in this class
    final customList = customStudents.where((s) => customStudentSubjectCodes[s.id] == subjectCode).toList();

    // Combine and apply deleted filters
    final combined = [...defaultList, ...customList];
    final activeStudents = combined.where((s) => !deletedStudentIds.contains(s.id)).toList();

    if (subjectCode == 'CS202') {
      currentSession = ClassSession(
        id: 's2',
        subjectCode: 'CS202',
        subjectName: 'Advanced Algorithms',
        room: 'Hall A, Main Building',
        startTime: DateTime.now().copyWith(hour: 13, minute: 30),
        endTime: DateTime.now().copyWith(hour: 15, minute: 0),
        totalEnrolled: activeStudents.length,
        previousAverageScore: 88,
        students: activeStudents,
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
        totalEnrolled: activeStudents.length,
        previousAverageScore: 90,
        students: activeStudents,
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
        totalEnrolled: activeStudents.length,
        previousAverageScore: 92,
        students: activeStudents,
        scannedStudents: [],
      );
    }
    _saveData();
    notifyListeners();
  }

  Future<void> finishSession() async {
    if (currentSession != null) {
      final session = currentSession!;
      pastSessions.add(session);
      currentSession = null;

      // Sync flow: Check server connection
      bool synced = await _trySyncSessionToXampp(session);
      if (!synced) {
        unsyncedSessionIds.add(session.id);
      }

      await _saveData();
      notifyListeners();
    }
  }

  // --- Student Registration & Deletion Operations ---

  // Checks if a card is already mapped to any student
  Student? checkCardRegistration(String cardUid) {
    final students = allStudentsInDirectory;
    final index = students.indexWhere((s) => s.deviceId == cardUid);
    if (index != -1) {
      return students[index];
    }
    return null;
  }

  // Registers a new student and syncs to XAMPP
  Future<void> registerNewStudent({
    required String id,
    required String name,
    required String cardUid,
    required String subjectCode,
  }) async {
    final newStudent = Student(
      id: id,
      name: name,
      deviceId: cardUid,
      isVerified: true,
    );

    // 1. Add locally
    customStudents.add(newStudent);
    customStudentSubjectCodes[id] = subjectCode;

    // 2. If active session matches class, append student to active session roster
    if (currentSession != null && currentSession!.subjectCode == subjectCode) {
      final updatedList = List<Student>.from(currentSession!.students)..add(newStudent);
      currentSession = currentSession!.copyWith(
        scannedStudents: currentSession!.scannedStudents,
      );
      // We manually construct ClassSession to update count
      currentSession = ClassSession(
        id: currentSession!.id,
        subjectCode: currentSession!.subjectCode,
        subjectName: currentSession!.subjectName,
        room: currentSession!.room,
        startTime: currentSession!.startTime,
        endTime: currentSession!.endTime,
        totalEnrolled: updatedList.length,
        previousAverageScore: currentSession!.previousAverageScore,
        students: updatedList,
        scannedStudents: currentSession!.scannedStudents,
      );
    }

    // 3. Sync to XAMPP
    bool synced = await _trySyncStudentToXampp(id, name, cardUid, subjectCode);
    if (!synced) {
      pendingRegistrations.add({
        'id': id,
        'name': name,
        'cardUid': cardUid,
        'subjectCode': subjectCode,
      });
    }

    // Remove from deleted list if they were previously deleted
    deletedStudentIds.remove(id);

    await _saveData();
    notifyListeners();
  }

  // Deletes a student from the directory
  Future<void> deleteStudent(String studentId) async {
    deletedStudentIds.add(studentId);

    // Remove from local custom list if present
    customStudents.removeWhere((s) => s.id == studentId);
    customStudentSubjectCodes.remove(studentId);

    // If active session has this student, remove them
    if (currentSession != null) {
      final updatedList = currentSession!.students.where((s) => s.id != studentId).toList();
      final updatedScannedList = currentSession!.scannedStudents.where((s) => s.id != studentId).toList();
      currentSession = ClassSession(
        id: currentSession!.id,
        subjectCode: currentSession!.subjectCode,
        subjectName: currentSession!.subjectName,
        room: currentSession!.room,
        startTime: currentSession!.startTime,
        endTime: currentSession!.endTime,
        totalEnrolled: updatedList.length,
        previousAverageScore: currentSession!.previousAverageScore,
        students: updatedList,
        scannedStudents: updatedScannedList,
      );
    }

    // Sync deletion to XAMPP
    bool synced = await _trySyncDeleteToXampp(studentId);
    if (!synced) {
      pendingDeletions.add(studentId);
    }

    await _saveData();
    notifyListeners();
  }

  // --- XAMPP API Communication & Syncing ---

  void toggleServerOnline(bool status) {
    isServerOnline = status;
    _saveData();
    notifyListeners();
    if (isServerOnline) {
      // Auto-trigger sync when connectivity is restored
      syncAllPendingData();
    }
  }

  Future<bool> _trySyncStudentToXampp(String id, String name, String cardUid, String subjectCode) async {
    if (!isServerOnline) return false;
    try {
      // ACTUAL INTEGRATION:
      // final response = await http.post(
      //   Uri.parse('http://<xampp_ip>/tap_attend/api/register_student.php'),
      //   body: {'id': id, 'name': name, 'deviceId': cardUid, 'subjectCode': subjectCode},
      // ).timeout(const Duration(seconds: 3));
      // return response.statusCode == 200;
      await Future.delayed(const Duration(milliseconds: 600));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _trySyncDeleteToXampp(String studentId) async {
    if (!isServerOnline) return false;
    try {
      // ACTUAL INTEGRATION:
      // final response = await http.post(
      //   Uri.parse('http://<xampp_ip>/tap_attend/api/delete_student.php'),
      //   body: {'id': studentId},
      // ).timeout(const Duration(seconds: 3));
      // return response.statusCode == 200;
      await Future.delayed(const Duration(milliseconds: 600));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _trySyncSessionToXampp(ClassSession session) async {
    if (!isServerOnline) return false;
    try {
      // ACTUAL INTEGRATION:
      // final response = await http.post(
      //   Uri.parse('http://<xampp_ip>/tap_attend/api/submit_attendance.php'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode(session.toJson()),
      // ).timeout(const Duration(seconds: 3));
      // return response.statusCode == 200;
      await Future.delayed(const Duration(milliseconds: 800));
      return true;
    } catch (_) {
      return false;
    }
  }

  // Tries to upload all queued offline records
  Future<void> syncAllPendingData() async {
    if (!isServerOnline) return;

    // 1. Sync pending student registrations
    final registrationsToSync = List<Map<String, dynamic>>.from(pendingRegistrations);
    for (var reg in registrationsToSync) {
      bool success = await _trySyncStudentToXampp(
        reg['id'],
        reg['name'],
        reg['cardUid'],
        reg['subjectCode'],
      );
      if (success) {
        pendingRegistrations.removeWhere((r) => r['id'] == reg['id']);
      }
    }

    // 2. Sync pending student deletions
    final deletionsToSync = List<String>.from(pendingDeletions);
    for (var studentId in deletionsToSync) {
      bool success = await _trySyncDeleteToXampp(studentId);
      if (success) {
        pendingDeletions.remove(studentId);
      }
    }

    // 3. Sync finished offline sessions
    final sessionsToSync = List<String>.from(unsyncedSessionIds);
    for (var sessionId in sessionsToSync) {
      // Find the session in pastSessions
      final index = pastSessions.indexWhere((s) => s.id == sessionId);
      if (index != -1) {
        bool success = await _trySyncSessionToXampp(pastSessions[index]);
        if (success) {
          unsyncedSessionIds.remove(sessionId);
        }
      }
    }

    await _saveData();
    notifyListeners();
  }

  // --- NFC Scanning Logic ---

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
    if (activeLateSessionId != null) {
      final msg = handleScannedTagForPastSession(activeLateSessionId!, deviceId);
      if (msg != null) {
        scanMessage = msg;
        notifyListeners();
      }
      return;
    }

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

  // --- Late Attendance / Past Session Operations ---

  // Retrieves an existing past session on a given date, or creates a retrospective one
  ClassSession getOrCreatePastSession(String subjectCode, DateTime date) {
    final existingIdx = pastSessions.indexWhere((s) => 
      s.subjectCode == subjectCode &&
      s.startTime.year == date.year &&
      s.startTime.month == date.month &&
      s.startTime.day == date.day
    );
    
    if (existingIdx != -1) {
      return pastSessions[existingIdx];
    }
    
    final defaultList = getDefaultStudents(subjectCode);
    final customList = customStudents.where((s) => customStudentSubjectCodes[s.id] == subjectCode).toList();
    final combined = [...defaultList, ...customList];
    final roster = combined.where((s) => !deletedStudentIds.contains(s.id)).toList();
    
    DateTime startTime;
    DateTime endTime;
    String room;
    String subjectName;
    
    if (subjectCode == 'CS202') {
      subjectName = 'Advanced Algorithms';
      room = 'Hall A, Main Building';
      startTime = DateTime(date.year, date.month, date.day, 13, 30);
      endTime = DateTime(date.year, date.month, date.day, 15, 0);
    } else if (subjectCode == 'CS303') {
      subjectName = 'Data Structures';
      room = 'Lab 1, Engineering Building';
      startTime = DateTime(date.year, date.month, date.day, 15, 15);
      endTime = DateTime(date.year, date.month, date.day, 16, 45);
    } else {
      subjectName = 'Computer Science 101';
      room = 'Lab 3, Engineering Building';
      startTime = DateTime(date.year, date.month, date.day, 10, 0);
      endTime = DateTime(date.year, date.month, date.day, 11, 30);
    }
    
    final newSessionId = 'past_${subjectCode}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    
    final newSession = ClassSession(
      id: newSessionId,
      subjectCode: subjectCode,
      subjectName: subjectName,
      room: room,
      startTime: startTime,
      endTime: endTime,
      totalEnrolled: roster.length,
      previousAverageScore: 85,
      students: roster,
      scannedStudents: [],
    );
    
    pastSessions.add(newSession);
    _saveData();
    notifyListeners();
    return newSession;
  }

  // Marks a student present in a past session retrospectively
  Future<void> markStudentPresentInPastSession(String sessionId, String studentId) async {
    final idx = pastSessions.indexWhere((s) => s.id == sessionId);
    if (idx != -1) {
      final session = pastSessions[idx];
      if (session.scannedStudents.any((s) => s.id == studentId)) {
        return;
      }
      final studentIdx = session.students.indexWhere((s) => s.id == studentId);
      if (studentIdx != -1) {
        final student = session.students[studentIdx];
        final verifiedStudent = student.copyWith(scanTime: DateTime.now());
        final updatedScanned = List<Student>.from(session.scannedStudents)..insert(0, verifiedStudent);
        final updatedSession = session.copyWith(scannedStudents: updatedScanned);
        pastSessions[idx] = updatedSession;
        
        bool synced = await _trySyncSessionToXampp(updatedSession);
        if (!synced) {
          if (!unsyncedSessionIds.contains(sessionId)) {
            unsyncedSessionIds.add(sessionId);
          }
        }
        await _saveData();
        notifyListeners();
      }
    }
  }

  // Handles scanned NFC tag for a past session late recording
  String? handleScannedTagForPastSession(String sessionId, String deviceId) {
    final idx = pastSessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return "Session not found";
    
    final session = pastSessions[idx];
    final studentIdx = session.students.indexWhere((s) => s.deviceId == deviceId);
    if (studentIdx == -1) {
      return "Card not registered\nto this class";
    }
    
    final student = session.students[studentIdx];
    if (session.scannedStudents.any((s) => s.id == student.id)) {
      return "${student.name}\nis already present";
    }
    
    final verifiedStudent = student.copyWith(scanTime: DateTime.now());
    final updatedScanned = List<Student>.from(session.scannedStudents)..insert(0, verifiedStudent);
    final updatedSession = session.copyWith(scannedStudents: updatedScanned);
    pastSessions[idx] = updatedSession;
    
    _syncPastSessionUpdate(updatedSession);
    return "Successfully recorded\n${student.name}";
  }
  
  Future<void> _syncPastSessionUpdate(ClassSession updatedSession) async {
    bool synced = await _trySyncSessionToXampp(updatedSession);
    if (!synced) {
      if (!unsyncedSessionIds.contains(updatedSession.id)) {
        unsyncedSessionIds.add(updatedSession.id);
      }
    }
    await _saveData();
    notifyListeners();
  }
}
