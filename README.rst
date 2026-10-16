Keel LNMP: nginx, MariaDB and PHP-FPM
=====================================

Keel LNMP is the PHP stack of Keel Linux (handbook decision 0059). It is a
layer on Keel Web::

    bt-layer lnmp --parent web

The chain is Core, Web and LNMP. Web brings nginx, Coraza and Anubis. This
layer adds PHP-FPM 8.4 and MariaDB 11.8 from Debian 13. Keel has no Apache.

What the layer adds
-------------------

- MariaDB on the two loopback addresses (``99-keel-bind.cnf``), with its
  socket units masked (keel-mariadb#29).
- The administrative account ``admin``, which cannot authenticate until
  the first boot sets its password from ``DB_PASS``
  (``firstboot.d/35mysqlpass``, from keel-mariadb).
- PHP-FPM on Debian's unix socket. No TCP port opens for it.
- The appliance manifest ``/usr/share/keel/appliances/lnmp.yaml``, built on
  ``web``: MariaDB on 3306 as a ``mesh`` port with its Monit check, PHP-FPM,
  the ``db_password`` secret and the ``db_user`` option.
- The check page at ``https://<address>/keel-check/``.

The image does not carry the manifest of keel-mariadb. Its base is
``core``, and two manifests that no other manifest is built on leave
``keel inspect`` unable to name the appliance (0059, point 3). The files
that keel-mariadb adds to the server are copied here for that reason.

The check page
--------------

``/etc/nginx/keel-default.d/50-keel-lnmp.conf`` gives
``/keel-check/index.php`` to PHP-FPM. keel-web 0.3.0 includes that
directory in its default site and in the server behind Anubis, so the page
answers in the simple mode and in the cloud modes.

The page connects to MariaDB over the local socket as ``www-data``, the
user of PHP-FPM. The server knows that user by the socket
(``unix_socket``), so there is no password for it. The account has
``SELECT`` on ``keel_check`` only. The page shows:

- the versions of PHP and MariaDB,
- the role of the server: writable, or read-only on a replica,
- the rows that ``firstboot.d/40lnmp-check`` wrote at the first boot.

The page only reads. On a pair, the row on the replica comes from the
primary, so the page also shows that the replication works. If MariaDB
does not answer, the page answers 503 with one line.

``firstboot.d/40lnmp-check`` writes with ``sql_log_bin = 0``. A node that
becomes a replica later then holds no transaction that the primary does
not have. It writes nothing on a read-only server. If the spec declares
``database.server.role: replica``, it makes the account and no database:
keel's seed would refuse to replace a local database without a
confirmation.

The pair
--------

The pair of decision 0049 comes from the spec: ``database.server`` and
``appliance.vip``, as on the keel-mariadb layer. keel converges the pair by
``database.server.engine``, not by the name of the appliance.
``keel/instance.example.yaml`` is a standalone spec and
``keel/instance.pair.example.yaml`` the primary of a pair.

Tests
-----

See ``tests/README.md`` and ``COVERAGE.md``.
