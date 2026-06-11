<?php
require_once 'db_connect.php';

// Check if request is POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["success" => false, "message" => "Method Not Allowed"]);
    exit;
}

// Retrieve POST fields
$cardUid = $_POST['card_uid'] ?? null;

if (!$cardUid) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Missing required fields"]);
    exit;
}

// Query lecturer by card_uid
$stmt = $conn->prepare("SELECT lecturer_id, name, email, department, office, phone, card_uid FROM lecturers WHERE REPLACE(REPLACE(UPPER(card_uid), ':', ''), ' ', '') = ?");
$stmt->bind_param("s", $cardUid);
$stmt->execute();
$result = $stmt->get_result();

if ($result && $result->num_rows > 0) {
    $row = $result->fetch_assoc();
    echo json_encode([
        "success" => true,
        "message" => "Login successful",
        "lecturer" => $row
    ]);
} else {
    http_response_code(401);
    echo json_encode(["success" => false, "message" => "Invalid NFC card or not registered to a lecturer"]);
}

$stmt->close();
$conn->close();
?>
