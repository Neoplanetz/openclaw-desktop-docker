#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHIM="${ROOT_DIR}/scripts/systemctl-shim"

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "${TMP_HOME}"' EXIT

run_shim() {
    HOME="${TMP_HOME}" "${SHIM}" "$@"
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local label="$3"

    if [ "${actual}" != "${expected}" ]; then
        echo "FAIL: ${label}" >&2
        echo "expected:" >&2
        printf '%s\n' "${expected}" >&2
        echo "actual:" >&2
        printf '%s\n' "${actual}" >&2
        exit 1
    fi
}

expected="ActiveState=inactive"

actual="$(run_shim --user show openclaw-gateway.service --property ActiveState)"
assert_eq "${expected}" "${actual}" "show accepts --property after the unit"

actual="$(run_shim --user show openclaw-gateway.service --property=ActiveState)"
assert_eq "${expected}" "${actual}" "show accepts --property= after the unit"

actual="$(run_shim --user show --property ActiveState openclaw-gateway.service)"
assert_eq "${expected}" "${actual}" "show accepts --property before the unit"

actual="$(run_shim --user show --property=ActiveState openclaw-gateway.service)"
assert_eq "${expected}" "${actual}" "show accepts --property= before the unit"

actual="$(run_shim --user --property ActiveState show openclaw-gateway.service)"
assert_eq "${expected}" "${actual}" "show accepts --property before the command"

actual="$(run_shim --user --property=ActiveState show openclaw-gateway.service)"
assert_eq "${expected}" "${actual}" "show accepts --property= before the command"

echo "systemctl-shim tests passed"
