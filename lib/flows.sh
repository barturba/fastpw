#!/usr/bin/env bash

# High-level interactive flows: search, copy, browse, add-login inline

search_and_copy() {
  require_jq
  init_if_missing
  require_gum
  local choice company login field value
  setup_screen
  choice=$(decrypt_data | jq -r '.companies[] as $c | $c.logins[] as $l | ($l.fields | to_entries[]) | [$c.name, $l.name, .key] | @tsv' | \
    render_filter "Search…" "Global Search") || { clear_screen; return 0; }
  choice=$(printf "%s" "${choice}" )
  IFS=$'\t' read -r company login field <<<"${choice}"
  value=$(get_field_value "$company" "$login" "$field")
  [ -n "${value}" ] && [ "${value}" != "null" ] || { gum_err "No value"; return 1; }
  copy_with_spin "Copying ${field} to clipboard…" "${value}"
  post_copy_animation "Copied '$field' for ${login} @ ${company}!"
  # Drop into continuous field browser for fast repeat
  clear_screen
  field_browser "${company}" "${login}" "${field}"
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
    company=$(list_companies | render_filter "Select company…" "") || { clear_screen; exit 0; }
    had_prompt=1
  fi
  if [ -z "${login}" ]; then
    require_gum
    setup_screen
    login=$(list_logins_for_company "$company" | render_filter "Select login…" "Company: ${company}") || { clear_screen; exit 0; }
    had_prompt=1
  fi
  if [ -z "${field}" ]; then
    require_gum
    setup_screen
    field=$(list_fields_for_login "$company" "$login" | render_filter "Select field…" "Company: ${company} • Login: ${login}") || { clear_screen; exit 0; }
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
  copy_with_spin "Copying ${field} to clipboard…" "${value}"
  if command -v gum >/dev/null 2>&1; then
    post_copy_animation "Copied '$field' for ${login} @ ${company}!"
    if [ ${had_prompt} -eq 1 ]; then
      clear_screen
      field_browser "${company}" "${login}" "${field}"
    fi
  else
    echo "Copied '$field' for ${login} @ ${company}!" >&2
  fi
}

browse_and_copy() {
  require_gum
  local company login field value
  setup_screen
  company=$(list_companies | render_filter "Select company…" "") || { clear_screen; return 0; }
  while true; do
    setup_submenu
    login=$(list_logins_for_company "$company" | render_filter "Select login…" "Company: ${company}") || { clear_screen; return 0; }
    while true; do
      setup_submenu
      field=$(list_fields_for_login "$company" "$login" | render_filter "Select field to copy…" "Company: ${company} • Login: ${login}") || { clear_screen; break; }
      value=$(get_field_value "$company" "$login" "$field")
      if [ -z "${value}" ] || [ "${value}" = "null" ]; then
        gum_err "No value for '$field'"
        continue
      fi
      copy_with_spin "Copying ${field} to clipboard…" "${value}"
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
    login=$(list_logins_for_company "$company" | render_filter "Select login…" "Company: ${company}") || { clear_screen; return 0; }
    while true; do
      setup_submenu
      field=$(list_fields_for_login "$company" "$login" | render_filter "Select field to copy…" "Company: ${company} • Login: ${login}") || { clear_screen; break; }
      value=$(get_field_value "$company" "$login" "$field")
      if [ -z "${value}" ] || [ "${value}" = "null" ]; then
        gum_err "No value for '$field'"
        continue
      fi
      copy_with_spin "Copying ${field} to clipboard…" "${value}"
      post_copy_animation "Copied '$field' for ${login} @ ${company}!"
      break
    done
  done
}

# New continuous browsers: company -> login -> field

# Field browser keeps the last selected field at the top and
# returns here after each copy for fast repeat.
# Return codes:
#   0 = caller should go back to login list
#   2 = caller should go back to companies list
field_browser() {
  require_gum
  local company="$1" login="$2" preselect_field="${3-}"
  [ -n "${company}" ] || return 0
  [ -n "${login}" ] || return 0
  while true; do
    setup_submenu
    local selection
    selection=$(
      {
        if [ -n "${preselect_field}" ]; then echo "${preselect_field}"; fi
        list_fields_for_login "${company}" "${login}" | awk -v p="${preselect_field}" 'p=="" || $0!=p'
      } | \
      render_filter "Select field to copy…" "Company: ${company} • Login: ${login}"
    ) || { clear_screen; return 0; }

    local value
    value=$(get_field_value "${company}" "${login}" "${selection}")
    if [ -z "${value}" ] || [ "${value}" = "null" ]; then
      gum_err "No value for '${selection}'"
      continue
    fi
    copy_with_spin "Copying ${selection} to clipboard…" "${value}"
    post_copy_animation "Copied '${selection}' for ${login} @ ${company}!"
    # Remember last field for this login for higher-level preselect
    LAST_FIELD_SELECTED="${selection}"
    # Stay in the field list, showing the same field at the top
    preselect_field="${selection}"
  done
}

# Login browser keeps last login at the top and returns to company list when requested
login_browser() {
  require_gum
  local company="$1" preselect_login="${2-}"
  [ -n "${company}" ] || return 0
  local selection
  while true; do
    setup_submenu
    selection=$(
      {
        if [ -n "${preselect_login}" ]; then echo "${preselect_login}"; fi
        list_logins_for_company "${company}" | awk -v p="${preselect_login}" 'p=="" || $0!=p'
      } | \
      render_filter "Select login…" "Company: ${company}"
    ) || { clear_screen; return 0; }

    # Enter field browser; after returning, continue in this company
    field_browser "${company}" "${selection}" "${LAST_FIELD_SELECTED-}"
    LAST_LOGIN_SELECTED="${selection}"
    preselect_login="${LAST_LOGIN_SELECTED-}"
  done
}

# Company browser shown at launch; exposes global actions and company selection
company_browser() {
  require_gum
  require_jq
  init_if_missing
  while true; do
    setup_screen
    local selection
    selection=$(
      {
        list_companies
        echo "🔎 Search"
        echo "🛠️ Manage"
        echo "⚙️ Settings"
        echo "Quit"
      } | \
      render_filter "Select company…" ""
    ) || { clear_screen; return 0; }

    case "${selection}" in
      "🔎 Search")
        search_and_copy ;;
      "🛠️ Manage")
        manage_menu ;;
      "⚙️ Settings")
        settings_menu ;;
      "Quit")
        clear_screen; return 0 ;;
      *)
        # Selected a company: enter login browser, preselect last used if available
        LAST_LOGIN_SELECTED=""
        login_browser "${selection}" "${LAST_LOGIN_SELECTED-}"
        ;;
    esac
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


