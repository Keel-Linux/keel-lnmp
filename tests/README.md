# Tests

## Suites

- `check-hook.bats`: `firstboot.d/40lnmp-check` with `systemctl`,
  `mysqladmin` and `mysql` as stubs. The SQL is read back.
- `image-check.bats`: `bin/keel-lnmp-image-check` against a scratch tree
  named by `KEEL_CONF_ROOT`.
- `route.bats`: the route file and the check page, read as files.
- `manifest.bats`: `lnmp.yaml`. Two tests run keel's validator on the
  manifest and on the specs when `KEEL_SRC` names a keel checkout and
  `KEEL_MANIFEST_SOURCES` names checkouts of keel-core, keel-web and
  common. The stack job sets both.
- `recipe.bats`: the Makefile, the plan and the changelog.
- `stack.bats`: the stack on a machine. It runs as root where
  `LNMP_STACK_TEST=1`, and skips everywhere else.
- `hook.bats`, `mariadb.bats`, `dbpass.bats`, `project-packages.bats`,
  `socket-wildcard.bats`, `apt-files.bats`: from keel-mariadb, for the
  files copied from it.
- `boot-test.bats`, `boot-test.sh`, `lib/boot-test-lib.sh`: the boot test
  of keel-web. `instance.yaml` is its spec, host `lnmp`, appliance `lnmp`,
  simple installation. `boot-test.sh` also reads the check page over
  HTTPS.

## Run

Debian packages `bats` (1.11), `kcov` (43) and `python3-yaml`; no root:

    COVERAGE_THRESHOLD=95 tests/coverage.sh

## The checks

| Check | What |
| --- | --- |
| `tests / tests` | `tests/coverage.sh`: the measured files and the other suites |
| `tests / package` | a change that ships has a changelog entry |
| `tests / stack` | nginx, PHP-FPM and MariaDB on a booted trixie container, with a stand-in for keel-web 0.3.0's default site |
| `tests / appliance` | the boot test of the published layer; `allow_unpublished` until the first release |
| `security / security` | gitleaks, bandit, semgrep, shellcheck |

## The layer on a built image

The appliance check boots what the mirror publishes, never this branch. The
evidence for a branch is its image, built with `bt-layer lnmp --parent
web` and booted on the real platform with an evidence file (decision 0053).
