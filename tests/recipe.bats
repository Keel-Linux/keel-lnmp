#!/usr/bin/env bats
# The recipe of the lnmp layer (handbook decision 0059): a layer on web,
# PHP-FPM and MariaDB from Debian 13, nothing of Apache, and no second
# appliance manifest. These read the files of the recipe; the build and
# the booted image prove the rest.

bats_require_minimum_version 1.5.0

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

# the package lines of plan/main, comments removed
packages() {
    sed -e 's|/\*.*\*/||g' "$REPO/plan/main" | sed -e '/\/\*/,/\*\//d' \
        | grep -vE '^\s*(#|$)' | awk '{print $1}'
}

@test "recipe: PHP-FPM and MariaDB through common's mk files, not Adminer" {
    grep -qx 'include $(FAB_PATH)/common/mk/turnkey/php-fpm.mk' "$REPO/Makefile"
    grep -qx 'include $(FAB_PATH)/common/mk/turnkey/mysql.mk' "$REPO/Makefile"
    run bash -c "grep -v '^#' '$REPO/Makefile' | grep -E 'adminer|lamp|apache|nginx-php-mysql'"
    [ "$status" -ne 0 ]
}

@test "recipe: the panel opens SSH, HTTP, HTTPS and Webmin only" {
    grep -qx 'WEBMIN_FW_TCP_INCOMING = 22 80 443 12321' "$REPO/Makefile"
}

@test "recipe: the plan has PHP-FPM, its MariaDB module and the server" {
    packages | grep -qx php-fpm
    packages | grep -qx php-mysql
    packages | grep -qx mariadb-client
    grep -qx '#include <turnkey/mysql>' "$REPO/plan/main"
}

@test "recipe: nothing of Apache, no php metapackage, no keel-mariadb" {
    run packages
    for name in apache2 libapache2-mod-php php keel-mariadb adminer; do
        if printf '%s\n' "$output" | grep -qx "$name"; then
            echo "plan/main asks for $name"
            return 1
        fi
    done
}

@test "recipe: the build tools are copied into the tree before the conf scripts" {
    grep -q 'bin/keel-project-packages' "$REPO/Makefile"
    grep -q 'bin/keel-socket-wildcard' "$REPO/Makefile"
    grep -q 'bin/keel-lnmp-image-check' "$REPO/Makefile"
}

@test "recipe: the changelog names the layer" {
    head -1 "$REPO/changelog" | grep -q '^keel-lnmp-19.0 (1) keel;'
}
