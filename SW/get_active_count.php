<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

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
$updated = false;

foreach ($active_players as $id => $player) {
    if (($current_time - $player['last_seen']) > $timeout) {
        unset($active_players[$id]);
        $updated = true;
    }
}

// Simpan jika ada perubahan
if ($updated) {
    file_put_contents($data_file, json_encode($active_players));
}

echo json_encode([
    'active_count' => count($active_players),
    'timestamp' => $current_time
]);
?>
