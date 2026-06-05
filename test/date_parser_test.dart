import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_attend/providers/attendance_provider.dart';
import 'package:tap_attend/utils/date_parser.dart';
import 'package:tap_attend/models/student.dart';
import 'package:tap_attend/models/class_session.dart';

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
}
