#!/usr/bin/env bats
# The appliance manifest of Keel LNMP (handbook decisions 0041 and 0059),
# which the overlay ships as /usr/share/keel/appliances/lnmp.yaml. It is
# built on web, so the image has one manifest that no other manifest is
# built on, and `keel inspect` names the appliance lnmp. The grep checks
# need nothing; the last test runs keel's own validator when KEEL_SRC
# names a checkout of Keel-Linux/keel (the stack job of tests.yml sets it).

bats_require_minimum_version 1.5.0

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    MANIFEST="$REPO/overlay/usr/share/keel/appliances/lnmp.yaml"
}

manifest() {
    python3 -c 'import sys, yaml
m = yaml.safe_load(open(sys.argv[1]))
print(eval(sys.argv[2]))' "$MANIFEST" "$1"
}

@test "manifest: the overlay ships it" {
    [ -f "$MANIFEST" ]
}

@test "manifest: an appliance named lnmp, version 1, on web" {
    [ "$(manifest 'm["manifest_version"]')" = 1 ]
    [ "$(manifest 'm["kind"]')" = appliance ]
    [ "$(manifest 'm["name"]')" = lnmp ]
    [ "$(manifest 'm["base"]')" = web ]
}

@test "manifest: MariaDB on 3306, a mesh port, with its Monit check" {
    [ "$(manifest '[p["unit"] for p in m["processes"] if p["name"] == "mariadb"][0]')" = mariadb.service ]
    [ "$(manifest '[p["listen"] for p in m["processes"] if p["name"] == "mariadb"][0]')" = "[{'port': 3306, 'protocol': 'tcp', 'expose': 'mesh'}]" ]
    [ "$(manifest '[(c["protocol"], c["port"], c["address"]) for c in m["checks"] if c["process"] == "mariadb"][0]')" = "('mysql', 3306, 'loopback')" ]
}

@test "manifest: PHP-FPM is a process with no TCP port" {
    [ "$(manifest '[p["unit"] for p in m["processes"] if p["name"] == "php-fpm"][0]')" = php8.4-fpm.service ]
    [ "$(manifest '[p.get("listen") for p in m["processes"] if p["name"] == "php-fpm"][0]')" = None ]
}

@test "manifest: no public port of its own: 80 and 443 are Web's" {
    [ "$(manifest '[l for p in m["processes"] for l in p.get("listen", []) if l["expose"] == "public"]')" = "[]" ]
}

@test "manifest: the shared database secret and the account option" {
    [ "$(manifest '[(s["name"], s["shared"], s["generate"]) for s in m["secrets"]]')" = "[('db_password', True, 'allowed')]" ]
    [ "$(manifest '[(o["name"], o["default"]) for o in m["options"]]')" = "[('db_user', 'admin')]" ]
}

@test "manifest: no overlays of its own: Core's and Web's are inherited" {
    [ "$(manifest 'm.get("overlays")')" = None ]
}

@test "manifest: no tabs, no CRLF" {
    run ! grep -q $'[\t\r]' "$MANIFEST"
}

# keel's validator, over a scratch root that holds Core's and Web's
# manifests, the overlays' and a stand-in file for every unit they name
@test "manifest: keel validates it and resolves it along web and core" {
    [ -n "${KEEL_SRC:-}" ] || skip "KEEL_SRC is not set (the stack job of tests.yml sets it)"
    run "$REPO/tests/lib/manifest-root.sh" "$BATS_TEST_TMPDIR/root" "$MANIFEST"
    [ "$status" -eq 0 ]
    run env PYTHONPATH="$KEEL_SRC" python3 -m keel manifest validate --root "$BATS_TEST_TMPDIR/root" lnmp
    echo "$output"
    [ "$status" -eq 0 ]
}

# the specs of this repository, held against the manifest by keel
@test "manifest: the example specs and the boot test's spec hold against it" {
    [ -n "${KEEL_SRC:-}" ] || skip "KEEL_SRC is not set (the stack job of tests.yml sets it)"
    run "$REPO/tests/lib/manifest-root.sh" "$BATS_TEST_TMPDIR/root" "$MANIFEST"
    [ "$status" -eq 0 ]
    for spec in keel/instance.example.yaml keel/instance.pair.example.yaml tests/instance.yaml; do
        run env PYTHONPATH="$KEEL_SRC" python3 -m keel spec validate --spec "$REPO/$spec" \
            --no-secret-files --root "$BATS_TEST_TMPDIR/root"
        echo "$spec: $output"
        [ "$status" -eq 0 ]
    done
}

# On a pair the replica replicates from the primary's overlay address, and
# keel binds the declared listen plus the VIP only (keel docs/replication.md).
# A listen of the loopbacks alone left the primary deaf to its replica
# (hw12-br1, 2026-10-16), so the example names the overlay address too.
@test "manifest: the pair example's listen holds the node's overlay address" {
    run python3 -c 'import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
own = d["network"]["overlay"]["wireguard"]["address"].split("/")[0]
listen = d["database"]["server"].get("listen")
sys.exit(0 if listen is None or own in [str(a) for a in listen] else 1)' "$REPO/keel/instance.pair.example.yaml"
    [ "$status" -eq 0 ]
}
