<?php
// keel-lnmp: the check page of Keel LNMP (handbook decision 0059, point 6).
//
// It proves each layer: nginx gave the request to PHP-FPM, PHP connected to
// MariaDB, and MariaDB answered. It shows the versions, the role of the
// server (writable, or read-only on a replica) and the rows that
// firstboot.d/40lnmp-check wrote. On a pair, the row on the replica comes
// from the primary, so the page also proves the replication.
//
// It only reads. Its account is www-data on localhost, which the server
// knows by the socket (unix_socket), with SELECT on keel_check alone.
// Every value is escaped with h() before it is shown.

declare(strict_types=1);

function h(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

mysqli_report(MYSQLI_REPORT_OFF);
header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: no-store');
header_remove('X-Powered-By');

$db = @new mysqli('localhost', 'www-data', '', 'keel_check');
if ($db->connect_errno) {
    http_response_code(503);
    echo h('MariaDB did not answer the check page (error ' . $db->connect_errno . ').'), "\n";
    exit;
}

$server = $db->query('SELECT VERSION(), @@global.read_only, @@hostname')->fetch_row();
$rows = [];
$result = $db->query('SELECT host, written_at FROM boot ORDER BY written_at');
if ($result !== false) {
    $rows = $result->fetch_all();
}
$role = $server[1] === '0' ? 'writable (primary or standalone)' : 'read-only (replica)';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Keel LNMP check</title>
<style>
body { font-family: sans-serif; margin: 2rem auto; max-width: 40rem; padding: 0 1rem; color: #1b2733; }
h1 { font-size: 1.4rem; }
table { border-collapse: collapse; width: 100%; margin-bottom: 1.5rem; }
th, td { text-align: left; padding: 0.4rem 0.6rem; border-bottom: 1px solid #d0d7de; }
.ok { color: #116329; font-weight: bold; }
</style>
</head>
<body>
<h1>Keel LNMP: <span class="ok">nginx, PHP and MariaDB answer</span></h1>
<table>
<tr><th>PHP</th><td><?php echo h(PHP_VERSION); ?></td></tr>
<tr><th>MariaDB</th><td><?php echo h((string) $server[0]); ?></td></tr>
<tr><th>Database server</th><td><?php echo h((string) $server[2]); ?></td></tr>
<tr><th>Role</th><td><?php echo h($role); ?></td></tr>
</table>
<h2>Rows written at the first boot</h2>
<table>
<tr><th>Host</th><th>Written at</th></tr>
<?php foreach ($rows as $row): ?>
<tr><td><?php echo h((string) $row[0]); ?></td><td><?php echo h((string) $row[1]); ?></td></tr>
<?php endforeach; ?>
</table>
</body>
</html>
