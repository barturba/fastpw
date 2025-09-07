#!/usr/bin/env bash

# Main menu and entry points

show_main_menu() {
  require_gum
  require_jq
  init_if_missing
  while true; do
    setup_screen
    local action

    action=$(render_menu --header "Main Menu" \
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
        if render_confirm "Logout and clear session?" "Yes" "No"; then
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


