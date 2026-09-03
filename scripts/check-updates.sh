#!/bin/bash
# Nightly update checker, run from the overlay checkout root by
# check-updates.yml. Two checks, one Gitea issue per finding:
#   - packages whose upstream has a release newer than our newest ebuild
#   - vendored GURU copies whose GURU directory history moved past the
#     commit recorded in scripts/guru-sync.state
# Issues are idempotent: retitled when upstream moves again, closed
# automatically once the overlay catches up.
set -euo pipefail

API="${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}"
AUTH="Authorization: token ${GITHUB_TOKEN}"

# app-local-ai/* and the acct packages follow sci-ml/local-ai and need
# no entries of their own.
declare -A UPSTREAMS=(
	[sci-ml/local-ai]=github:mudler/LocalAI
	[dev-util/opencode]=github:anomalyco/opencode
	[dev-util/gitea-runner]=gitea:gitea.com/gitea/runner
	[app-containers/zot]=github:project-zot/zot
	[sci-libs/onnxruntime]=github:microsoft/onnxruntime
	[sci-libs/onnxruntime-bin]=github:microsoft/onnxruntime
	[sci-libs/dlpack]=github:dmlc/dlpack
	[dev-cpp/safeint]=github:dcleblanc/SafeInt
)

latest_upstream() {
	local kind=${1%%:*} repo=${1#*:} tag=
	case "${kind}" in
		github)
			tag=$(curl -sf "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name // empty')
			[ -n "${tag}" ] || tag=$(curl -sf "https://api.github.com/repos/${repo}/tags?per_page=1" | jq -r '.[0].name // empty')
			;;
		gitea)
			tag=$(curl -sf "https://${repo%%/*}/api/v1/repos/${repo#*/}/releases/latest" | jq -r '.tag_name // empty')
			;;
	esac
	printf '%s\n' "${tag#v}"
}

latest_ebuild() {
	basename -s .ebuild "${1}"/*.ebuild | sed -e "s:^${1##*/}-::" -e 's:-r[0-9]*$::' | sort -V | tail -n1
}

open_issue() { # <title prefix> -> "<number> <title>" of the first matching open issue
	curl -sf -H "${AUTH}" --get --data-urlencode "q=${1}" \
			--data 'state=open&type=issues' "${API}/issues" \
		| jq -r --arg t "${1}" '.[] | select(.title | startswith($t)) | "\(.number) \(.title)"' | head -n1
}

close_issue() { # <number>
	echo "closing resolved issue #${1}"
	curl -sf -X PATCH -H "${AUTH}" -H 'Content-Type: application/json' \
		-d '{"state":"closed"}' "${API}/issues/${1}" >/dev/null
}

file_issue() { # <existing> <title> <body>
	local existing=$1 title=$2 body=$3
	if [ -n "${existing}" ]; then
		if [ "${existing#* }" = "${title}" ]; then
			echo "issue already open: ${title}"
		else
			echo "retitling #${existing%% *}: ${title}"
			curl -sf -X PATCH -H "${AUTH}" -H 'Content-Type: application/json' \
				-d "$(jq -n --arg t "${title}" '{title: $t}')" "${API}/issues/${existing%% *}" >/dev/null
		fi
	else
		echo "opening issue: ${title}"
		curl -sf -X POST -H "${AUTH}" -H 'Content-Type: application/json' \
			-d "$(jq -n --arg t "${title}" --arg b "${body}" '{title: $t, body: $b}')" "${API}/issues" >/dev/null
	fi
}

rc=0

for pkg in $(printf '%s\n' "${!UPSTREAMS[@]}" | sort); do
	cur=$(latest_ebuild "${pkg}")
	up=$(latest_upstream "${UPSTREAMS[${pkg}]}")
	if [ -z "${up}" ]; then
		echo "warn: cannot determine upstream version for ${pkg}"
		rc=1
		continue
	fi
	existing=$(open_issue "update: ${pkg} ")
	if [ "$(printf '%s\n%s\n' "${cur}" "${up}" | sort -V | tail -n1)" = "${cur}" ]; then
		echo "current: ${pkg} ${cur} (upstream ${up})"
		[ -n "${existing}" ] && close_issue "${existing%% *}"
		continue
	fi
	body="Upstream: ${UPSTREAMS[${pkg}]#*:} — newest ebuild is ${cur}, latest upstream release is ${up}."
	[ "${pkg}" = sci-ml/local-ai ] && body+=" The app-local-ai backends follow this version."
	file_issue "${existing}" "update: ${pkg} ${up} is available (have ${cur})" "${body}"
done

while read -r pkg synced; do
	latest=$(curl -sf "https://api.github.com/repos/gentoo-mirror/guru/commits?path=${pkg}&per_page=1" | jq -r '.[0].sha // empty')
	if [ -z "${latest}" ]; then
		echo "warn: cannot read GURU history for ${pkg}"
		rc=1
		continue
	fi
	existing=$(open_issue "guru-sync: ${pkg} ")
	if [ "${latest}" = "${synced}" ]; then
		echo "in sync with GURU: ${pkg}"
		[ -n "${existing}" ] && close_issue "${existing%% *}"
		continue
	fi
	body="GURU history: https://github.com/gentoo-mirror/guru/commits/master/${pkg}

After copying the changes (minus our deviations), record the sync:
\`\`\`
sed -i 's|^${pkg} .*|${pkg} ${latest}|' scripts/guru-sync.state
\`\`\`"
	file_issue "${existing}" "guru-sync: ${pkg} changed in GURU (${latest:0:12})" "${body}"
done < scripts/guru-sync.state

exit ${rc}
