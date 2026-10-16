# Coverage

Measured with kcov over the bats suites by `tests/coverage.sh`
(decision 0004), 2026-10-16:

| File | Lines covered |
| --- | --- |
| `tests/lib/boot-test-lib.sh` | 100.00 percent (109 of 109) |
| `overlay/usr/lib/inithooks/lib/mariadb.sh` | 100.00 percent (43 of 43) |
| `overlay/usr/lib/inithooks/firstboot.d/35mysqlpass` | 96.00 percent (24 of 25): the process substitution, which kcov gives no line |
| `overlay/usr/lib/inithooks/firstboot.d/40lnmp-check` | 100.00 percent (25 of 25) |
| `bin/keel-project-packages` | 100.00 percent (32 of 32) |
| `bin/keel-socket-wildcard` | 100.00 percent (48 of 48) |
| `bin/keel-lnmp-image-check` | 96.67 percent (29 of 30) |

The threshold in `.forgejo/workflows/tests.yml` is 95, the lowest of
them rounded down. It is only ever raised (decision 0006).

Not measured: `conf.d/main` runs in the build chroot and the build runs
it; `tests/boot-test.sh` runs keel and LXC as root in the boot test;
`tests/lib/manifest-root.sh` is a test helper. The check page is PHP: the
stack job serves it and reads it back (`tests/stack.bats`).
