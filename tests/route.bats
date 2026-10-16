#!/usr/bin/env bats
# The route of the check page and the page itself (handbook decision 0059,
# points 4 and 6). The route is a file of /etc/nginx/keel-default.d/, which
# keel-web 0.3.0 includes in its default site and in the server behind
# Anubis. These read the files; the stack job of tests.yml serves them with
# nginx, PHP-FPM and MariaDB and reads the page back.

bats_require_minimum_version 1.5.0

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    ROUTE="$REPO/overlay/etc/nginx/keel-default.d/50-keel-lnmp.conf"
    PAGE="$REPO/overlay/usr/share/keel-lnmp/www/keel-check/index.php"
}

# the route without its comments
route() {
    grep -vE '^\s*(#|$)' "$ROUTE"
}

@test "route: the file is in keel-web's include directory" {
    [ -f "$ROUTE" ]
}

@test "route: /keel-check redirects to /keel-check/" {
    route | grep -qF 'location = /keel-check {'
    route | grep -qF 'return 301 /keel-check/;'
}

@test "route: /keel-check/ is a prefix that no regular expression takes" {
    route | grep -qF 'location ^~ /keel-check/ {'
    route | grep -qF 'root /usr/share/keel-lnmp/www;'
    route | grep -qF 'index index.php;'
}

@test "route: PHP goes to PHP-FPM through Debian's socket of the default version" {
    route | grep -qF 'include snippets/fastcgi-php.conf;'
    route | grep -qF 'fastcgi_pass unix:/run/php/php-fpm.sock;'
}

@test "route: only index.php runs, no other file under the root" {
    route | grep -qF 'location = /keel-check/index.php {'
    run bash -c "grep -vE '^\s*(#|$)' '$ROUTE' | grep -c 'fastcgi_pass'"
    [ "$output" = 1 ]
}

@test "route: no server name, no listen: it is a part of the sites that include it" {
    run bash -c "grep -vE '^\s*(#|$)' '$ROUTE' | grep -cE '^\s*(server|listen|server_name)\b'"
    [ "$output" = 0 ]
}

@test "page: it reads only: no INSERT, UPDATE, DELETE, CREATE, DROP or GRANT" {
    run grep -iE '\b(INSERT|UPDATE|DELETE|CREATE|DROP|GRANT|ALTER)\b' "$PAGE"
    [ "$status" -ne 0 ]
}

@test "page: no phpinfo, no environment, no configuration" {
    run grep -iE 'phpinfo|getenv|\$_ENV|\$_SERVER|ini_get|php_uname' "$PAGE"
    [ "$status" -ne 0 ]
}

@test "page: it connects over the local socket as the user of PHP-FPM, with no password" {
    grep -qF "new mysqli('localhost', 'www-data', '', 'keel_check')" "$PAGE"
    run grep -iE 'password|passwd|DB_PASS' "$PAGE"
    [ "$status" -ne 0 ]
}

@test "page: every value it prints is escaped" {
    run bash -c "grep -n 'echo\|printf\|print ' '$PAGE' | grep -v 'h('"
    [ "$output" = "" ]
    grep -qF 'htmlspecialchars($value, ENT_QUOTES' "$PAGE"
}

@test "page: an unreachable database answers 503 with one line" {
    grep -qF 'http_response_code(503);' "$PAGE"
}

@test "page: no external resource" {
    run grep -iE 'https?://' "$PAGE"
    [ "$status" -ne 0 ]
}
