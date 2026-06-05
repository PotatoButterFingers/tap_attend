<?php
require_once 'db_connect.php';

// Check if request is POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["success" => false, "message" => "Method Not Allowed"]);
    exit;
}

// Retrieve POST fields
$id = $_POST['id'] ?? null;
$name = $_POST['name'] ?? null;
$deviceId = $_POST['deviceId'] ?? null; // cardUid
$subjectCode = $_POST['subjectCode'] ?? null;

if (!$id || !$name || !$deviceId || !$subjectCode) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Missing required fields"]);
    exit;
}

// Insert or replace student
$stmt = $conn->prepare("INSERT INTO students (id, name, card_uid, subject_code) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name), card_uid = VALUES(card_uid), subject_code = VALUES(subject_code)");
$stmt->bind_param("ssss", $id, $name, $deviceId, $subjectCode);

if ($stmt->execute()) {
    echo json_encode(["success" => true, "message" => "Student registered successfully"]);
} else {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database insertion failed: " . $stmt->error]);
}

$stmt->close();
$conn->close();
?>
