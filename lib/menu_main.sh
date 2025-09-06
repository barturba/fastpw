#!/usr/bin/env bash

# Main menu and entry points

show_main_menu() {
  require_gum
  require_jq
  init_if_missing
  while true; do
    setup_screen
    local action

    action=$(gum choose --height "$(calc_menu_height)" --padding "0 4 0 4" $(gum_width_opt choose "$(calc_input_width)") --select-if-one $(gum_timeout_opt) \
      "🔎 Search" \
      "🗂️ Browse & Copy" \
      "➕ Add Login" \
      "🛠️ Manage" \
      "⚙️ Settings" \
      "🚪 Logout" \
      "Quit") || { clear_screen; return 0; }


    case "${action}" in
      *"🔎 Search"*)
        search_and_copy ;;
      *"🗂️ Browse & Copy"*)
        browse_and_copy ;;
      *"➕ Add Login"*)
        interactive_add_login ;;
      *"🛠️ Manage"*)
        manage_menu ;;
      *"⚙️ Settings"*)
        settings_menu ;;
      *"🚪 Logout"*)
        if gum confirm --affirmative "Yes" --negative "No" --padding "${GUM_CONFIRM_PADDING:-"0 1"}" $(gum_timeout_opt) "Logout and clear session?"; then
          rm -f "${SESSION_FILE}" && gum_warn "Session cleared."
        fi ;;
      *"Quit"*)
        clear_screen
        return 0 ;;
      *)
        clear_screen
        return 0 ;;
    esac
  done
}


