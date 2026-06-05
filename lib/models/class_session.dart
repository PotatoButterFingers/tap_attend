import 'package:tap_attend/models/student.dart';

class ClassSession {
  final String id;
  final String subjectCode;
  final String subjectName;
  final String room;
  final DateTime startTime;
  final DateTime endTime;
  final int totalEnrolled;
  final int previousAverageScore; 
  final List<Student> students; // List of all enrolled students
  final List<Student> scannedStudents; // Students who have tapped their NFC

  ClassSession({
    required this.id,
    required this.subjectCode,
    required this.subjectName,
    required this.room,
    required this.startTime,
    required this.endTime,
    required this.totalEnrolled,
    required this.previousAverageScore,
    required this.students,
    this.scannedStudents = const [],
  });

  String get timeString {
    final startStr = _formatTime(startTime);
    final endStr = _formatTime(endTime);
    final diff = endTime.difference(startTime).inMinutes;
    return '$startStr - $endStr ($diff mins)';
  }

  String _formatTime(DateTime time) {
    int hour = time.hour;
    int min = time.minute;
    String ampm = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    String minStr = min < 10 ? '0$min' : '$min';
    return '$hour:$minStr $ampm';
  }

  ClassSession copyWith({
    List<Student>? scannedStudents,
  }) {
    return ClassSession(
      id: id,
      subjectCode: subjectCode,
      subjectName: subjectName,
      room: room,
      startTime: startTime,
      endTime: endTime,
      totalEnrolled: totalEnrolled,
      previousAverageScore: previousAverageScore,
      students: students,
      scannedStudents: scannedStudents ?? this.scannedStudents,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjectCode': subjectCode,
      'subjectName': subjectName,
      'room': room,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'totalEnrolled': totalEnrolled,
      'previousAverageScore': previousAverageScore,
      'students': students.map((e) => e.toJson()).toList(),
      'scannedStudents': scannedStudents.map((e) => e.toJson()).toList(),
    };
  }

  factory ClassSession.fromJson(Map<String, dynamic> json) {
    return ClassSession(
      id: json['id'],
      subjectCode: json['subjectCode'],
      subjectName: json['subjectName'],
      room: json['room'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      totalEnrolled: json['totalEnrolled'],
      previousAverageScore: json['previousAverageScore'],
      students: (json['students'] as List).map((e) => Student.fromJson(e)).toList(),
      scannedStudents: (json['scannedStudents'] as List).map((e) => Student.fromJson(e)).toList(),
    );
  }
}
