#!/usr/bin/env bash

# Manage submenu trees: companies and logins

manage_menu() {
  require_gum
  require_jq
  init_if_missing
  while true; do
    setup_screen
    local action

    action=$(gum choose --header "Manage" --height "$(calc_menu_height)" --padding "0 4 0 4" $(gum_width_opt choose "$(calc_input_width)") --select-if-one $(gum_timeout_opt) \
      "🏢 Companies" \
      "🔐 Logins" \
      "⬅ Back") || { clear_screen; return 0; }

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

    action=$(gum choose --header "🏢 Companies – choose an action" --height "$(calc_menu_height)" --padding "0 4 0 4" $(gum_width_opt choose "$(calc_input_width)") --select-if-one $(gum_timeout_opt) \
      "➕ Add Company" "✏️ Rename Company" "🗑️ Remove Company" "↕️ Move Company" "⬅ Back") || { clear_screen; return 0; }
    case "${action}" in
      "➕ Add Company")
        local name
        name=$(gum input --placeholder "New company name" --prompt "🏢 " --width "$(calc_input_width)" --padding "${GUM_INPUT_PADDING:-"0 1"}" $(gum_timeout_opt)) || { clear_screen; continue; }
        [ -n "${name}" ] || { gum_warn "Name required"; continue; }
        company_add "${name}" && celebrate "Added ${name}."
        ;;
      "✏️ Rename Company")
        local old new
        old=$(list_companies | gum filter --height "$(calc_body_height)" --padding "0 4 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt) --placeholder "Select company…") || { clear_screen; continue; }
        [ -n "${old}" ] || continue
        new=$(gum input --placeholder "New name" --prompt "✏️ " --width "$(calc_input_width)" --padding "${GUM_INPUT_PADDING:-"0 1"}" $(gum_timeout_opt)) || { clear_screen; continue; }
        [ -n "${new}" ] || { gum_warn "New name required"; continue; }
        company_rename "${old}" "${new}" && celebrate "Renamed ${old} → ${new}."
        ;;
      "🗑️ Remove Company")
        local target
        target=$(list_companies | gum filter --height "$(calc_body_height)" --padding "0 4 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt) --placeholder "Select company to remove…") || { clear_screen; continue; }
        [ -n "${target}" ] || continue
        if ! gum confirm --affirmative "Yes" --negative "No" --padding "${GUM_CONFIRM_PADDING:-"0 1"}" $(gum_timeout_opt) "Delete '${target}' and ALL its logins?"; then
          clear_screen; continue; fi
        company_rm "${target}" && gum_ok "Removed ${target}."
        ;;
      "↕️ Move Company")
        local nm idx count
        nm=$(list_companies | gum filter --height "$(calc_body_height)" --padding "0 4 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt) --placeholder "Select company to move…") || { clear_screen; continue; }
        [ -n "${nm}" ] || continue
        count=$(list_companies | wc -l | tr -d ' ')
        idx=$(gum input --placeholder "Target index (0..$((count-1)))" --prompt "# " --width "$(calc_input_width)" --padding "${GUM_INPUT_PADDING:-"0 1"}" $(gum_timeout_opt)) || { clear_screen; continue; }
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

    company=$(list_companies | gum filter --height "$(calc_body_height)" --padding "0 4 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt) --placeholder "Select company…") || { clear_screen; return 0; }
    [ -n "${company}" ] || return 0
    while true; do
      setup_submenu
      local action

      action=$(gum choose --header "🔐 Logins @ ${company} – choose an action" --height "$(calc_menu_height)" --padding "0 4 0 4" $(gum_width_opt choose "$(calc_input_width)") --select-if-one $(gum_timeout_opt) \
        "➕ Add Login" "✏️ Rename Login" "🗑️ Remove Login" "🗑️ Remove Login(s)" "↕️ Move Login" "⬅ Back") || { clear_screen; break; }
      case "${action}" in
        "➕ Add Login")
          interactive_add_login_for_company "${company}"
          ;;
        "✏️ Rename Login")
          local ln new
          ln=$(list_logins_for_company "${company}" | gum filter --height "$(calc_body_height)" --padding "0 4 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt) --placeholder "Select login to rename…") || { clear_screen; continue; }
          [ -n "${ln}" ] || continue
          new=$(gum input --placeholder "New login name" --prompt "✏️ " --width "$(calc_input_width)" --padding "${GUM_INPUT_PADDING:-"0 1"}" $(gum_timeout_opt)) || { clear_screen; continue; }
          [ -n "${new}" ] || { gum_warn "New name required"; continue; }
          login_rename "${company}" "${ln}" "${new}" && celebrate "Renamed ${ln} → ${new}."
          ;;
        "🗑️ Remove Login")
          local ln
          ln=$(list_logins_for_company "${company}" | gum filter --height "$(calc_body_height)" --padding "0 4 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt) --placeholder "Select login to remove…") || { clear_screen; continue; }
          [ -n "${ln}" ] || continue
          if ! gum confirm --affirmative "Yes" --negative "No" --padding "${GUM_CONFIRM_PADDING:-"0 1"}" $(gum_timeout_opt) "Delete '${ln}'?"; then
            clear_screen; continue; fi
          login_rm "${company}" "${ln}" && gum_ok "Removed ${ln}."
          ;;
        "🗑️ Remove Login(s)")
          local selected count ln
          selected=$(list_logins_for_company "${company}" | gum choose --no-limit --header "Select logins to remove…" --selected-prefix="✗ " --height "$(calc_body_height)" --padding "0 4 0 4" $(gum_width_opt choose "$(calc_input_width)")) || { clear_screen; continue; }
          [ -n "${selected}" ] || continue
          count=$(printf "%s\n" "${selected}" | sed '/^\s*$/d' | wc -l | tr -d ' ')
          if ! gum confirm --affirmative "Delete" --negative "Cancel" --padding "${GUM_CONFIRM_PADDING:-"0 1"}" $(gum_timeout_opt) "Delete ${count} selected login(s)?"; then
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
          ln=$(list_logins_for_company "${company}" | gum filter --height "$(calc_body_height)" --padding "0 4 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt) --placeholder "Select login to move…") || { clear_screen; continue; }
          [ -n "${ln}" ] || continue
          dest=$( (echo "(keep ${company})"; list_companies) | gum filter --height "$(calc_body_height)" --padding "0 4 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt) --placeholder "Destination company…") || { clear_screen; continue; }
          [ -n "${dest}" ] || continue
          if [ "${dest}" = "(keep ${company})" ]; then dest="${company}"; fi
          raw=$(gum input --placeholder "Target index (leave blank to append)" --prompt "# " --width "$(calc_input_width)" --padding "${GUM_INPUT_PADDING:-"0 1"}" $(gum_timeout_opt)) || { clear_screen; continue; }
          if [ -z "${raw}" ]; then to_idx=-1; else to_idx="${raw}"; fi
          login_mv "${company}" "${ln}" "${dest}" "${to_idx}" && gum_ok "Moved ${ln} → ${dest} (idx ${to_idx})."
          ;;
        *)
          break ;;
      esac
    done
    # After finishing with a company, ask if we should pick another
    local again
    again=$(gum choose --height "$(calc_menu_height)" --padding "0 4 0 4" $(gum_width_opt choose "$(calc_input_width)") --select-if-one $(gum_timeout_opt) "choose another company" "back to main") || { clear_screen; return 0; }
    [ "${again}" = "choose another company" ] || return 0
  done
}


