#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." >/dev/null 2>&1 && pwd -P)"
BIN="${REPO_DIR}/bin/fastpw"
LIB_STORE="${REPO_DIR}/lib/store.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for tests" >&2
  exit 1
fi
if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required for tests" >&2
  exit 1
fi

# Extract iterations from the code to avoid drift
OPENSSL_ITERATIONS="$(grep -E '^[[:space:]]*OPENSSL_ITERATIONS=' "${LIB_STORE}" | sed 's/[^0-9]*\([0-9][0-9]*\).*/\1/')"
if [ -z "${OPENSSL_ITERATIONS}" ]; then
  echo "Failed to detect OPENSSL_ITERATIONS from lib/store.sh" >&2
  exit 1
fi

tmp_root="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_root}"
}
trap cleanup EXIT

export HOME="${tmp_root}/home"
mkdir -p "${HOME}"

MASTER="s3cr3t-TEST"
export FASTPW_NO_PAUSE=1

data_file() { printf "%s/.fastpw/data.enc.json" "${HOME}"; }
session_file() { printf "%s/.fastpw/session.cache" "${HOME}"; }

decrypt_store() {
  local pass="$1"
  if [ ! -f "$(data_file)" ]; then
    echo "{}"
    return 0
  fi
  openssl enc -d -aes-256-cbc -pbkdf2 -iter "${OPENSSL_ITERATIONS}" -pass pass:"${pass}" <"$(data_file)"
}

assert() { # assert <exit_code> <message>
  local code="$1" msg="$2"
  if [ "${code}" -ne 0 ]; then
    echo "ASSERTION FAILED: ${msg}" >&2
    exit 1
  fi
}

assert_eq() { # assert_eq <actual> <expected> <message>
  local actual="$1" expected="$2" msg="$3"
  if [ "${actual}" != "${expected}" ]; then
    echo "ASSERTION FAILED: ${msg}. Expected='${expected}' Actual='${actual}'" >&2
    exit 1
  fi
}

assert_contains() { # assert_contains <haystack> <needle> <message>
  local hay="$1" needle="$2" msg="$3"
  if ! printf "%s" "${hay}" | grep -Fq -- "${needle}"; then
    echo "ASSERTION FAILED: ${msg}. Missing '${needle}'" >&2
    exit 1
  fi
}

run() { echo "+ $*" 1>&2; "$@"; }

echo "Running FastPW integration tests in ${tmp_root}"

echo "01) init creates encrypted store"
FASTPW_MASTER="${MASTER}" run "${BIN}" --init
test -f "$(data_file)" || { echo "data file not found" >&2; exit 1; }
decrypt_store "${MASTER}" | jq -e '.companies | length > 0' >/dev/null 2>&1
assert $? "init should create seed companies"

echo "02) --list prints companies"
out=$(FASTPW_MASTER="${MASTER}" run "${BIN}" --list | sed 's/\x1B\[[0-9;]*[JKmsu]//g' || true)
assert_contains "${out}" "Companies:" "--list should include Companies header"

echo "03) company add ACME"
FASTPW_MASTER="${MASTER}" run "${BIN}" company add "ACME"
decrypt_store "${MASTER}" | jq -e '.companies | map(.name=="ACME") | any' >/dev/null 2>&1
assert $? "company ACME should be present"

echo "04) login add --company ACME --login prod"
FASTPW_MASTER="${MASTER}" run "${BIN}" login add --company "ACME" --login "prod"
decrypt_store "${MASTER}" | jq -e '.companies[] | select(.name=="ACME") | .logins | map(.name=="prod") | any' >/dev/null 2>&1
assert $? "login prod for ACME should be present"

echo "05) field set username=alice"
FASTPW_MASTER="${MASTER}" run "${BIN}" field set --company "ACME" --login "prod" --field "username" --value "alice"
decrypt_store "${MASTER}" | jq -e '.companies[] | select(.name=="ACME") | .logins[] | select(.name=="prod") | .fields.username=="alice"' >/dev/null 2>&1
assert $? "username field should equal alice"

echo "06) copy --print returns value"
val=$(FASTPW_MASTER="${MASTER}" run "${BIN}" copy --company "ACME" --login "prod" --field "username" --print)
assert_eq "${val}" "alice" "copy --print should output field value"

echo "07) field rm username"
FASTPW_MASTER="${MASTER}" run "${BIN}" field rm --company "ACME" --login "prod" --field "username"
decrypt_store "${MASTER}" | jq -e '.companies[] | select(.name=="ACME") | .logins[] | select(.name=="prod") | .fields | has("username") | not' >/dev/null 2>&1
assert $? "username field should be removed"

echo "08) login rm prod"
FASTPW_MASTER="${MASTER}" run "${BIN}" login rm --company "ACME" --login "prod"
decrypt_store "${MASTER}" | jq -e '.companies[] | select(.name=="ACME") | .logins | map(.name=="prod") | any | not' >/dev/null 2>&1
assert $? "login prod should be removed"

echo "09) company rm ACME"
FASTPW_MASTER="${MASTER}" run "${BIN}" company rm "ACME"
decrypt_store "${MASTER}" | jq -e '.companies | map(.name=="ACME") | any | not' >/dev/null 2>&1
assert $? "company ACME should be removed"

echo "10) logout clears session cache"
FASTPW_MASTER="${MASTER}" run "${BIN}" logout
test ! -f "$(session_file)" || { echo "session cache still exists" >&2; exit 1; }

echo "11) reset repopulates seed data"
FASTPW_MASTER="${MASTER}" run "${BIN}" reset
decrypt_store "${MASTER}" | jq -e '.companies | length > 0' >/dev/null 2>&1
assert $? "reset should repopulate seed companies"

echo "12) company rename works"
orig=$(decrypt_store "${MASTER}" | jq -r '.companies[0].name')
FASTPW_MASTER="${MASTER}" run "${BIN}" company rename "${orig}" "Renamed Co"
decrypt_store "${MASTER}" | jq -e '.companies | map(.name=="Renamed Co") | any' >/dev/null 2>&1
assert $? "company should be renamed"

echo "13) company mv reorders companies"
FASTPW_MASTER="${MASTER}" run "${BIN}" company mv "Renamed Co" 0
first=$(decrypt_store "${MASTER}" | jq -r '.companies[0].name')
assert_eq "${first}" "Renamed Co" "Renamed company should be first"

echo "14) login rename within a company"
cname="Renamed Co"
login_before=$(decrypt_store "${MASTER}" | jq -r --arg c "$cname" '.companies[] | select(.name==$c) | .logins[0].name')
FASTPW_MASTER="${MASTER}" run "${BIN}" login rename --company "$cname" --login "$login_before" --new "Login X"
decrypt_store "${MASTER}" | jq -e --arg c "$cname" '.companies[] | select(.name==$c) | .logins | map(.name=="Login X") | any' >/dev/null 2>&1
assert $? "login should be renamed to Login X"

echo "15) login mv within same company (reorder)"
FASTPW_MASTER="${MASTER}" run "${BIN}" login mv --company "$cname" --login "Login X" --to 0
first_login=$(decrypt_store "${MASTER}" | jq -r --arg c "$cname" '.companies[] | select(.name==$c) | .logins[0].name')
assert_eq "${first_login}" "Login X" "Login X should be first within company"

echo "16) login mv to another company"
# pick another company name
other=$(decrypt_store "${MASTER}" | jq -r '.companies[] | select(.name!="Renamed Co") | .name' | head -n1)
FASTPW_MASTER="${MASTER}" run "${BIN}" login mv --company "$cname" --login "Login X" --dest-company "$other" --to 0
present_src=$(decrypt_store "${MASTER}" | jq -e --arg c "$cname" '.companies[] | select(.name==$c) | .logins | map(.name=="Login X") | any | not' >/dev/null 2>&1; echo $?)
assert ${present_src} "Login X should be removed from source company"
first_dest=$(decrypt_store "${MASTER}" | jq -r --arg c "$other" '.companies[] | select(.name==$c) | .logins[0].name')
assert_eq "${first_dest}" "Login X" "Login X should be first in destination company"

echo "All tests passed."

