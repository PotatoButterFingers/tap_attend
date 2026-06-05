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
$password = $_POST['password'] ?? null;

if (!$lecturerId || !$password) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Missing required fields"]);
    exit;
}

// Query lecturer
$stmt = $conn->prepare("SELECT lecturer_id, name, email, password_hash, department, office, phone, card_uid FROM lecturers WHERE lecturer_id = ?");
$stmt->bind_param("s", $lecturerId);
$stmt->execute();
$result = $stmt->get_result();

if ($result && $result->num_rows > 0) {
    $row = $result->fetch_assoc();
    
    // Verify password using bcrypt
    if (password_verify($password, $row['password_hash'])) {
        // Remove password hash from response
        unset($row['password_hash']);
        
        echo json_encode([
            "success" => true,
            "message" => "Login successful",
            "lecturer" => $row
        ]);
    } else {
        http_response_code(401);
        echo json_encode(["success" => false, "message" => "Invalid password"]);
    }
} else {
    http_response_code(401);
    echo json_encode(["success" => false, "message" => "Invalid Lecturer ID"]);
}

$stmt->close();
$conn->close();
?>
