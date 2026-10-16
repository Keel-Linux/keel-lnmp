# keel-lnmp: nginx, MariaDB and PHP-FPM, the LNMP stack of Keel (handbook
# decision 0059), built as a layer on Keel Web:
#
#     bt-layer lnmp --parent web
#
# Web brings nginx, Coraza and Anubis; this layer adds PHP-FPM 8.4 and
# MariaDB 11.8 from Debian 13, the first boot hooks of the database
# (35mysqlpass, copied from keel-mariadb) and the check page at
# /keel-check/ (40lnmp-check, the route in /etc/nginx/keel-default.d/).
# Apache is not part of it: Keel retired Apache (0059). common's
# nginx-php-mysql.mk is not used, because it brings Adminer and the LAMP
# console overlay.
#
# PHP_* are read by common's conf/php.
PHP_MEMORY_LIMIT = 128M
PHP_POST_MAX_SIZE = 16M
PHP_UPLOAD_MAX_FILESIZE = 16M

include $(FAB_PATH)/common/mk/turnkey/php-fpm.mk
include $(FAB_PATH)/common/mk/turnkey/mysql.mk

# After the mk files, so a file of this overlay wins over the shared one.
COMMON_OVERLAYS += $(CURDIR)/overlay

# 80 and 443 are Web's, 12321 the panel. 3306 is not opened: MariaDB is on
# the loopback, and on a pair on the mesh (the manifest says mesh).
WEBMIN_FW_TCP_INCOMING = 22 80 443 12321

include $(FAB_PATH)/common/mk/turnkey.mk

# The checks conf.d/main runs on the tree, as keel-mariadb runs them: the
# project packages at the archive's candidate (bin/keel-project-packages),
# no socket unit on a wildcard address for 3306 (bin/keel-socket-wildcard),
# and the image as a first boot of LNMP starts from
# (bin/keel-lnmp-image-check). They are copied in before the conf scripts
# run, and conf.d/main removes them again.
KEEL_BUILD_TOOLS ?= /usr/local/lib/keel-build
define _keel_root.patched/pre

	install -D -m 755 $(CURDIR)/bin/keel-project-packages $O/root.patched$(KEEL_BUILD_TOOLS)/keel-project-packages;
	install -D -m 755 $(CURDIR)/bin/keel-socket-wildcard $O/root.patched$(KEEL_BUILD_TOOLS)/keel-socket-wildcard;
	install -D -m 755 $(CURDIR)/bin/keel-lnmp-image-check $O/root.patched$(KEEL_BUILD_TOOLS)/keel-lnmp-image-check;
endef
root.patched/pre += $(_keel_root.patched/pre)
