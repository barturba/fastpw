#!/usr/bin/env bash

# Menu aggregator: source split modules and provide any remaining wrappers

_FASTPW_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
# shellcheck source=lib/flows.sh
. "${_FASTPW_LIB_DIR}/flows.sh"
# shellcheck source=lib/menu_main.sh
. "${_FASTPW_LIB_DIR}/menu_main.sh"
# shellcheck source=lib/menu_manage.sh
. "${_FASTPW_LIB_DIR}/menu_manage.sh"
# shellcheck source=lib/settings.sh
. "${_FASTPW_LIB_DIR}/settings.sh"

# Add login for a known company, collecting fields inline
interactive_add_login() {
  require_gum
  local company login

  company=$( (list_companies; echo "➕ New company…") | \
    render_filter "Choose or create company…" "") || { clear_screen; return 0; }
  if [ "${company}" = "➕ New company…" ]; then
    company=$(render_input "New company name" "🏢 ") || { clear_screen; return 1; }
    [ -n "${company}" ] || return 1
    company_add "${company}"
  fi
  interactive_add_login_for_company "${company}"
}
