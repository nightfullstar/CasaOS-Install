#!/usr/bin/env bash
# shellcheck disable=SC2034 # the globals are read by the function copied out of install.sh
#
# Checks that an upgrade rewrites only the dead Big Bear zip and the legacy
# GitHub-raw recasaos.zip on exact `appstore =` lines. Rewrite_Dead_AppStores
# is copied out of install.sh as it stands and run against a fixture conf.
#
#   bash scripts/test-install-appstore.sh
#
# The release workflow runs this before anything is built.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

# install.sh as bash reads it: a Windows checkout has CRLF line endings.
INSTALL_SH="${WORK}/install.sh"
tr -d '\r' <"${ROOT}/install.sh" >"${INSTALL_SH}"
bash -n "${INSTALL_SH}" || fail "install.sh does not parse"

eval "$(sed -n '/^Rewrite_Dead_AppStores() {$/,/^}$/p' "${INSTALL_SH}")"
declare -F Rewrite_Dead_AppStores >/dev/null || fail "install.sh defines no Rewrite_Dead_AppStores()"

# what the function takes from install.sh's globals
sudo_cmd=""
PREFIX="${WORK}/root"
mkdir -p "${PREFIX}/etc/casaos"

DEAD='appstore = https://github.com/bigbeartechworld/big-bear-casaos/archive/refs/heads/master.zip'
USER='appstore = https://github.com/ReCasaOS/big-bear-casaos/archive/refs/heads/master.zip'
LEGACY='appstore = https://raw.githubusercontent.com/ReCasaOS/_appstore/catalogue/store/recasaos.zip'
ORG='appstore = https://recasaos.org/store/recasaos.zip'

CONF="${PREFIX}/etc/casaos/app-management.conf"
printf '%s\n' '[server]' "${DEAD}" "${USER}" "${LEGACY}" >"${CONF}"

Rewrite_Dead_AppStores

got="$(cat "${CONF}")"
want="$(printf '%s\n' '[server]' "${ORG}" "${USER}" "${ORG}")"
[[ "${got}" == "${want}" ]] || fail "fixture: wanted
${want}
got
${got}"
echo "ok: only the dead zip and the legacy raw default become the org URL"

grep -qE '^[[:space:]]+Rewrite_Dead_AppStores$' "${INSTALL_SH}" || fail "install.sh never calls Rewrite_Dead_AppStores"
grep -Fq 'sed -i "s#https://github.com/IceWhaleTech/_appstore/#${CASA_DOWNLOAD_DOMAIN}IceWhaleTech/_appstore/#g"' "${INSTALL_SH}" ||
    fail "install.sh no longer rewrites the IceWhale _appstore URL"
echo "ok: IceWhale sed stays, and the rewrite is called"

echo "all appstore rewrite checks passed"
