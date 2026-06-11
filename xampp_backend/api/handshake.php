<?php
require_once 'db_connect.php';

$configFile = __DIR__ . '/server_config.json';

if (file_exists($configFile)) {
    $config = json_decode(file_get_contents($configFile), true);
} else {
    $config = [];
}

// Generate unique server token if it doesn't exist
if (!isset($config['server_token']) || empty($config['server_token'])) {
    // Generate a secure random token
    $config['server_token'] = bin2hex(random_bytes(16));
    file_put_contents($configFile, json_encode($config, JSON_PRETTY_PRINT));
}

// Get computer hostname
$hostname = gethostname();
if (!$hostname) {
    $hostname = "Tap Attend Server";
}

echo json_encode([
    "success" => true,
    "app" => "tap_attend",
    "server_name" => $hostname,
    "server_token" => $config['server_token']
]);
?>
