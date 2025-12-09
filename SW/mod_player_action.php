<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

$action = $_POST['action'] ?? '';
$session_id = $_POST['session_id'] ?? '';
$timestamp = $_POST['timestamp'] ?? time();

// File untuk menyimpan data (atau gunakan database)
$data_file = 'active_players.json';

// Baca data yang ada
$active_players = [];
if (file_exists($data_file)) {
    $json_data = file_get_contents($data_file);
    $active_players = json_decode($json_data, true) ?: [];
}

// Hapus player yang sudah tidak aktif (lebih dari 5 menit)
$current_time = time();
$timeout = 300; // 5 menit
foreach ($active_players as $id => $player) {
    if (($current_time - $player['last_seen']) > $timeout) {
        unset($active_players[$id]);
    }
}

if ($action === 'login') {
    // Tambah atau update player
    $active_players[$session_id] = [
        'session_id' => $session_id,
        'login_time' => $timestamp,
        'last_seen' => $current_time
    ];
} elseif ($action === 'logout') {
    // Hapus player
    unset($active_players[$session_id]);
}

// Simpan data kembali
file_put_contents($data_file, json_encode($active_players));

// Return count
echo json_encode([
    'success' => true,
    'active_count' => count($active_players),
    'action' => $action
]);
?>
