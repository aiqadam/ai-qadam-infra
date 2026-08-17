#!/usr/bin/env php
<?php
$pdo = new PDO('sqlite:/var/roundcube/db/sqlite.db');

echo "=== Tables ===\n";
foreach ($pdo->query("SELECT name FROM sqlite_master WHERE type='table'") as $r)
    echo $r['name'] . "\n";

echo "\n=== Users ===\n";
foreach ($pdo->query('SELECT user_id, username, mail_host FROM users LIMIT 10') as $r)
    echo "uid={$r['user_id']} | username=[{$r['username']}] | host={$r['mail_host']}\n";

echo "\n=== Identities ===\n";
foreach ($pdo->query('SELECT identity_id, user_id, name, email, "standard" FROM identities LIMIT 20') as $r)
    echo "id={$r['identity_id']} | uid={$r['user_id']} | name=[{$r['name']}] | email=[{$r['email']}] | default={$r['standard']}\n";
