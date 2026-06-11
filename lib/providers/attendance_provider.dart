import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
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
  
  Lecturer? lecturer;
  String? cachedLecturerId;
  String? cachedPassword;
  String? nfcLoginCardUid;

  // Sync Queues and Custom Local Data
  List<Student> customStudents = [];
  Map<String, String> customStudentSubjectCodes = {}; // Maps student.id -> subjectCode
  List<Map<String, dynamic>> pendingRegistrations = []; // Queue for offline registrations: {id, name, cardUid, subjectCode}
  List<String> pendingDeletions = []; // Queue for offline deletions: studentId
  List<String> unsyncedSessionIds = []; // Queue for offline finished session IDs
  List<String> deletedStudentIds = []; // Local deleted student IDs
  List<String> deletedSessionIds = []; // Local deleted session IDs
  List<ClassSession> deletedSessionsCache = []; // Offline cache for deleted sessions
  bool isServerConnectionActive = false; // Actual connection state
  bool isLecturerProfileUnsynced = false; // True if lecturer edits were made offline and need sync
  String? activeLateSessionId; // If set, NFC scans record late attendance for this past session instead of currentSession
  String serverIp = '10.0.2.2'; // Use 10.0.2.2 for Android emulator gateway, localhost for iOS, or computer's local IP (e.g. 192.168.x.x) for physical phones
  String? trustedServerToken;
  String? trustedServerName;

  static const MethodChannel _nfcChannel = MethodChannel('com.example.tap_attend/nfc');
  static const EventChannel _nfcEventChannel = EventChannel('com.example.tap_attend/nfc_events');
  StreamSubscription? _nfcSubscription;

  Future<void>? initializationFuture;

  AttendanceProvider() {
    initializationFuture = _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    serverIp = prefs.getString('serverIp') ?? '10.0.2.2';
    trustedServerToken = prefs.getString('trustedServerToken');
    trustedServerName = prefs.getString('trustedServerName');

    cachedLecturerId = prefs.getString('cachedLecturerId');
    cachedPassword = prefs.getString('cachedPassword');
    nfcLoginCardUid = prefs.getString('nfcLoginCardUid');

    // Load lecturer profile
    final lecturerJson = prefs.getString('lecturer');
    if (lecturerJson != null) {
      var parsedLecturer = Lecturer.fromJson(jsonDecode(lecturerJson));
      if (parsedLecturer.id.isEmpty && cachedLecturerId != null) {
        parsedLecturer = parsedLecturer.copyWith(id: cachedLecturerId);
      }
      lecturer = parsedLecturer;
    }

    // Load deleted session IDs first to use them for filtering
    deletedSessionIds = prefs.getStringList('deletedSessionIds') ?? [];

    // Load deleted sessions cache
    final deletedSessionsJson = prefs.getStringList('deletedSessionsCache');
    if (deletedSessionsJson != null) {
      deletedSessionsCache = deletedSessionsJson
          .map((e) => ClassSession.fromJson(jsonDecode(e)))
          .toList();
    } else {
      deletedSessionsCache = [];
    }

    // Load past sessions
    final pastSessionsJson = prefs.getStringList('pastSessions');
    if (pastSessionsJson != null) {
      pastSessions = pastSessionsJson
          .map((e) => ClassSession.fromJson(jsonDecode(e)))
          .where((s) => !deletedSessionIds.contains(s.id))
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
    } else {
      // Seed default students on first run
      customStudents = [
        Student(id: '101', name: 'Benjamin Miller', deviceId: 'tag_1', isVerified: true),
        Student(id: '102', name: 'Sophia Chen', deviceId: 'tag_2', isVerified: true),
        Student(id: '103', name: 'Marcus Wright', deviceId: 'tag_3', isVerified: true),
        Student(id: '201', name: 'Emma Watson', deviceId: 'tag_4', isVerified: true),
        Student(id: '202', name: 'Liam Neeson', deviceId: 'tag_5', isVerified: true),
        Student(id: '203', name: 'Olivia Wilde', deviceId: 'tag_6', isVerified: true),
        Student(id: '301', name: 'Noah Centineo', deviceId: 'tag_7', isVerified: true),
        Student(id: '302', name: 'Ava DuVernay', deviceId: 'tag_8', isVerified: true),
        Student(id: '303', name: 'Lucas Hedges', deviceId: 'tag_9', isVerified: true),
      ];
    }

    // Load custom student subject codes
    final customStudentSubjectCodesJson = prefs.getString('customStudentSubjectCodes');
    if (customStudentSubjectCodesJson != null) {
      customStudentSubjectCodes = Map<String, String>.from(jsonDecode(customStudentSubjectCodesJson));
    } else {
      // Seed default student class mappings on first run
      customStudentSubjectCodes = {
        '101': 'CS101',
        '102': 'CS101',
        '103': 'CS101',
        '201': 'CS202',
        '202': 'CS202',
        '203': 'CS202',
        '301': 'CS303',
        '302': 'CS303',
        '303': 'CS303',
      };
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
    isLecturerProfileUnsynced = prefs.getBool('isLecturerProfileUnsynced') ?? false;

    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString('serverIp', serverIp);
    if (trustedServerToken != null) {
      await prefs.setString('trustedServerToken', trustedServerToken!);
    } else {
      await prefs.remove('trustedServerToken');
    }
    if (trustedServerName != null) {
      await prefs.setString('trustedServerName', trustedServerName!);
    } else {
      await prefs.remove('trustedServerName');
    }

    if (currentSession != null) {
      await prefs.setString('currentSession', jsonEncode(currentSession!.toJson()));
    } else {
      await prefs.remove('currentSession');
    }

    if (lecturer != null) {
      await prefs.setString('lecturer', jsonEncode(lecturer!.toJson()));
    } else {
      await prefs.remove('lecturer');
    }
    
    if (cachedLecturerId != null) {
      await prefs.setString('cachedLecturerId', cachedLecturerId!);
    } else {
      await prefs.remove('cachedLecturerId');
    }

    if (cachedPassword != null) {
      await prefs.setString('cachedPassword', cachedPassword!);
    } else {
      await prefs.remove('cachedPassword');
    }

    if (nfcLoginCardUid != null) {
      await prefs.setString('nfcLoginCardUid', nfcLoginCardUid!);
    } else {
      await prefs.remove('nfcLoginCardUid');
    }

    final pastSessionsJson = pastSessions
        .map((e) => jsonEncode(e.toJson()))
        .toList();
    await prefs.setStringList('pastSessions', pastSessionsJson);

    final deletedSessionsJson = deletedSessionsCache
        .map((e) => jsonEncode(e.toJson()))
        .toList();
    await prefs.setStringList('deletedSessionsCache', deletedSessionsJson);

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
    await prefs.setStringList('deletedSessionIds', deletedSessionIds);
    await prefs.setBool('isLecturerProfileUnsynced', isLecturerProfileUnsynced);
  }

  Future<DiscoveredServer?> checkHandshake(String ip) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip/tap_attend/api/handshake.php'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['app'] == 'tap_attend') {
          return DiscoveredServer(
            ip: ip,
            name: data['server_name'] ?? 'Tap Attend Server',
            token: data['server_token'] ?? '',
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> setTrustedServer(DiscoveredServer server) async {
    trustedServerToken = server.token;
    trustedServerName = server.name;
    serverIp = server.ip;
    await _saveData();
    notifyListeners();
    await checkServerConnection();
  }

  Future<void> updateServerIp(String ip) async {
    serverIp = ip;
    await _saveData();
    notifyListeners();
    
    final info = await checkHandshake(ip);
    if (info != null) {
      trustedServerToken = info.token;
      trustedServerName = info.name;
      await _saveData();
    }
    
    await checkServerConnection();
  }

  Future<bool> updateLecturer(Lecturer updated) async {
    final cleanedLecturer = updated.copyWith(
      cardUid: updated.cardUid != null ? _normalizeUid(updated.cardUid!) : null,
    );
    lecturer = cleanedLecturer;
    if (cleanedLecturer.cardUid != null) {
      nfcLoginCardUid = cleanedLecturer.cardUid;
    }
    await _saveData();
    // Update cachedLecturer in SharedPreferences so offline login has the updated profile
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cachedLecturer', jsonEncode(cleanedLecturer.toJson()));
    notifyListeners();

    // Try to sync with server
    bool success = await _trySyncLecturerProfileToXampp(cleanedLecturer);
    if (success) {
      isLecturerProfileUnsynced = false;
    } else {
      isLecturerProfileUnsynced = true;
    }
    
    await _saveData(); // Save the new value of isLecturerProfileUnsynced
    notifyListeners();
    return success;
  }

  void _initMockSession() {
    loadSessionByCode('CS101');
  }

  void loadMockSession() {
    loadSessionByCode('CS101');
  }

  // Get master list of all unique active students in the directory
  List<Student> get allStudentsInDirectory {
    // Filter out deleted students
    final filteredList = customStudents.where((s) => !deletedStudentIds.contains(s.id)).toList();
    
    // De-duplicate by ID
    final Map<String, Student> unique = {};
    for (var s in filteredList) {
      unique[s.id] = s;
    }
    return unique.values.toList();
  }

  void loadSessionByCode(String subjectCode) {
    // Load custom students enrolled in this class from local cache
    final activeStudents = customStudents
        .where((s) => customStudentSubjectCodes[s.id] == subjectCode && !deletedStudentIds.contains(s.id))
        .toList();

    final uniqueId = '${subjectCode == 'CS202' ? 's2' : subjectCode == 'CS303' ? 's3' : 's1'}_${DateTime.now().millisecondsSinceEpoch}';
    deletedSessionIds.remove(uniqueId);

    if (subjectCode == 'CS202') {
      currentSession = ClassSession(
        id: uniqueId,
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
        id: uniqueId,
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
        id: uniqueId,
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

  void loadSession(ClassSession session) {
    currentSession = session;
    deletedSessionIds.remove(session.id);
    _saveData();
    notifyListeners();
  }

  Future<void> finishSession() async {
    if (currentSession != null) {
      final session = currentSession!;
      final existingIdx = pastSessions.indexWhere((s) => s.id == session.id);
      if (existingIdx != -1) {
        pastSessions[existingIdx] = session;
      } else {
        pastSessions.add(session);
      }
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

  String _normalizeUid(String uid) {
    return uid.trim().replaceAll(':', '').replaceAll(' ', '').replaceAll('-', '').toUpperCase();
  }

  // Checks if a card is already mapped to any student
  Student? checkCardRegistration(String cardUid) {
    final students = allStudentsInDirectory;
    final normalized = _normalizeUid(cardUid);
    final index = students.indexWhere((s) => _normalizeUid(s.deviceId) == normalized);
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
    final cleanedCardUid = _normalizeUid(cardUid);
    final newStudent = Student(
      id: id,
      name: name,
      deviceId: cleanedCardUid,
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
    bool synced = await _trySyncStudentToXampp(id, name, cleanedCardUid, subjectCode);
    if (!synced) {
      pendingRegistrations.add({
        'id': id,
        'name': name,
        'cardUid': cleanedCardUid,
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

  Future<bool> checkServerConnection() async {
    try {
      final response = await http.get(Uri.parse('http://$serverIp/tap_attend/api/db_connect.php')).timeout(const Duration(seconds: 2));
      isServerConnectionActive = (response.statusCode == 200);
    } catch (_) {
      isServerConnectionActive = false;
    }
    notifyListeners();
    if (isServerConnectionActive) {
      await syncAllPendingData();
      await fetchStudentsFromServer();
      await fetchSessionsFromServer();
    }
    return isServerConnectionActive;
  }

  Future<void> fetchStudentsFromServer() async {
    try {
      final response = await http.get(Uri.parse('http://$serverIp/tap_attend/api/get_students.php')).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        isServerConnectionActive = true;
        final List<dynamic> data = jsonDecode(response.body);
        final List<Student> fetchedStudents = [];
        final Map<String, String> fetchedSubjectCodes = {};

        for (var item in data) {
          final student = Student(
            id: item['id'],
            name: item['name'],
            deviceId: item['deviceId'],
            isVerified: item['isVerified'] ?? true,
          );
          fetchedStudents.add(student);
          fetchedSubjectCodes[student.id] = item['subjectCode'];
        }

        customStudents = fetchedStudents;
        customStudentSubjectCodes = fetchedSubjectCodes;
        await _saveData();
        notifyListeners();
      } else {
        isServerConnectionActive = false;
        notifyListeners();
      }
    } catch (_) {
      isServerConnectionActive = false;
      notifyListeners();
    }
  }

  Future<void> fetchSessionsFromServer() async {
    try {
      debugPrint("[DateDebug] fetchSessionsFromServer started. ServerIp: $serverIp");
      final response = await http.get(Uri.parse('http://$serverIp/tap_attend/api/get_sessions.php')).timeout(const Duration(seconds: 3));
      debugPrint("[DateDebug] fetchSessionsFromServer response: ${response.statusCode}, body: ${response.body}");
      if (response.statusCode == 200) {
        isServerConnectionActive = true;
        final List<dynamic> data = jsonDecode(response.body);
        final List<ClassSession> fetchedSessions = data
            .map((e) => ClassSession.fromJson(e))
            .where((s) => !deletedSessionIds.contains(s.id))
            .toList();

        // Retain local unsynced sessions so they are not wiped out by server fetches
        final List<ClassSession> unsyncedSessions = pastSessions
            .where((s) => unsyncedSessionIds.contains(s.id) && !deletedSessionIds.contains(s.id))
            .toList();

        // Merge fetched sessions and unsynced sessions, avoiding duplicates
        final mergedSessions = <ClassSession>[];
        for (var s in fetchedSessions) {
          if (!mergedSessions.any((existing) => existing.id == s.id)) {
            mergedSessions.add(s);
          }
        }
        for (var s in unsyncedSessions) {
          if (!mergedSessions.any((existing) => existing.id == s.id)) {
            mergedSessions.add(s);
          }
        }

        pastSessions = mergedSessions;
        await _saveData();
        notifyListeners();
      } else {
        isServerConnectionActive = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("[DateDebug] fetchSessionsFromServer error: $e");
      isServerConnectionActive = false;
      notifyListeners();
    }
  }

  // Checks the XAMPP server for a session matching the subjectCode and date.
  // If found, merges/saves it to local pastSessions and returns it.
  Future<ClassSession?> checkAndFetchSessionFromServer(String subjectCode, DateTime date) async {
    // 1. First, check our local deleted sessions cache (handles offline restore!)
    final localMatchIdx = deletedSessionsCache.lastIndexWhere((s) =>
        s.subjectCode == subjectCode &&
        s.startTime.year == date.year &&
        s.startTime.month == date.month &&
        s.startTime.day == date.day);
    
    if (localMatchIdx != -1) {
      final match = deletedSessionsCache[localMatchIdx];
      deletedSessionsCache.removeAt(localMatchIdx);
      deletedSessionIds.remove(match.id);
      
      final existingIdx = pastSessions.indexWhere((s) => s.id == match.id);
      if (existingIdx != -1) {
        pastSessions[existingIdx] = match;
      } else {
        pastSessions.add(match);
      }
      await _saveData();
      notifyListeners();
      return match;
    }

    // 2. If not found in local cache, proceed with server fetch
    try {
      debugPrint("[DateDebug] checkAndFetchSessionFromServer started. Code: $subjectCode, Date: $date, ServerIp: $serverIp");
      final response = await http.get(
        Uri.parse('http://$serverIp/tap_attend/api/get_sessions.php'),
      ).timeout(const Duration(seconds: 3));
      
      debugPrint("[DateDebug] checkAndFetchSessionFromServer response: ${response.statusCode}, body: ${response.body}");
      if (response.statusCode == 200) {
        isServerConnectionActive = true;
        final List<dynamic> data = jsonDecode(response.body);
        final List<ClassSession> fetchedSessions = data
            .map((e) => ClassSession.fromJson(e))
            .toList();
        
        for (var s in fetchedSessions) {
          debugPrint("[DateDebug] Fetched: id=${s.id}, code=${s.subjectCode}, startTime=${s.startTime} (Y:${s.startTime.year} M:${s.startTime.month} D:${s.startTime.day})");
        }
        
        // Find matches (ignore deletedSessionIds here so we can retrieve and restore it when explicitly requested via dashboard/details today)
        final matches = fetchedSessions.where((s) {
          return s.subjectCode == subjectCode &&
              s.startTime.year == date.year &&
              s.startTime.month == date.month &&
              s.startTime.day == date.day;
        }).toList();

        if (matches.isNotEmpty) {
          // Return the first matching session and restore it (remove from deletedSessionIds)
          final match = matches.first;
          deletedSessionIds.remove(match.id);
          
          final existingIdx = pastSessions.indexWhere((s) => s.id == match.id);
          if (existingIdx != -1) {
            pastSessions[existingIdx] = match;
          } else {
            pastSessions.add(match);
          }
          await _saveData();
          notifyListeners();
          return match;
        }
        notifyListeners();
      } else {
        isServerConnectionActive = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("[DateDebug] checkAndFetchSessionFromServer error: $e");
      isServerConnectionActive = false;
      notifyListeners();
    }
    return null;
  }

  Future<bool> _trySyncLecturerProfileToXampp(Lecturer profile) async {
    try {
      final response = await http.post(
        Uri.parse('http://$serverIp/tap_attend/api/update_lecturer.php'),
        body: {
          'lecturer_id': profile.id,
          'name': profile.name,
          'email': profile.email,
          'department': profile.department,
          'office': profile.office,
          'phone': profile.phone,
          'card_uid': profile.cardUid,
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> _trySyncStudentToXampp(String id, String name, String cardUid, String subjectCode) async {
    try {
      final response = await http.post(
        Uri.parse('http://$serverIp/tap_attend/api/register_student.php'),
        body: {'id': id, 'name': name, 'deviceId': cardUid, 'subjectCode': subjectCode},
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _trySyncDeleteToXampp(String studentId) async {
    try {
      final response = await http.post(
        Uri.parse('http://$serverIp/tap_attend/api/delete_student.php'),
        body: {'id': studentId},
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _trySyncSessionToXampp(ClassSession session) async {
    try {
      final response = await http.post(
        Uri.parse('http://$serverIp/tap_attend/api/submit_attendance.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(session.toJson()),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Tries to upload all queued offline records
  Future<void> syncAllPendingData() async {
    if (!isServerConnectionActive) return;

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

    // 4. Sync pending lecturer profile edits
    if (isLecturerProfileUnsynced && lecturer != null) {
      bool success = await _trySyncLecturerProfileToXampp(lecturer!);
      if (success) {
        isLecturerProfileUnsynced = false;
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
      if (Platform.isAndroid) {
        await _nfcChannel.invokeMethod('startNfc');
        _nfcSubscription?.cancel();
        _nfcSubscription = _nfcEventChannel.receiveBroadcastStream().listen((dynamic uid) {
          if (uid is String) {
            handleScannedTag(uid);
          } else {
            scanMessage = "Failed to parse card ID";
            notifyListeners();
          }
        });
      } else {
        scanMessage = "NFC is not available on this device.\nSimulating scan instead.";
        notifyListeners();
        Future.delayed(const Duration(seconds: 3), () {
          if (isScanning) simulateNfcScan('tag_1');
        });
      }
    } catch (e) {
      scanMessage = "Error initializing NFC";
      notifyListeners();
    }
  }

  void stopNfcScanning() {
    isScanning = false;
    scanMessage = null;
    _nfcSubscription?.cancel();
    if (Platform.isAndroid) {
      _nfcChannel.invokeMethod('stopNfc').catchError((_) {});
    }
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

    final normalizedScanned = _normalizeUid(deviceId);
    final matchIdx = currentSession!.students.indexWhere(
      (s) => _normalizeUid(s.deviceId) == normalizedScanned,
    );
    if (matchIdx != -1) {
      _markStudentPresent(currentSession!.students[matchIdx]);
    } else {
      scanMessage = "Unrecognized Student Card\nUID: $normalizedScanned";
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
    
    final roster = customStudents
        .where((s) => customStudentSubjectCodes[s.id] == subjectCode && !deletedStudentIds.contains(s.id))
        .toList();
    
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
    deletedSessionIds.remove(newSessionId);
    
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
    final normalizedScanned = _normalizeUid(deviceId);
    final studentIdx = session.students.indexWhere(
      (s) => _normalizeUid(s.deviceId) == normalizedScanned,
    );
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

  // Deletes a single past session from history (local app history only)
  Future<void> deletePastSession(String sessionId) async {
    final sessionIdx = pastSessions.indexWhere((s) => s.id == sessionId);
    if (sessionIdx != -1) {
      final session = pastSessions[sessionIdx];
      if (!deletedSessionsCache.any((s) => s.id == sessionId)) {
        deletedSessionsCache.add(session);
      }
    }
    pastSessions.removeWhere((s) => s.id == sessionId);
    if (!deletedSessionIds.contains(sessionId)) {
      deletedSessionIds.add(sessionId);
    }
    await _saveData();
    notifyListeners();
  }

  // Clears all past sessions from history (local app history only)
  Future<void> clearAllPastSessions() async {
    for (var s in pastSessions) {
      if (!deletedSessionsCache.any((cached) => cached.id == s.id)) {
        deletedSessionsCache.add(s);
      }
      if (!deletedSessionIds.contains(s.id)) {
        deletedSessionIds.add(s.id);
      }
    }
    pastSessions.clear();
    await _saveData();
    notifyListeners();
  }

  // Removes a student's attendance from a session and updates the XAMPP database
  Future<void> removeStudentAttendance(String sessionId, String studentId) async {
    final index = pastSessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      final session = pastSessions[index];
      final updatedScanned = session.scannedStudents.where((s) => s.id != studentId).toList();
      final updatedSession = session.copyWith(scannedStudents: updatedScanned);
      
      pastSessions[index] = updatedSession;
      
      // Sync change to XAMPP database immediately if online, else queue it
      bool success = await _trySyncSessionToXampp(updatedSession);
      if (!success) {
        if (!unsyncedSessionIds.contains(sessionId)) {
          unsyncedSessionIds.add(sessionId);
        }
      } else {
        unsyncedSessionIds.remove(sessionId);
      }
      
      await _saveData();
      notifyListeners();
    }
  }

  // Clears all student attendance from a session (makes everyone absent) and updates XAMPP
  Future<void> clearAllSessionAttendance(String sessionId) async {
    final index = pastSessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      final session = pastSessions[index];
      final updatedSession = session.copyWith(scannedStudents: []);
      
      pastSessions[index] = updatedSession;
      
      // Sync change to XAMPP database immediately if online, else queue it
      bool success = await _trySyncSessionToXampp(updatedSession);
      if (!success) {
        if (!unsyncedSessionIds.contains(sessionId)) {
          unsyncedSessionIds.add(sessionId);
        }
      } else {
        unsyncedSessionIds.remove(sessionId);
      }
      
      await _saveData();
      notifyListeners();
    }
  }

  // Auto-scans local subnet IPs (e.g. 192.168.1.x or 10.x.x.x) to locate the XAMPP backend
  Future<DiscoveredServer?> autoDiscoverServer() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
        includeLoopback: false,
      );

      if (interfaces.isEmpty) return null;

      String? localIp;
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          // Identify common private network / local subnets
          if (addr.address.startsWith('192.168.') ||
              addr.address.startsWith('10.') ||
              addr.address.startsWith('172.')) {
            localIp = addr.address;
            break;
          }
        }
        if (localIp != null) break;
      }

      if (localIp == null) return null;

      final parts = localIp.split('.');
      if (parts.length != 4) return null;
      final subnetPrefix = '${parts[0]}.${parts[1]}.${parts[2]}';

      // Perform a fast concurrent subnet scan checking the handshake endpoint
      final List<Future<DiscoveredServer?>> scanFutures = [];
      for (int i = 1; i <= 254; i++) {
        final ipToTest = '$subnetPrefix.$i';
        if (ipToTest == localIp) continue;

        scanFutures.add(
          http.get(Uri.parse('http://$ipToTest/tap_attend/api/handshake.php'))
              .timeout(const Duration(milliseconds: 1000))
              .then((response) {
                if (response.statusCode == 200) {
                  final data = jsonDecode(response.body);
                  if (data['success'] == true && data['app'] == 'tap_attend') {
                    return DiscoveredServer(
                      ip: ipToTest,
                      name: data['server_name'] ?? 'Tap Attend Server',
                      token: data['server_token'] ?? '',
                    );
                  }
                }
                return null;
              })
              .catchError((_) => null)
        );
      }

      final results = await Future.wait(scanFutures);
      final foundServers = results.whereType<DiscoveredServer>().toList();
      if (foundServers.isEmpty) return null;

      // If we already have a trusted server token, try to find a matching one first
      if (trustedServerToken != null) {
        for (var server in foundServers) {
          if (server.token == trustedServerToken) {
            // Match found! Auto-reconnect silently.
            await updateServerIp(server.ip);
            return server;
          }
        }
      }

      // No matching trusted server found or first time connecting.
      // Return the first discovered server candidate for user confirmation.
      return foundServers.first;
    } catch (_) {}
    return null;
  }

  Future<bool> loginLecturer(String lecturerId, String password) async {
    if (initializationFuture != null) {
      await initializationFuture;
    }

    final idClean = lecturerId.trim().toLowerCase();
    final pwdClean = password.trim();

    if (idClean.isEmpty || pwdClean.isEmpty) return false;

    // 1. Try online login first if server connection is active
    if (isServerConnectionActive) {
      try {
        final response = await http.post(
          Uri.parse('http://$serverIp/tap_attend/api/login_lecturer.php'),
          body: {'lecturer_id': idClean, 'password': pwdClean},
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            lecturer = Lecturer.fromJson(data['lecturer']);
            cachedLecturerId = idClean;
            cachedPassword = pwdClean;
            nfcLoginCardUid = lecturer?.cardUid != null ? _normalizeUid(lecturer!.cardUid!) : null;
            await _saveData();
            // Store the lecturer profile in a persistent cache so it's not lost on sign out
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('cachedLecturer', jsonEncode(lecturer!.toJson()));
            notifyListeners();
            return true;
          }
        }
      } catch (_) {
        // Fallback to offline check if network fails
      }
    }

    // 2. Offline Mode verification against local cache
    if (cachedLecturerId != null && cachedPassword != null) {
      if (idClean == cachedLecturerId && pwdClean == cachedPassword) {
        if (lecturer == null) {
          final prefs = await SharedPreferences.getInstance();
          final lecturerJson = prefs.getString('cachedLecturer') ?? prefs.getString('lecturer');
          if (lecturerJson != null) {
            var parsed = Lecturer.fromJson(jsonDecode(lecturerJson));
            if (parsed.id.isEmpty && cachedLecturerId != null) {
              parsed = parsed.copyWith(id: cachedLecturerId);
            }
            lecturer = parsed;
          }
        }
        nfcLoginCardUid = lecturer?.cardUid != null ? _normalizeUid(lecturer!.cardUid!) : null;
        notifyListeners();
        return true;
      }
    }

    return false;
  }

  Future<bool> loginWithNfc(String cardUid) async {
    try {
      final cardUidClean = _normalizeUid(cardUid);
      if (cardUidClean.isEmpty) return false;

      // 1. Try online login first if server connection is active
      if (isServerConnectionActive) {
        try {
          final response = await http.post(
            Uri.parse('http://$serverIp/tap_attend/api/login_lecturer_nfc.php'),
            body: {'card_uid': cardUidClean},
          ).timeout(const Duration(seconds: 4));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['success'] == true) {
              lecturer = Lecturer.fromJson(data['lecturer']);
              cachedLecturerId = lecturer!.id;
              nfcLoginCardUid = cardUidClean;
              await _saveData();
              // Store the lecturer profile in a persistent cache so it's not lost on sign out
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('cachedLecturer', jsonEncode(lecturer!.toJson()));
              notifyListeners();
              return true;
            }
          }
        } catch (_) {
          // Fallback to offline check if network fails
        }
      }

      // 2. Offline Mode verification against local cached profile
      final prefs = await SharedPreferences.getInstance();
      final lecturerJson = prefs.getString('cachedLecturer') ?? prefs.getString('lecturer');
      if (lecturerJson != null) {
        var cachedLecturer = Lecturer.fromJson(jsonDecode(lecturerJson));
        if (cachedLecturer.id.isEmpty && cachedLecturerId != null) {
          cachedLecturer = cachedLecturer.copyWith(id: cachedLecturerId);
        }
        if (cachedLecturer.cardUid != null && _normalizeUid(cachedLecturer.cardUid!) == cardUidClean) {
          lecturer = cachedLecturer;
          nfcLoginCardUid = cardUidClean;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint("Error in loginWithNfc: $e");
    }

    return false;
  }

  Future<void> signOutLecturer() async {
    lecturer = null;
    nfcLoginCardUid = null;
    // We do NOT clear cachedLecturerId, cachedPassword, or cachedLecturer,
    // so they remain available for offline login even after signing out.
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lecturer');
    await prefs.remove('nfcLoginCardUid');
    
    notifyListeners();
  }
}

class DiscoveredServer {
  final String ip;
  final String name;
  final String token;

  DiscoveredServer({
    required this.ip,
    required this.name,
    required this.token,
  });
}

