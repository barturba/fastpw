#!/usr/bin/env bash

# Paths and config
FASTPW_DIR="${HOME}/.fastpw"
DATA_FILE="${FASTPW_DIR}/data.enc.json"
SESSION_FILE="${FASTPW_DIR}/session.cache"
SESSION_TTL_SECONDS=$((8 * 60 * 60)) # 8 hours
OPENSSL_ITERATIONS=200000

bootstrap_dir() {
  umask 077
  if [ ! -d "${FASTPW_DIR}" ]; then
    mkdir -p "${FASTPW_DIR}"
    chmod 700 "${FASTPW_DIR}"
  fi
}

now_epoch() { date +%s; }

cache_valid() {
  [ -f "${SESSION_FILE}" ] || return 1
  local mtime
  mtime=$(stat -f %m "${SESSION_FILE}" 2>/dev/null || stat -c %Y "${SESSION_FILE}" 2>/dev/null || echo 0)
  local now
  now=$(now_epoch)
  local age=$((now - mtime))
  [ ${age} -lt ${SESSION_TTL_SECONDS} ]
}

read_cached_password() {
  if cache_valid; then
    head -n1 "${SESSION_FILE}"
    return 0
  fi
  return 1
}

write_cached_password() {
  umask 077
  printf "%s\n" "$1" >"${SESSION_FILE}"
}

prompt_master_password() {
  local cached
  if cached=$(read_cached_password); then
    printf "%s" "${cached}"
    return 0
  fi
  if [ -n "${FASTPW_MASTER-}" ]; then
    write_cached_password "${FASTPW_MASTER}"
    printf "%s" "${FASTPW_MASTER}"
    return 0
  fi
  if command -v gum >/dev/null 2>&1; then
    local pw
    pw=$(render_password "Enter master password" "") || exit 1
    write_cached_password "${pw}"
    printf "%s" "${pw}"
  else
    printf "Enter master password: " >&2
    stty -echo
    local pw
    IFS= read -r pw
    stty echo
    printf "\n" >&2
    write_cached_password "${pw}"
    printf "%s" "${pw}"
  fi
}

openssl_encrypt() {
  local pass="$1"
  # Read plaintext from stdin; read passphrase from fd 3
  openssl enc -aes-256-cbc -salt -pbkdf2 -iter ${OPENSSL_ITERATIONS} -pass fd:3 3<<<"${pass}"
}

openssl_decrypt() {
  local pass="$1"
  # Read ciphertext from stdin; read passphrase from fd 3
  openssl enc -d -aes-256-cbc -pbkdf2 -iter ${OPENSSL_ITERATIONS} -pass fd:3 3<<<"${pass}"
}

save_json_from_stdin() {
  # Encrypts JSON from stdin to DATA_FILE atomically with validation
  local pw tmp_enc tmp_plain
  pw=$(prompt_master_password)
  tmp_enc="${DATA_FILE}.tmp.$$"
  tmp_plain="${DATA_FILE}.plain.$$"
  umask 077
  cat >"${tmp_plain}"
  if ! jq -e . <"${tmp_plain}" >/dev/null 2>&1; then
    rm -f "${tmp_plain}"
    gum_err "Invalid JSON. Aborting save."
    exit 1
  fi
  if command -v gum >/dev/null 2>&1; then
    with_spin "🔐 Encrypting and saving…" bash -c 'set -euo pipefail; pass="$1"; plain="$2"; enc_tmp="$3"; iter="$4"; data_file="$5"; \
      openssl enc -aes-256-cbc -salt -pbkdf2 -iter "$iter" -pass fd:3 3<<<"$pass" <"$plain" >"$enc_tmp"; \
      chmod 600 "$enc_tmp"; rm -f "$plain"; mv "$enc_tmp" "$data_file"' _ "${pw}" "${tmp_plain}" "${tmp_enc}" "${OPENSSL_ITERATIONS}" "${DATA_FILE}"
  else
    bash -c 'set -euo pipefail; pass="$1"; plain="$2"; enc_tmp="$3"; iter="$4"; data_file="$5"; \
      openssl enc -aes-256-cbc -salt -pbkdf2 -iter "$iter" -pass fd:3 3<<<"$pass" <"$plain" >"$enc_tmp"; \
      chmod 600 "$enc_tmp"; rm -f "$plain"; mv "$enc_tmp" "$data_file"' _ "${pw}" "${tmp_plain}" "${tmp_enc}" "${OPENSSL_ITERATIONS}" "${DATA_FILE}"
  fi
}

seed_json() {
  cat <<'JSON'
{
  "companies": [
    {
      "name": "Aurora Quantum Group",
      "logins": [
        {"name": "Admin Portal", "fields": {"username": "admin@auroraq.com", "password": "ChangeMe!123", "portal_url": "https://admin.auroraq.com"}},
        {"name": "Okta", "fields": {"username": "it@auroraq.com", "password": "Rotate-Now-2025", "org": "auroraq"}}
      ]
    },
    {
      "name": "Nimbus Private Aviation",
      "logins": [
        {"name": "Ops Console", "fields": {"username": "ops@nimbusair.io", "password": "S3cureSky!", "portal_url": "https://ops.nimbusair.io"}}
      ]
    },
    {
      "name": "Cobalt Ventures",
      "logins": [
        {"name": "Investor Portal", "fields": {"username": "ir@cobalt.vc", "password": "Alpha^Beta^Gamma", "portal_url": "https://invest.cobalt.vc"}}
      ]
    },
    {
      "name": "Zephyr Capital Partners",
      "logins": [
        {"name": "MFA Vault", "fields": {"username": "secops@zephyrcap.com", "password": "TempPass!", "note": "Rotate post-onboarding"}}
      ]
    },
    {
      "name": "Vanguard Lux Resorts",
      "logins": [
        {"name": "PMS Admin", "fields": {"username": "pms-admin@vanguardlux.com", "password": "5tarLux#2025"}}
      ]
    }
  ]
}
JSON
}

init_if_missing() {
  bootstrap_dir
  if [ -f "${DATA_FILE}" ]; then
    return 0
  fi
  require_jq
  local pw
  pw=$(prompt_master_password)
  seed_json | jq '.' | openssl_encrypt "${pw}" >"${DATA_FILE}"
  chmod 600 "${DATA_FILE}"
}

decrypt_data() {
  require_jq
  local pw out
  pw=$(prompt_master_password)
  if ! out=$(openssl_decrypt "${pw}" <"${DATA_FILE}" 2>/dev/null); then
    # Likely a stale/incorrect cached password. Clear and retry once.
    rm -f "${SESSION_FILE}"
    pw=$(prompt_master_password)
    if ! out=$(openssl_decrypt "${pw}" <"${DATA_FILE}" 2>/dev/null); then
      gum_err "Failed to decrypt store. Wrong password?"
      exit 1
    fi
  fi
  # Validate JSON; if invalid, retry once after clearing session
  if ! jq -e . >/dev/null 2>&1 <<<"${out}"; then
    rm -f "${SESSION_FILE}"
    pw=$(prompt_master_password)
    if ! out=$(openssl_decrypt "${pw}" <"${DATA_FILE}" 2>/dev/null); then
      gum_err "Failed to decrypt store. Wrong password?"
      exit 1
    fi
    if ! jq -e . >/dev/null 2>&1 <<<"${out}"; then
      gum_err "Decrypted data is invalid. Aborting."
      exit 1
    fi
  fi
  printf "%s" "${out}"
}

list_companies() {
  decrypt_data | jq -r '.companies[].name'
}

list_logins_for_company() {
  local company="$1"
  decrypt_data | jq -r --arg c "$company" '.companies[] | select(.name==$c) | .logins[].name'
}

list_fields_for_login() {
  local company="$1" login="$2"
  decrypt_data | jq -r --arg c "$company" --arg l "$login" '.companies[] | select(.name==$c) | .logins[] | select(.name==$l) | .fields | keys[]'
}

get_field_value() {
  local company="$1" login="$2" field="$3"
  decrypt_data | jq -r --arg c "$company" --arg l "$login" --arg f "$field" '.companies[] | select(.name==$c) | .logins[] | select(.name==$l) | .fields[$f]'
}

# CRUD helpers using jq transformations
company_add() {
  local name="$1"
  decrypt_data | jq --arg n "$name" '
    if ([.companies[] | select(.name==$n)] | length) == 0 then
      .companies += [{name:$n, logins: []}]
    else . end
  ' | save_json_from_stdin
}

company_rm() {
  local name="$1"
  decrypt_data | jq --arg n "$name" '.companies |= map(select(.name!=$n))' | save_json_from_stdin
}

login_add() {
  local company="$1" login="$2"
  decrypt_data | jq --arg c "$company" --arg l "$login" '
    .companies |= map(
      if .name==$c then
        if ([.logins[]? | select(.name==$l)] | length)==0 then
          .logins += [{name:$l, fields:{}}]
        else . end
      else . end)
  ' | save_json_from_stdin
}

login_rm() {
  local company="$1" login="$2"
  decrypt_data | jq --arg c "$company" --arg l "$login" '
    .companies |= map(
      if .name==$c then
        .logins |= map(select(.name!=$l))
      else . end)
  ' | save_json_from_stdin
}

field_set() {
  local company="$1" login="$2" field="$3" value="$4"
  decrypt_data | jq --arg c "$company" --arg l "$login" --arg f "$field" --arg v "$value" '
    .companies |= map(
      if .name==$c then
        .logins |= map(
          if .name==$l then .fields[$f]=$v else . end)
      else . end)
  ' | save_json_from_stdin
}

field_rm() {
  local company="$1" login="$2" field="$3"
  decrypt_data | jq --arg c "$company" --arg l "$login" --arg f "$field" '
    .companies |= map(
      if .name==$c then
        .logins |= map(
          if .name==$l then del(.fields[$f]) else . end)
      else . end)
  ' | save_json_from_stdin
}

# Rename a company (no-op if target name already exists)
company_rename() {
  local old_name="$1" new_name="$2"
  decrypt_data | jq --arg o "$old_name" --arg n "$new_name" '
    if ([.companies[] | select(.name==$n)] | length) == 0 then
      .companies |= map(if .name==$o then (.name=$n) else . end)
    else . end
  ' | save_json_from_stdin
}

# Move/reorder a company to a specific index (0-based). Out-of-range indexes are clamped.
company_mv() {
  local name="$1" index="$2"
  decrypt_data | jq --arg n "$name" --argjson idx "$index" '
    . as $r
    | ([ $r.companies[] | select(.name==$n) ][0]) as $item
    | if $item == null then . else
        ([ $r.companies[] | select(.name!=$n) ]) as $rest
        | ($idx | if . < 0 then 0 elif . > ($rest|length) then ($rest|length) else . end) as $i
        | .companies = ($rest[0:$i] + [ $item ] + $rest[$i:])
      end
  ' | save_json_from_stdin
}

# Rename a login within a company (no-op if target name already exists in that company)
login_rename() {
  local company="$1" login="$2" new_name="$3"
  decrypt_data | jq --arg c "$company" --arg l "$login" --arg n "$new_name" '
    .companies |= map(
      if .name==$c then
        .logins |= ( if ((map(select(.name==$n)) | length)==0)
                     then (map(if .name==$l then (.name=$n) else . end))
                     else . end )
      else . end)
  ' | save_json_from_stdin
}

# Move a login within a company (reorder) or to another company and optional index
# Usage: login_mv <source_company> <login_name> [<dest_company>] [<to_index>]
login_mv() {
  local src_company="$1" login_name="$2" dest_company="${3-}" to_index="${4--1}"
  decrypt_data | jq --arg sc "$src_company" --arg l "$login_name" --arg dc "$dest_company" --argjson idx "$to_index" '
    . as $r
    | ([ $r.companies[] | select(.name==$sc) | .logins[] | select(.name==$l) ][0]) as $item
    | if $item == null then . else
        (if $dc != "" then $dc else $sc end) as $target
        | ( [ .companies[] | select(.name==$target) ] | length ) as $target_exists
        | if $target_exists == 0 then .companies += [{name:$target, logins: []}] else . end
        | .companies = [ .companies[] |
            if .name==$sc then .logins = [ .logins[] | select(.name!=$l) ] | . else . end
          ]
        | .companies = [ .companies[] |
            if .name==$target then
              (.logins as $logs
               | ($idx | if . == -1 then ($logs|length) else . end) as $raw
               | ($raw | if . < 0 then 0 elif . > ($logs|length) then ($logs|length) else . end) as $i
               | .logins = ($logs[0:$i] + [ $item ] + $logs[$i:])
              )
            else . end
          ]
      end
  ' | save_json_from_stdin
}
