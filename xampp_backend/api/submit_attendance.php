<?php
require_once 'db_connect.php';

// Check if request is POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["success" => false, "message" => "Method Not Allowed"]);
    exit;
}

// Get raw JSON payload
$json = file_get_contents('php://input');
$data = json_decode($json, true);

if (!$data) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Invalid JSON payload"]);
    exit;
}

$sessionId = $data['id'] ?? null;
$subjectCode = $data['subjectCode'] ?? null;
$subjectName = $data['subjectName'] ?? null;
$room = $data['room'] ?? null;
$startTime = $data['startTime'] ?? null;
$endTime = $data['endTime'] ?? null;
$totalEnrolled = $data['totalEnrolled'] ?? 0;
$scannedStudents = $data['scannedStudents'] ?? [];
$presentCount = count($scannedStudents);

if (!$sessionId || !$subjectCode || !$subjectName || !$room || !$startTime || !$endTime) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Missing required session fields"]);
    exit;
}

// Convert ISO8601 to SQL friendly datetime formats
$startDateTime = date('Y-m-d H:i:s', strtotime($startTime));
$endDateTime = date('Y-m-d H:i:s', strtotime($endTime));

// Start transaction
$conn->begin_transaction();

try {
    // 1. Insert or update session record
    $stmt = $conn->prepare("INSERT INTO sessions (session_id, subject_code, subject_name, room, start_time, end_time, total_enrolled, present_count) VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE subject_code = VALUES(subject_code), subject_name = VALUES(subject_name), room = VALUES(room), start_time = VALUES(start_time), end_time = VALUES(end_time), total_enrolled = VALUES(total_enrolled), present_count = VALUES(present_count)");
    $stmt->bind_param("ssssssii", $sessionId, $subjectCode, $subjectName, $room, $startDateTime, $endDateTime, $totalEnrolled, $presentCount);
    $stmt->execute();
    $stmt->close();

    // 2. Clear old attendance records for this session to handle updates/re-saves correctly
    $stmt = $conn->prepare("DELETE FROM attendance WHERE session_id = ?");
    $stmt->bind_param("s", $sessionId);
    $stmt->execute();
    $stmt->close();

    // 3. Insert new attendance records
    if ($presentCount > 0) {
        $stmt = $conn->prepare("INSERT INTO attendance (session_id, student_id, student_name, card_uid, scan_time) VALUES (?, ?, ?, ?, ?)");
        foreach ($scannedStudents as $student) {
            $studentId = $student['id'] ?? '';
            $studentName = $student['name'] ?? '';
            $cardUid = $student['deviceId'] ?? '';
            $scanTime = $student['scanTime'] ?? date('Y-m-d H:i:s');
            
            // Format scanTime
            $formattedScanTime = date('Y-m-d H:i:s', strtotime($scanTime));
            
            $stmt->bind_param("sssss", $sessionId, $studentId, $studentName, $cardUid, $formattedScanTime);
            $stmt->execute();
        }
        $stmt->close();
    }

    // Commit transaction
    $conn->commit();
    echo json_encode(["success" => true, "message" => "Attendance session submitted successfully"]);
} catch (Exception $e) {
    // Rollback on error
    $conn->rollback();
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database operation failed: " . $e->getMessage()]);
}

$conn->close();
?>
