<?php
require_once 'db_connect.php';

// Check if request is GET
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(["success" => false, "message" => "Method Not Allowed"]);
    exit;
}

$sql = "SELECT session_id AS id, subject_code AS subjectCode, subject_name AS subjectName, room, start_time AS startTime, end_time AS endTime, total_enrolled AS totalEnrolled FROM sessions ORDER BY start_time ASC";
$result = $conn->query($sql);

$sessions = [];
if ($result) {
    while ($row = $result->fetch_assoc()) {
        $sessionId = $row['id'];
        $subjectCode = $row['subjectCode'];
        
        // Format times to ISO8601
        $row['startTime'] = date('c', strtotime($row['startTime']));
        $row['endTime'] = date('c', strtotime($row['endTime']));
        
        // Hardcode score fallback for UI compatibility
        $row['previousAverageScore'] = 85;
        
        // Fetch all enrolled students for this class code from the students table
        $studentsQuery = $conn->prepare("SELECT id, name, card_uid AS deviceId FROM students WHERE subject_code = ?");
        $studentsQuery->bind_param("s", $subjectCode);
        $studentsQuery->execute();
        $studentsResult = $studentsQuery->get_result();
        
        $enrolledStudents = [];
        while ($studentRow = $studentsResult->fetch_assoc()) {
            $studentRow['isVerified'] = true;
            $studentRow['scanTime'] = null;
            $enrolledStudents[] = $studentRow;
        }
        $studentsQuery->close();
        $row['students'] = $enrolledStudents;
        
        // Fetch scanned students for this session from the attendance table
        $attendanceQuery = $conn->prepare("SELECT student_id AS id, student_name AS name, card_uid AS deviceId, scan_time AS scanTime FROM attendance WHERE session_id = ? ORDER BY scan_time DESC");
        $attendanceQuery->bind_param("s", $sessionId);
        $attendanceQuery->execute();
        $attendanceResult = $attendanceQuery->get_result();
        
        $scannedStudents = [];
        while ($attRow = $attendanceResult->fetch_assoc()) {
            $attRow['isVerified'] = true;
            $attRow['scanTime'] = date('c', strtotime($attRow['scanTime']));
            $scannedStudents[] = $attRow;
        }
        $attendanceQuery->close();
        $row['scannedStudents'] = $scannedStudents;
        
        $sessions[] = $row;
    }
}

echo json_encode($sessions);
$conn->close();
?>
