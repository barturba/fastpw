#!/usr/bin/env bash

# High-level interactive flows: search, copy, browse, add-login inline

search_and_copy() {
  require_jq
  init_if_missing
  require_gum
  local choice company login field value
  setup_screen
  choice=$(decrypt_data | jq -r '.companies[] as $c | $c.logins[] as $l | ($l.fields | to_entries[]) | [$c.name, $l.name, .key] | @tsv' | \
    gum filter --placeholder "Search…" --height "$(calc_body_height)" --padding "0 4 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt)) || { clear_screen; return 0; }
  choice=$(printf "%s" "${choice}" )
  IFS=$'\t' read -r company login field <<<"${choice}"
  value=$(get_field_value "$company" "$login" "$field")
  [ -n "${value}" ] && [ "${value}" != "null" ] || { gum_err "No value"; return 1; }
  with_spin "Copying ${field} to clipboard…" bash -c 'v="$1"; if command -v pbcopy >/dev/null 2>&1; then printf "%s" "$v" | pbcopy; elif command -v clip.exe >/dev/null 2>&1; then printf "%s" "$v" | clip.exe; elif command -v wl-copy >/dev/null 2>&1; then printf "%s" "$v" | wl-copy; elif command -v xclip >/dev/null 2>&1; then printf "%s" "$v" | xclip -selection clipboard; elif command -v xsel >/dev/null 2>&1; then printf "%s" "$v" | xsel --clipboard --input; else printf "%s" "$v"; echo "(Clipboard tool not found; printed value instead)" >&2; fi' _ "${value}"
  post_copy_animation "Copied '$field' for ${login} @ ${company}!"
  clear_screen
  browse_company "${company}"
  return 0
}

copy_flow() {
  require_jq
  init_if_missing
  local company="${1-}" login="${2-}" field="${3-}" print_only="${4-}"
  local had_prompt=0
  if [ -z "${company}" ]; then
    require_gum
    setup_screen
    company=$(list_companies | \
      gum filter --height "$(calc_body_height)" --padding "0 4 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt) --placeholder "Select company…") || { clear_screen; exit 0; }
    had_prompt=1
  fi
  if [ -z "${login}" ]; then
    require_gum
    setup_screen
    login=$(list_logins_for_company "$company" | \
      gum filter --height "$(calc_body_height)" --padding "0 4 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt) --placeholder "Select login…") || { clear_screen; exit 0; }
    had_prompt=1
  fi
  if [ -z "${field}" ]; then
    require_gum
    setup_screen
    field=$(list_fields_for_login "$company" "$login" | \
      gum filter --height "$(calc_body_height)" --padding "0 4 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt) --placeholder "Select field…") || { clear_screen; exit 0; }
    had_prompt=1
  fi
  local value
  value=$(get_field_value "$company" "$login" "$field")
  if [ -z "${value}" ] || [ "${value}" = "null" ]; then
    if command -v gum >/dev/null 2>&1; then
      gum_err "No value for '$field'"
    else
      echo "No value for '$field'" >&2
    fi
    exit 1
  fi
  if [ "${print_only}" = "print" ] || [ "${FASTPW_PRINT-}" = "1" ]; then
    printf "%s" "${value}"
    return 0
  fi
  with_spin "Copying ${field} to clipboard…" bash -c 'v="$1"; if command -v pbcopy >/dev/null 2>&1; then printf "%s" "$v" | pbcopy; elif command -v clip.exe >/dev/null 2>&1; then printf "%s" "$v" | clip.exe; elif command -v wl-copy >/dev/null 2>&1; then printf "%s" "$v" | wl-copy; elif command -v xclip >/dev/null 2>&1; then printf "%s" "$v" | xclip -selection clipboard; elif command -v xsel >/dev/null 2>&1; then printf "%s" "$v" | xsel --clipboard --input; else printf "%s" "$v"; echo "(Clipboard tool not found; printed value instead)" >&2; fi' _ "${value}"
  if command -v gum >/dev/null 2>&1; then
    post_copy_animation "Copied '$field' for ${login} @ ${company}!"
    if [ ${had_prompt} -eq 1 ]; then
      clear_screen
      browse_company "${company}"
    fi
  else
    echo "Copied '$field' for ${login} @ ${company}!" >&2
  fi
}

browse_and_copy() {
  require_gum
  local company login field value
  setup_screen
  company=$(list_companies | \
    gum filter --placeholder "Select company…" --height "$(calc_body_height)" --padding "0 4 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt)) || { clear_screen; return 0; }
  while true; do
    setup_submenu
    login=$( (echo "⬅ Back"; list_logins_for_company "$company") | \
      gum filter --height "$(calc_body_height)" --padding "0 4 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt) --placeholder "Select login…") || { clear_screen; return 0; }
    if [ "${login}" = "⬅ Back" ]; then
      return 0
    fi
    while true; do
      setup_submenu
      field=$( (echo "⬅ Back to logins"; list_fields_for_login "$company" "$login") | \
        gum filter --height "$(calc_body_height)" --padding "0 4 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt) --placeholder "Select field to copy…") || { clear_screen; break; }
      if [ "${field}" = "⬅ Back to logins" ]; then
        break
      fi
      value=$(get_field_value "$company" "$login" "$field")
      if [ -z "${value}" ] || [ "${value}" = "null" ]; then
        gum_err "No value for '$field'"
        continue
      fi
      with_spin "Copying ${field} to clipboard…" bash -c 'v="$1"; if command -v pbcopy >/dev/null 2>&1; then printf "%s" "$v" | pbcopy; elif command -v clip.exe >/dev/null 2>&1; then printf "%s" "$v" | clip.exe; elif command -v wl-copy >/dev/null 2>&1; then printf "%s" "$v" | wl-copy; elif command -v xclip >/dev/null 2>&1; then printf "%s" "$v" | xclip -selection clipboard; elif command -v xsel >/dev/null 2>&1; then printf "%s" "$v" | xsel --clipboard --input; else printf "%s" "$v"; echo "(Clipboard tool not found; printed value instead)" >&2; fi' _ "${value}"
      post_copy_animation "Copied '$field' for ${login} @ ${company}!"
      # After copy, go back to selecting a login within the same company
      break
    done
  done
}

# Browse within a given company (login -> field -> copy) and return here after copy
browse_company() {
  require_gum
  local company="$1" login field value
  [ -n "${company}" ] || return 0
  while true; do
    setup_submenu
    login=$( (echo "⬅ Back"; list_logins_for_company "$company") | \
      gum filter --height "$(calc_body_height)" --padding "0 4 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt) --placeholder "Select login…") || { clear_screen; return 0; }
    if [ "${login}" = "⬅ Back" ]; then
      return 0
    fi
    while true; do
      setup_submenu
      field=$( (echo "⬅ Back to logins"; list_fields_for_login "$company" "$login") | \
        gum filter --height "$(calc_body_height)" --padding "0 4 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt) --placeholder "Select field to copy…") || { clear_screen; break; }
      if [ "${field}" = "⬅ Back to logins" ]; then
        break
      fi
      value=$(get_field_value "$company" "$login" "$field")
      if [ -z "${value}" ] || [ "${value}" = "null" ]; then
        gum_err "No value for '$field'"
        continue
      fi
      with_spin "Copying ${field} to clipboard…" bash -c 'v="$1"; if command -v pbcopy >/dev/null 2>&1; then printf "%s" "$v" | pbcopy; elif command -v clip.exe >/dev/null 2>&1; then printf "%s" "$v" | clip.exe; elif command -v wl-copy >/dev/null 2>&1; then printf "%s" "$v" | wl-copy; elif command -v xclip >/dev/null 2>&1; then printf "%s" "$v" | xclip -selection clipboard; elif command -v xsel >/dev/null 2>&1; then printf "%s" "$v" | xsel --clipboard --input; else printf "%s" "$v"; echo "(Clipboard tool not found; printed value instead)" >&2; fi' _ "${value}"
      post_copy_animation "Copied '$field' for ${login} @ ${company}!"
      break
    done
  done
}

# Add login for a known company, collecting fields inline
interactive_add_login_for_company() {
  require_gum
  local company="$1" login
  [ -n "${company}" ] || return 1
  login=$(gum input --placeholder "Login name (e.g., Admin, Portal)" --prompt "🔐 " --width "$(calc_input_width)" --padding "${GUM_INPUT_PADDING:-"0 1"}" $(gum_timeout_opt)) || { clear_screen; return 1; }
  [ -n "${login}" ] || return 1
  login_add "${company}" "${login}"
  local add_more="yes" field value
  while [ "${add_more}" = "yes" ]; do
    field=$(gum input --placeholder "Field name (e.g., username, password, url)" --prompt "🔣 " --width "$(calc_input_width)" --padding "${GUM_INPUT_PADDING:-"0 1"}" $(gum_timeout_opt)) || { clear_screen; return 1; }
    [ -n "${field}" ] || break
    value=$(gum input --password --placeholder "Field value (hidden)" --prompt "🙈 " --width "$(calc_input_width)" --padding "${GUM_INPUT_PADDING:-"0 1"}" $(gum_timeout_opt)) || { clear_screen; return 1; }
    field_set "${company}" "${login}" "${field}" "${value}"
    add_more=$(gum choose --header "Add another field?" --height "$(calc_menu_height)" --padding "0 4 0 4" $(gum_width_opt choose "$(calc_input_width)") --select-if-one $(gum_timeout_opt) "yes" "no") || { clear_screen; break; }
  done
  celebrate "Saved ${login} @ ${company}."
  return 0
}


