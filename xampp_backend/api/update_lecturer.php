<?php
require_once 'db_connect.php';

// Check if request is POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["success" => false, "message" => "Method Not Allowed"]);
    exit;
}

// Retrieve POST fields
$lecturerId = $_POST['lecturer_id'] ?? null;
$name = $_POST['name'] ?? null;
$email = $_POST['email'] ?? null;
$department = $_POST['department'] ?? null;
$office = $_POST['office'] ?? null;
$phone = $_POST['phone'] ?? null;
$cardUid = $_POST['card_uid'] ?? null;

if (!$lecturerId || !$name || !$email || !$department || !$office || !$phone) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Missing required fields"]);
    exit;
}

// Update lecturer in database
$stmt = $conn->prepare("UPDATE lecturers SET name = ?, email = ?, department = ?, office = ?, phone = ?, card_uid = ? WHERE lecturer_id = ?");
$stmt->bind_param("sssssss", $name, $email, $department, $office, $phone, $cardUid, $lecturerId);

if ($stmt->execute()) {
    echo json_encode(["success" => true, "message" => "Lecturer profile updated successfully"]);
} else {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database update failed: " . $stmt->error]);
}

$stmt->close();
$conn->close();
?>
