SUMMARY = "ARC web UI"
DESCRIPTION = "Web browser UI for LEA Amplifier"
LICENSE = "CLOSED"
DEPENDS = "lighttpd"
PR = "r1"

SRC_URI = "file://${BP}.tar.gz"

inherit bin_package
