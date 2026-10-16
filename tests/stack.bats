#!/usr/bin/env bats
# The stack on a machine (handbook decision 0059): nginx, PHP-FPM and
# MariaDB of Debian 13 running under systemd, the overlay files of this
# layer in place, firstboot.d/40lnmp-check run once, and a default server
# that includes /etc/nginx/keel-default.d/ as keel-web 0.3.0 does. The
# stack job of .forgejo/workflows/tests.yml sets that up on a disposable
# trixie container and runs this suite as root with LNMP_STACK_TEST=1.
# Anywhere else every test skips: the suite stops and starts MariaDB.

bats_require_minimum_version 1.5.0

setup() {
    if [ "${LNMP_STACK_TEST:-}" != 1 ] || [ "$(id -u)" -ne 0 ]; then
        skip "the stack test runs as root where LNMP_STACK_TEST=1 (the stack job)"
    fi
    REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    HOOK="$REPO/overlay/usr/lib/inithooks/firstboot.d/40lnmp-check"
    PAGE_DIR=/usr/share/keel-lnmp/www/keel-check
}

code() {
    curl -sk -o /dev/null -w '%{http_code}' "$@"
}

rows() {
    mariadb --batch --skip-column-names -e 'SELECT COUNT(*) FROM keel_check.boot'
}

@test "nginx accepts the configuration with the route" {
    run nginx -t
    [ "$status" -eq 0 ]
}

@test "PHP-FPM listens on Debian's socket of the default version" {
    [ -S /run/php/php8.4-fpm.sock ]
    [ "$(readlink -f /run/php/php-fpm.sock)" = /run/php/php8.4-fpm.sock ]
}

@test "/keel-check redirects to /keel-check/" {
    [ "$(code http://127.0.0.1/keel-check)" = 301 ]
    run curl -s -o /dev/null -w '%{redirect_url}' http://127.0.0.1/keel-check
    [ "$output" = http://127.0.0.1/keel-check/ ]
}

@test "the check page answers over HTTPS with PHP 8.4, MariaDB 11.8 and a writable server" {
    [ "$(code https://127.0.0.1/keel-check/)" = 200 ]
    run curl -sk https://127.0.0.1/keel-check/
    [[ "$output" == *"nginx, PHP and MariaDB answer"* ]]
    [[ "$output" == *"<th>PHP</th><td>8.4."* ]]
    [[ "$output" == *"<th>MariaDB</th><td>11.8."* ]]
    [[ "$output" == *"writable (primary or standalone)"* ]]
}

@test "the check page shows the row the first boot wrote for this host" {
    run curl -sk https://127.0.0.1/keel-check/
    [[ "$output" == *"<td>$(hostname)</td>"* ]]
    [ "$(rows)" = 1 ]
}

@test "the check page answers on the IPv6 loopback too" {
    [ "$(code 'https://[::1]/keel-check/')" = 200 ]
}

@test "a second run of the hook writes no second row" {
    run "$HOOK"
    [ "$status" -eq 0 ]
    [ "$(rows)" = 1 ]
}

@test "the account of the page may read the check database and write nothing" {
    run runuser -u www-data -- mariadb --batch --skip-column-names -e 'SELECT COUNT(*) FROM keel_check.boot'
    [ "$status" -eq 0 ]
    [ "$output" = 1 ]
    run runuser -u www-data -- mariadb -e "INSERT INTO keel_check.boot VALUES ('x', NOW())"
    [ "$status" -ne 0 ]
    run runuser -u www-data -- mariadb -e 'SELECT COUNT(*) FROM mysql.user'
    [ "$status" -ne 0 ]
}

@test "a read-only server: the hook writes nothing, and the page says read-only" {
    mariadb -e 'SET GLOBAL read_only = 1'
    run "$HOOK"
    mariadb -e 'SET GLOBAL read_only = 0' || true
    [ "$status" -eq 0 ]
    [[ "$output" == *"read-only"* ]]
    mariadb -e 'SET GLOBAL read_only = 1'
    run curl -sk https://127.0.0.1/keel-check/
    mariadb -e 'SET GLOBAL read_only = 0'
    [[ "$output" == *"read-only (replica)"* ]]
}

@test "the hook writes nothing to the binary log" {
    if [ "$(mariadb --batch --skip-column-names -e 'SELECT @@log_bin')" != 1 ]; then
        skip "the binary log is off on this server"
    fi
    before="$(mariadb --batch --skip-column-names -e 'SELECT @@gtid_binlog_pos')"
    run "$HOOK"
    [ "$status" -eq 0 ]
    [ "$(mariadb --batch --skip-column-names -e 'SELECT @@gtid_binlog_pos')" = "$before" ]
}

@test "no other PHP file under the page's directory runs" {
    printf '<?php echo "ran-" . "php";\n' > "$PAGE_DIR/other.php"
    run curl -sk https://127.0.0.1/keel-check/other.php
    rm -f "$PAGE_DIR/other.php"
    [[ "$output" != *"ran-php"* ]]
}

@test "MariaDB listens on the two loopback addresses only" {
    run bash -c "ss -Hltn 'sport = :3306' | awk '{print \$4}' | sort"
    [ "$output" = $'127.0.0.1:3306\n[::1]:3306' ]
}

@test "with MariaDB stopped the page answers 503 with one line" {
    systemctl stop mariadb.service
    status_code="$(code https://127.0.0.1/keel-check/)"
    body="$(curl -sk https://127.0.0.1/keel-check/)"
    systemctl start mariadb.service
    [ "$status_code" = 503 ]
    [[ "$body" == "MariaDB did not answer the check page"* ]]
}

@test "the page does not name PHP in its headers" {
    run curl -skI https://127.0.0.1/keel-check/
    [[ "$output" != *"X-Powered-By"* ]]
}
