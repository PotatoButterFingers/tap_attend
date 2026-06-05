<?php
require_once 'db_connect.php';

// Check if request is GET
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(["success" => false, "message" => "Method Not Allowed"]);
    exit;
}

$sql = "SELECT id, name, card_uid AS deviceId, subject_code AS subjectCode FROM students";
$result = $conn->query($sql);

$students = [];
if ($result) {
    while ($row = $result->fetch_assoc()) {
        $row['isVerified'] = true; // Set isVerified to true for all students in directory
        $students[] = $row;
    }
}

echo json_encode($students);
$conn->close();
?>
