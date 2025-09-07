#!/usr/bin/env bash

# Manage submenu trees: companies and logins

manage_menu() {
  require_gum
  require_jq
  init_if_missing
  while true; do
    setup_screen
    local action

    action=$(render_menu --header "Manage" \
      "🏢 Companies" \
      "🔐 Logins" \
      "$(BACK_LABEL)") || { clear_screen; return 0; }

    case "${action}" in
      "🏢 Companies"|"Companies")
        manage_companies_menu ;;
      "🔐 Logins"|"Logins")
        manage_logins_menu ;;
      *)
        return 0 ;;
    esac
  done
}

# Companies management (full CRUD)
manage_companies_menu() {
  require_gum
  require_jq
  init_if_missing
  while true; do
    setup_submenu
    local action

    action=$(render_menu --header "🏢 Companies – choose an action" \
      "➕ Add Company" "✏️ Rename Company" "🗑️ Remove Company" "↕️ Move Company" "$(BACK_LABEL)") || { clear_screen; return 0; }
    case "${action}" in
      "➕ Add Company")
        local name
        name=$(render_input "New company name" "🏢 ") || { clear_screen; continue; }
        [ -n "${name}" ] || { gum_warn "Name required"; continue; }
        company_add "${name}" && celebrate "Added ${name}."
        ;;
      "✏️ Rename Company")
        local old new
        old=$(list_companies | render_filter "Select company…" "") || { clear_screen; continue; }
        [ -n "${old}" ] || continue
        new=$(render_input "New name" "✏️ ") || { clear_screen; continue; }
        [ -n "${new}" ] || { gum_warn "New name required"; continue; }
        company_rename "${old}" "${new}" && celebrate "Renamed ${old} → ${new}."
        ;;
      "🗑️ Remove Company")
        local target
        target=$(list_companies | render_filter "Select company to remove…" "") || { clear_screen; continue; }
        [ -n "${target}" ] || continue
        if ! render_confirm "Delete '${target}' and ALL its logins?" "Yes" "No"; then
          clear_screen; continue; fi
        company_rm "${target}" && gum_ok "Removed ${target}."
        ;;
      "↕️ Move Company")
        local nm idx count
        nm=$(list_companies | render_filter "Select company to move…" "") || { clear_screen; continue; }
        [ -n "${nm}" ] || continue
        count=$(list_companies | wc -l | tr -d ' ')
        idx=$(render_input "Target index (0..$((count-1)))" "# ") || { clear_screen; continue; }
        idx=${idx:-0}
        company_mv "${nm}" "${idx}" && gum_ok "Moved ${nm} to index ${idx}."
        ;;
      *)
        return 0 ;;
    esac
  done
}

# Logins management (full CRUD)
manage_logins_menu() {
  require_gum
  require_jq
  init_if_missing
  while true; do
    setup_submenu
    local company

    company=$(list_companies | render_filter "Select company…" "") || { clear_screen; return 0; }
    [ -n "${company}" ] || return 0
    while true; do
      setup_submenu
      local action

      action=$(render_menu --header "🔐 Logins @ ${company} – choose an action" \
        "➕ Add Login" "✏️ Rename Login" "🗑️ Remove Login" "🗑️ Remove Login(s)" "↕️ Move Login" "$(BACK_LABEL)") || { clear_screen; break; }
      case "${action}" in
        "➕ Add Login")
          interactive_add_login_for_company "${company}"
          ;;
        "✏️ Rename Login")
          local ln new
          ln=$(list_logins_for_company "${company}" | render_filter "Select login to rename…" "Company: ${company}") || { clear_screen; continue; }
          [ -n "${ln}" ] || continue
          new=$(render_input "New login name" "✏️ ") || { clear_screen; continue; }
          [ -n "${new}" ] || { gum_warn "New name required"; continue; }
          login_rename "${company}" "${ln}" "${new}" && celebrate "Renamed ${ln} → ${new}."
          ;;
        "🗑️ Remove Login")
          local ln
          ln=$(list_logins_for_company "${company}" | render_filter "Select login to remove…" "Company: ${company}") || { clear_screen; continue; }
          [ -n "${ln}" ] || continue
          if ! render_confirm "Delete '${ln}'?" "Yes" "No"; then
            clear_screen; continue; fi
          login_rm "${company}" "${ln}" && gum_ok "Removed ${ln}."
          ;;
        "🗑️ Remove Login(s)")
          local selected count ln
          # Multi-select with standardized header hints
          mapfile -t __items < <(list_logins_for_company "${company}")
          selected=$(render_menu_multi --header "Select logins to remove…" "${__items[@]}") || { clear_screen; continue; }
          [ -n "${selected}" ] || continue
          count=$(printf "%s\n" "${selected}" | sed '/^\s*$/d' | wc -l | tr -d ' ')
          if ! render_confirm "Delete ${count} selected login(s)?" "Delete" "Cancel"; then
            clear_screen; continue; fi
          while IFS= read -r ln; do
            [ -n "${ln}" ] || continue
            login_rm "${company}" "${ln}"
          done <<EOF
${selected}
EOF
          celebrate "Removed ${count} login(s) from ${company}."
          ;;
        "↕️ Move Login")
          local ln dest to_idx raw
          ln=$(list_logins_for_company "${company}" | render_filter "Select login to move…" "Company: ${company}") || { clear_screen; continue; }
          [ -n "${ln}" ] || continue
          dest=$( (echo "(keep ${company})"; list_companies) | render_filter "Destination company…" "") || { clear_screen; continue; }
          [ -n "${dest}" ] || continue
          if [ "${dest}" = "(keep ${company})" ]; then dest="${company}"; fi
          raw=$(render_input "Target index (leave blank to append)" "# ") || { clear_screen; continue; }
          if [ -z "${raw}" ]; then to_idx=-1; else to_idx="${raw}"; fi
          login_mv "${company}" "${ln}" "${dest}" "${to_idx}" && gum_ok "Moved ${ln} → ${dest} (idx ${to_idx})."
          ;;
        *)
          break ;;
      esac
    done
    # After finishing with a company, ask if we should pick another
    local again
    again=$(render_menu "choose another company" "back to main") || { clear_screen; return 0; }
    [ "${again}" = "choose another company" ] || return 0
  done
}


