#!/usr/bin/env bash

# Settings and demo-related helpers

demo_mode() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground "${THEME_PRIMARY}" $(style_bg_opt) --border normal --border-foreground "${THEME_BORDER}" --padding "${GUM_STYLE_PADDING:-"1 2"}" \
      --align center --width "$(term_cols)" \
      "${APP_NAME} ready" "Gum detected and CLI is executable."
  else
    echo "${APP_NAME} ready (plain mode)"
    echo "Tip: Install 'gum' for the full TUI."
  fi
}

change_master() {
  require_jq
  init_if_missing
  local current new1 new2 data
  current=$(prompt_master_password)
  data=$(openssl_decrypt "${current}" <"${DATA_FILE}")
  if command -v gum >/dev/null 2>&1; then
    new1=$(gum input --password --width "$(calc_input_width)" --padding "${GUM_INPUT_PADDING:-"0 1"}" $(gum_timeout_opt) --placeholder "Enter NEW master password") || { clear_screen; return 1; }
    new2=$(gum input --password --width "$(calc_input_width)" --padding "${GUM_INPUT_PADDING:-"0 1"}" $(gum_timeout_opt) --placeholder "Confirm NEW master password") || { clear_screen; return 1; }
  else
    printf "Enter NEW master password: " >&2; stty -echo; IFS= read -r new1; stty echo; printf "\n" >&2
    printf "Confirm NEW master password: " >&2; stty -echo; IFS= read -r new2; stty echo; printf "\n" >&2
  fi
  [ "${new1}" = "${new2}" ] || { echo "Passwords do not match" >&2; return 1; }
  rm -f "${SESSION_FILE}"
  write_cached_password "${new1}"
  printf "%s" "${data}" | save_json_from_stdin
  if command -v gum >/dev/null 2>&1; then
    gum_ok "🔑 Master password updated."
  else
    echo "Master password updated."
  fi
  return 0
}

# Settings submenu for master password and reset
settings_menu() {
  require_gum
  require_jq
  init_if_missing
  while true; do
    setup_screen
    local action

    action=$(gum choose --header "Settings" --height "$(calc_menu_height)" --padding "0 4 0 4" $(gum_width_opt choose "$(calc_input_width)") --select-if-one $(gum_timeout_opt) \
      "🔑 Change Master" \
      "♻️ Reset" \
      "⬅ Back") || { clear_screen; return 0; }

    case "${action}" in
      "🔑 Change Master"|"Change Master")
        change_master ;;
      "♻️ Reset"|"Reset")
        if gum confirm --affirmative "Reset" --negative "Cancel" --padding "${GUM_CONFIRM_PADDING:-"0 1"}" $(gum_timeout_opt) "This will DELETE your encrypted store and re-seed it. Continue?"; then
          rm -f "${DATA_FILE}" "${SESSION_FILE}" && init_if_missing && gum_err "Store reset with seed data."
        fi ;;
      *)
        return 0 ;;
    esac
  done
}


