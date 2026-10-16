#!/usr/bin/env bats
# bin/keel-lnmp-image-check, which conf.d/main runs at the end of the build
# on the image tree (handbook decision 0059): it changes nothing and fails
# the build when the image is not what a first boot of LNMP starts from.
# Here it runs against a scratch tree named by KEEL_CONF_ROOT.

bats_require_minimum_version 1.5.0

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    CHECK="$REPO/bin/keel-lnmp-image-check"
    T="$BATS_TEST_TMPDIR/tree"
    export KEEL_CONF_ROOT="$T"
    mkdir -p "$T/etc/systemd/system/multi-user.target.wants" "$T/var/lib/dpkg" \
        "$T/etc/nginx/keel-default.d" "$T/usr/share/keel-lnmp/www/keel-check" \
        "$T/usr/share/keel/appliances" "$T/etc/webmin/phpini" "$T/etc/php/8.4/fpm"
    ln -s /dev/null "$T/etc/systemd/system/mariadb.socket"
    ln -s /dev/null "$T/etc/systemd/system/mariadb-extra.socket"
    ln -s /usr/lib/systemd/system/php8.4-fpm.service \
        "$T/etc/systemd/system/multi-user.target.wants/php8.4-fpm.service"
    printf 'Package: nginx\nStatus: install ok installed\n\nPackage: php8.4-fpm\nStatus: install ok installed\n\n' \
        > "$T/var/lib/dpkg/status"
    cp "$REPO/overlay/etc/nginx/keel-default.d/50-keel-lnmp.conf" "$T/etc/nginx/keel-default.d/"
    cp "$REPO/overlay/usr/share/keel-lnmp/www/keel-check/index.php" "$T/usr/share/keel-lnmp/www/keel-check/"
    cp "$REPO/overlay/usr/share/keel/appliances/lnmp.yaml" "$T/usr/share/keel/appliances/"
    printf 'php_ini=/etc/php/8.4/fpm/php.ini=Configuration for PHP-FPM\n' > "$T/etc/webmin/phpini/config"
    touch "$T/etc/php/8.4/fpm/php.ini"
}

@test "an image as the recipe leaves it passes" {
    run "$CHECK"
    [ "$status" -eq 0 ]
}

@test "apache2 in the image fails the build" {
    printf 'Package: apache2\nStatus: install ok installed\n\n' >> "$T/var/lib/dpkg/status"
    run "$CHECK"
    [ "$status" -eq 1 ]
    [[ "$output" == *"apache2 is installed"* ]]
}

@test "mod_php in the image fails the build" {
    printf 'Package: libapache2-mod-php8.4\nStatus: install ok installed\n\n' >> "$T/var/lib/dpkg/status"
    run "$CHECK"
    [ "$status" -eq 1 ]
    [[ "$output" == *"libapache2-mod-php8.4 is installed"* ]]
}

@test "a package that was removed is not installed" {
    printf 'Package: apache2\nStatus: deinstall ok config-files\n\n' >> "$T/var/lib/dpkg/status"
    run "$CHECK"
    [ "$status" -eq 0 ]
}

@test "a socket unit of MariaDB that is not masked fails the build" {
    rm "$T/etc/systemd/system/mariadb.socket"
    run "$CHECK"
    [ "$status" -eq 1 ]
    [[ "$output" == *"mariadb.socket is not masked"* ]]
}

@test "PHP-FPM not enabled fails the build" {
    rm "$T/etc/systemd/system/multi-user.target.wants/php8.4-fpm.service"
    run "$CHECK"
    [ "$status" -eq 1 ]
    [[ "$output" == *"php8.4-fpm.service is not enabled"* ]]
}

@test "a missing route, page or manifest fails the build, each said" {
    rm "$T/etc/nginx/keel-default.d/50-keel-lnmp.conf" \
        "$T/usr/share/keel-lnmp/www/keel-check/index.php" \
        "$T/usr/share/keel/appliances/lnmp.yaml"
    run "$CHECK"
    [ "$status" -eq 1 ]
    [[ "$output" == *"50-keel-lnmp.conf"* ]]
    [[ "$output" == *"index.php"* ]]
    [[ "$output" == *"lnmp.yaml"* ]]
}

@test "the manifest of a database layer beside lnmp.yaml fails the build" {
    touch "$T/usr/share/keel/appliances/mariadb.yaml"
    run "$CHECK"
    [ "$status" -eq 1 ]
    [[ "$output" == *"mariadb.yaml is in the image"* ]]
}

@test "Webmin's PHP module pointed at Apache's php.ini fails the build" {
    printf 'php_ini=/etc/php/8.4/apache2/php.ini=Configuration for mod_php\n' > "$T/etc/webmin/phpini/config"
    run "$CHECK"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Webmin's PHP module"* ]]
}

@test "a credential file of MariaDB in the image fails the build" {
    mkdir -p "$T/root"
    touch "$T/root/.my.cnf"
    run "$CHECK"
    [ "$status" -eq 1 ]
    [[ "$output" == *"/root/.my.cnf is in the image"* ]]
}

@test "every problem is reported, not only the first" {
    rm "$T/etc/systemd/system/mariadb.socket" "$T/etc/systemd/system/mariadb-extra.socket"
    run "$CHECK"
    [ "$status" -eq 1 ]
    [ "$(grep -c 'is not masked' <<<"$output")" = 2 ]
}
