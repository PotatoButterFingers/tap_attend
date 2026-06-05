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

if (!$id) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Missing session ID"]);
    exit;
}

// Delete session (cascade will delete attendance automatically)
$stmt = $conn->prepare("DELETE FROM sessions WHERE session_id = ?");
$stmt->bind_param("s", $id);

if ($stmt->execute()) {
    echo json_encode(["success" => true, "message" => "Session deleted successfully"]);
} else {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database deletion failed: " . $stmt->error]);
}

$stmt->close();
$conn->close();
?>
