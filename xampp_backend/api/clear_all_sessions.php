<?php
require_once 'db_connect.php';

// Check if request is POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["success" => false, "message" => "Method Not Allowed"]);
    exit;
}

// Clear all sessions (cascade will clear attendance automatically)
if ($conn->query("DELETE FROM sessions")) {
    echo json_encode(["success" => true, "message" => "All sessions cleared successfully"]);
} else {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database clear failed: " . $conn->error]);
}

$conn->close();
?>
