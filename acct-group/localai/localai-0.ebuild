# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-group

# -1 = allocate the next free GID at install time (fixed IDs are only
# mandatory for packages in the main Gentoo tree).
ACCT_GROUP_ID=-1
