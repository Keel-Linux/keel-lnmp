#!/usr/bin/env bats
# The first boot hook firstboot.d/40lnmp-check (handbook decision 0059,
# point 6): it gives the check page its database account and the row the
# page reads. Every command that touches the system (systemctl,
# mysqladmin, mysql) is a stub that records what it was asked; the SQL is
# read back from the stub. Nothing here needs root or a database.

bats_require_minimum_version 1.5.0

setup() {
    ROOT="$BATS_TEST_DIRNAME/.."
    HOOK="$ROOT/overlay/usr/lib/inithooks/firstboot.d/40lnmp-check"
    scratch="$BATS_TEST_TMPDIR/hook"
    mkdir -p "$scratch/bin"
    export INITHOOKS_DEFAULT="$scratch/default-inithooks"
    printf 'INITHOOKS_CONF=%s\nINITHOOKS_PATH=%s\n' "$scratch/inithooks.conf" "$scratch" \
        > "$INITHOOKS_DEFAULT"
    export CALLS="$scratch/calls" SQL="$scratch/sql"
    export LNMP_SPEC="$scratch/instance.yaml"
    export LNMP_SLEEP=: LNMP_WAIT_TRIES=3
    export READ_ONLY=0
    stub systemctl 'echo "systemctl $*" >> "$CALLS"'
    stub mysqladmin 'echo "mysqladmin $*" >> "$CALLS"'
    # SELECT @@global.read_only is answered from READ_ONLY; any other
    # statement comes on stdin and is kept
    stub mysql 'echo "mysql $*" >> "$CALLS"
case "$*" in *read_only*) echo "$READ_ONLY"; exit 0 ;; esac
cat >> "$SQL"'
    PATH="$scratch/bin:$PATH"
}

stub() {
    printf '#!/bin/sh\n%s\n' "$2" > "$scratch/bin/$1"
    chmod +x "$scratch/bin/$1"
}

@test "a writable server gets the database, the table, the account and one row" {
    run "$HOOK"
    [ "$status" -eq 0 ]
    grep -qx 'systemctl start mariadb.service' "$CALLS"
    grep -qx 'CREATE DATABASE IF NOT EXISTS keel_check;' "$SQL"
    grep -q '^CREATE TABLE IF NOT EXISTS keel_check.boot' "$SQL"
    grep -qx "CREATE USER IF NOT EXISTS 'www-data'@'localhost' IDENTIFIED VIA unix_socket;" "$SQL"
    grep -qx "GRANT SELECT ON keel_check.* TO 'www-data'@'localhost';" "$SQL"
    grep -q '^INSERT INTO keel_check.boot (host, written_at) VALUES (@@hostname, NOW())' "$SQL"
    [[ "$output" == *"check database ready"* ]]
}

@test "the first statement keeps every write out of the binary log" {
    run "$HOOK"
    [ "$status" -eq 0 ]
    [ "$(head -1 "$SQL")" = 'SET SESSION sql_log_bin = 0;' ]
}

@test "the account may only read, and only the check database" {
    run "$HOOK"
    [ "$status" -eq 0 ]
    [ "$(grep -c '^GRANT' "$SQL")" = 1 ]
    run grep -E 'GRANT (ALL|INSERT|UPDATE|DELETE)|ON \*\.\*|IDENTIFIED BY' "$SQL"
    [ "$status" -ne 0 ]
}

@test "a second run writes no second row and fails nothing" {
    run "$HOOK"
    run "$HOOK"
    [ "$status" -eq 0 ]
    [ "$(grep -c 'ON DUPLICATE KEY UPDATE written_at = written_at;' "$SQL")" = 2 ]
}

@test "a read-only server is a replica: nothing is written, and it says so" {
    READ_ONLY=1 run "$HOOK"
    [ "$status" -eq 0 ]
    [ ! -e "$SQL" ]
    [[ "$output" == *"read-only"* ]]
}

@test "a spec that declares a replica gets the account and no database" {
    printf 'version: 1\ndatabase:\n  server:\n    engine: mariadb\n    role: replica\n' > "$LNMP_SPEC"
    run "$HOOK"
    [ "$status" -eq 0 ]
    grep -qx "CREATE USER IF NOT EXISTS 'www-data'@'localhost' IDENTIFIED VIA unix_socket;" "$SQL"
    run grep -E 'CREATE DATABASE|INSERT' "$SQL"
    [ "$status" -ne 0 ]
}

@test "a spec that declares a primary gets the database and the row" {
    printf 'version: 1\ndatabase:\n  server:\n    engine: mariadb\n    role: primary\n' > "$LNMP_SPEC"
    run "$HOOK"
    [ "$status" -eq 0 ]
    grep -qx 'CREATE DATABASE IF NOT EXISTS keel_check;' "$SQL"
}

@test "a spec that cannot be read is not a replica" {
    printf 'version: 1\ndatabase: [this is: not a mapping\n' > "$LNMP_SPEC"
    run "$HOOK"
    [ "$status" -eq 0 ]
    grep -qx 'CREATE DATABASE IF NOT EXISTS keel_check;' "$SQL"
}

@test "a server that never answers fails the hook and says why" {
    stub mysqladmin 'echo "mysqladmin $*" >> "$CALLS"; exit 1'
    run "$HOOK"
    [ "$status" -eq 1 ]
    [ "$(grep -c '^mysqladmin' "$CALLS")" = 3 ]
    [[ "$output" == *"did not answer after 3 tries"* ]]
}

@test "a server that cannot say whether it is read-only fails the hook" {
    stub mysql 'case "$*" in *read_only*) exit 1 ;; esac; cat > /dev/null'
    run "$HOOK"
    [ "$status" -eq 1 ]
    [[ "$output" == *"read_only"* ]]
}

@test "a refused statement fails the hook" {
    stub mysql 'case "$*" in *read_only*) echo 0; exit 0 ;; esac; cat > /dev/null; exit 1'
    run "$HOOK"
    [ "$status" -eq 1 ]
    [[ "$output" == *"could not write the check database"* ]]
}
