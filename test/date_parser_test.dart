import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_attend/providers/attendance_provider.dart';
import 'package:tap_attend/utils/date_parser.dart';
import 'package:tap_attend/models/student.dart';
import 'package:tap_attend/models/class_session.dart';
import 'package:tap_attend/models/lecturer.dart';

void main() {
  group('DateParser.parseTimezoneIndependent', () {
    test('should parse ISO 8601 with positive timezone offset correctly', () {
      final parsed = DateParser.parseTimezoneIndependent('2026-06-05T10:00:00+08:00');
      expect(parsed.year, equals(2026));
      expect(parsed.month, equals(6));
      expect(parsed.day, equals(5));
      expect(parsed.hour, equals(10));
      expect(parsed.minute, equals(0));
      expect(parsed.second, equals(0));
    });

    test('should parse ISO 8601 with negative timezone offset correctly', () {
      final parsed = DateParser.parseTimezoneIndependent('2026-06-05T10:00:00-05:00');
      expect(parsed.year, equals(2026));
      expect(parsed.month, equals(6));
      expect(parsed.day, equals(5));
      expect(parsed.hour, equals(10));
      expect(parsed.minute, equals(0));
      expect(parsed.second, equals(0));
    });

    test('should parse ISO 8601 with Z (UTC) timezone offset correctly', () {
      final parsed = DateParser.parseTimezoneIndependent('2026-06-05T10:00:00Z');
      expect(parsed.year, equals(2026));
      expect(parsed.month, equals(6));
      expect(parsed.day, equals(5));
      expect(parsed.hour, equals(10));
      expect(parsed.minute, equals(0));
      expect(parsed.second, equals(0));
    });

    test('should parse ISO 8601 with milliseconds and timezone offset correctly', () {
      final parsed = DateParser.parseTimezoneIndependent('2026-06-05T10:00:00.123+08:00');
      expect(parsed.year, equals(2026));
      expect(parsed.month, equals(6));
      expect(parsed.day, equals(5));
      expect(parsed.hour, equals(10));
      expect(parsed.minute, equals(0));
      expect(parsed.second, equals(0));
    });

    test('should parse standard datetime string without offset correctly', () {
      final parsed = DateParser.parseTimezoneIndependent('2026-06-05 10:00:00');
      expect(parsed.year, equals(2026));
      expect(parsed.month, equals(6));
      expect(parsed.day, equals(5));
      expect(parsed.hour, equals(10));
      expect(parsed.minute, equals(0));
      expect(parsed.second, equals(0));
    });

    test('should successfully match parsed session date with selected date', () {
      final serverResponseTime = '2026-06-05T10:00:00+02:00';
      final parsedStartTime = DateParser.parseTimezoneIndependent(serverResponseTime);
      final selectedDate = DateTime(2026, 6, 5); // June 5th, 2026
      
      final matches = parsedStartTime.year == selectedDate.year &&
                      parsedStartTime.month == selectedDate.month &&
                      parsedStartTime.day == selectedDate.day;
                      
      expect(matches, isTrue);
    });
  });

  group('Model Resilience Tests', () {
    test('Student.fromJson should handle numeric IDs and integer verification flags correctly', () {
      final json = {
        'id': 101, // Numeric ID instead of String
        'name': 'Sophia Chen',
        'deviceId': 'tag_2',
        'scanTime': '2026-06-05T18:37:52+02:00',
        'isVerified': 1 // Integer flag instead of boolean
      };

      final student = Student.fromJson(json);
      expect(student.id, equals('101'));
      expect(student.name, equals('Sophia Chen'));
      expect(student.deviceId, equals('tag_2'));
      expect(student.isVerified, isTrue);
      expect(student.scanTime?.year, equals(2026));
      expect(student.scanTime?.month, equals(6));
      expect(student.scanTime?.day, equals(5));
    });

    test('ClassSession.fromJson should handle String representations of totalEnrolled and previousAverageScore', () {
      final json = {
        'id': 'past_CS101_20260605',
        'subjectCode': 'CS101',
        'subjectName': 'Computer Science 101',
        'room': 'Lab 3, Engineering Building',
        'startTime': '2026-06-05T10:00:00+02:00',
        'endTime': '2026-06-05T11:30:00+02:00',
        'totalEnrolled': '3', // String representation
        'previousAverageScore': '85', // String representation
        'students': [],
        'scannedStudents': []
      };

      final session = ClassSession.fromJson(json);
      expect(session.id, equals('past_CS101_20260605'));
      expect(session.totalEnrolled, equals(3));
      expect(session.previousAverageScore, equals(85));
    });

    test('Lecturer.fromJson and toJson should serialize id and cardUid properly', () {
      final json = {
        'lecturer_id': 'sharvin',
        'name': 'Mr. Sharvin Ganeson',
        'department': 'Dept. of Computer Science',
        'email': 'sharvin.ganeson@university.edu',
        'phone': '+1 (555) 123-4567',
        'office': 'Engineering Bldg, Room 402',
        'card_uid': 'lecturer_card_1'
      };

      final lecturer = Lecturer.fromJson(json);
      expect(lecturer.id, equals('sharvin'));
      expect(lecturer.name, equals('Mr. Sharvin Ganeson'));
      expect(lecturer.cardUid, equals('lecturer_card_1'));

      final serialized = lecturer.toJson();
      expect(serialized['id'], equals('sharvin'));
      expect(serialized['name'], equals('Mr. Sharvin Ganeson'));
      expect(serialized['card_uid'], equals('lecturer_card_1'));
    });
  });

  group('Lecturer Authentication Cache Tests', () {
    test('signOutLecturer should clear active session but preserve cached credentials', () async {
      SharedPreferences.setMockInitialValues({
        'cachedLecturerId': 'sharvin',
        'cachedPassword': 'Secret123',
        'cachedLecturer': jsonEncode({
          'name': 'Mr. Sharvin Ganeson',
          'department': 'Dept. of Computer Science',
          'email': 'sharvin.ganeson@university.edu',
          'phone': '+1 (555) 123-4567',
          'office': 'Engineering Bldg, Room 402'
        }),
        'lecturer': jsonEncode({
          'name': 'Mr. Sharvin Ganeson',
          'department': 'Dept. of Computer Science',
          'email': 'sharvin.ganeson@university.edu',
          'phone': '+1 (555) 123-4567',
          'office': 'Engineering Bldg, Room 402'
        })
      });

      final provider = AttendanceProvider();
      await provider.initializationFuture;

      expect(provider.lecturer, isNotNull);
      expect(provider.lecturer!.name, equals('Mr. Sharvin Ganeson'));
      expect(provider.cachedLecturerId, equals('sharvin'));
      expect(provider.cachedPassword, equals('Secret123'));

      await provider.signOutLecturer();

      expect(provider.lecturer, isNull);
      expect(provider.cachedLecturerId, equals('sharvin'));
      expect(provider.cachedPassword, equals('Secret123'));

      provider.isServerConnectionActive = false;
      final loginSuccess = await provider.loginLecturer('sharvin', 'Secret123');
      expect(loginSuccess, isTrue);
      
      expect(provider.lecturer, isNotNull);
      expect(provider.lecturer!.name, equals('Mr. Sharvin Ganeson'));
    });
  });

  group('Session History Multiple and Deletion Tests', () {
    test('Offline multiple sessions should have different IDs and deleting one should preserve the other', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider();
      await provider.initializationFuture;

      // Clear any default mock sessions
      provider.pastSessions.clear();

      // 1. Load and end first session
      provider.loadSessionByCode('CS101');
      final firstSessionId = provider.currentSession!.id;
      await provider.finishSession();

      // Wait 2ms to ensure timestamp difference
      await Future.delayed(const Duration(milliseconds: 2));

      // 2. Load and end second session
      provider.loadSessionByCode('CS101');
      final secondSessionId = provider.currentSession!.id;
      await provider.finishSession();

      // Verify they have different IDs
      expect(firstSessionId, isNot(equals(secondSessionId)));
      expect(provider.pastSessions.length, equals(2));
      expect(provider.pastSessions[0].id, equals(firstSessionId));
      expect(provider.pastSessions[1].id, equals(secondSessionId));

      // 3. Delete the second session
      await provider.deletePastSession(secondSessionId);

      // Verify only the second session is deleted and the first remains
      expect(provider.pastSessions.length, equals(1));
      expect(provider.pastSessions[0].id, equals(firstSessionId));
    });

    test('deletedSessionIds should persist and filter out matching session IDs', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider();
      await provider.initializationFuture;

      provider.pastSessions.clear();
      provider.deletedSessionIds.clear();

      final session = ClassSession(
        id: 's1_999999',
        subjectCode: 'CS101',
        subjectName: 'Computer Science 101',
        room: 'Lab 3, Engineering Building',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        totalEnrolled: 3,
        previousAverageScore: 88,
        students: [],
      );

      provider.pastSessions.add(session);
      await provider.deletePastSession('s1_999999');

      expect(provider.pastSessions, isEmpty);
      expect(provider.deletedSessionIds, contains('s1_999999'));

      // Simulate a reload by starting a new provider instance
      final provider2 = AttendanceProvider();
      await provider2.initializationFuture;

      expect(provider2.deletedSessionIds, contains('s1_999999'));
      expect(provider2.pastSessions, isEmpty);
    });

    test('Offline restoration of deleted session today should work and recover full session details', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider();
      await provider.initializationFuture;

      provider.pastSessions.clear();
      provider.deletedSessionIds.clear();
      provider.deletedSessionsCache.clear();

      final today = DateTime.now();
      final session = ClassSession(
        id: 's1_123456',
        subjectCode: 'CS101',
        subjectName: 'Computer Science 101',
        room: 'Lab 3, Engineering Building',
        startTime: today,
        endTime: today.add(const Duration(hours: 1)),
        totalEnrolled: 3,
        previousAverageScore: 88,
        students: [],
      );

      provider.pastSessions.add(session);
      await provider.deletePastSession('s1_123456');

      expect(provider.pastSessions, isEmpty);
      expect(provider.deletedSessionIds, contains('s1_123456'));
      expect(provider.deletedSessionsCache.length, equals(1));

      // Simulate being offline and tapping the card to take attendance today
      // This will trigger checkAndFetchSessionFromServer which should restore from local cache!
      final restoredSession = await provider.checkAndFetchSessionFromServer('CS101', today);

      expect(restoredSession, isNotNull);
      expect(restoredSession!.id, equals('s1_123456'));
      expect(provider.pastSessions.length, equals(1));
      expect(provider.deletedSessionIds, isNot(contains('s1_123456')));
      expect(provider.deletedSessionsCache, isEmpty);
    });
  });
}

