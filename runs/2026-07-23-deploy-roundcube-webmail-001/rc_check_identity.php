<?php
$pdo = new PDO('sqlite:/var/roundcube/db/roundcube.db');

echo "=== Tables ===\n";
foreach ($pdo->query("SELECT name FROM sqlite_master WHERE type='table'") as $r)
    echo $r['name'] . "\n";

echo "\n=== Users ===\n";
try {
    foreach ($pdo->query('SELECT * FROM rc_users LIMIT 10') as $r)
        echo "uid={$r['user_id']} | username=[{$r['username']}] | host={$r['mail_host']}\n";
} catch (Exception $e) { echo "rc_users error: " . $e->getMessage() . "\n"; }

echo "\n=== Identities ===\n";
try {
    foreach ($pdo->query('SELECT * FROM rc_identities LIMIT 20') as $r)
        echo "id={$r['identity_id']} | uid={$r['user_id']} | name=[{$r['name']}] | email=[{$r['email']}] | default={$r['standard']}\n";
} catch (Exception $e) { echo "rc_identities error: " . $e->getMessage() . "\n"; }
