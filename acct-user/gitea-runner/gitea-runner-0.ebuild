# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-user

ACCT_USER_ID=-1
ACCT_USER_HOME=/var/lib/gitea-runner
# The docker group grants access to the Docker socket the runner launches
# job containers through.
ACCT_USER_GROUPS=( gitea-runner docker )

acct-user_add_deps
