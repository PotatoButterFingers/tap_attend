import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tap_attend/models/class_session.dart';

class ExportUtils {
  static Future<void> exportSessionToCSV(ClassSession session) async {
    List<List<dynamic>> rows = [];

    // Check which students are present
    final presentStudentIds = session.scannedStudents.map((s) => s.id).toSet();

    // Headers
    rows.add([
      "Subject Code",
      "Subject Name",
      "Date",
      "Time",
      "Total Enrolled",
      "Total Attended",
    ]);

    // Metadata Row
    rows.add([
      session.subjectCode,
      session.subjectName,
      "${session.startTime.year}-${session.startTime.month}-${session.startTime.day}",
      session.timeString,
      session.totalEnrolled,
      session.scannedStudents.length,
    ]);

    rows.add([]); // Empty row

    // Student Headers
    rows.add(["Student ID", "Name", "NFC Tag", "Status", "Scan Time"]);

    // Student Data
    for (var student in session.students) {
      bool isPresent = presentStudentIds.contains(student.id);
      String scanTimeStr = "";
      if (isPresent) {
        // Find scan time
        final scannedInfo = session.scannedStudents.firstWhere(
          (s) => s.id == student.id,
        );
        if (scannedInfo.scanTime != null) {
          scanTimeStr =
              "${scannedInfo.scanTime!.hour}:${scannedInfo.scanTime!.minute}:${scannedInfo.scanTime!.second}";
        }
      }

      rows.add([
        student.id,
        student.name,
        student.deviceId,
        isPresent ? "Present" : "Absent",
        scanTimeStr,
      ]);
    }

    String csvData = const CsvEncoder().convert(rows);

    final directory = await getApplicationDocumentsDirectory();
    final path =
        "${directory.path}/Attendance_${session.subjectCode}_${session.startTime.millisecondsSinceEpoch}.csv";
    final file = File(path);
    await file.writeAsString(csvData);

    // Share the file
    final xFile = XFile(path);
    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        text: "Attendance report for ${session.subjectCode}",
      ),
    );
  }
}
