# Horizontal frame width (e.g., borders) to subtract from available columns.
# Default 0; set FASTPW_HORIZONTAL_FRAME=2 if a bordered frame encloses content.
horizontal_frame() { printf "%s" "${FASTPW_HORIZONTAL_FRAME-0}"; }
#!/usr/bin/env bash

# UI and theming helpers using gum
init_theme() {
  # Defaults (sane, readable palette)
  THEME_PRIMARY=${THEME_PRIMARY-81}
  THEME_SECONDARY=${THEME_SECONDARY-111}
  THEME_ACCENT=${THEME_ACCENT-213}
  THEME_MATCH=${THEME_MATCH-219}
  THEME_CURSOR=${THEME_CURSOR-213}
  THEME_OK=${THEME_OK-120}
  THEME_WARN=${THEME_WARN-214}
  THEME_ERR=${THEME_ERR-203}
  THEME_BORDER=${THEME_BORDER-93}
  THEME_HEADER_FG=${THEME_HEADER_FG-213}
  THEME_BG=${THEME_BG-236}
  THEME_HEADER_BG=${THEME_HEADER_BG-0}
  THEME_CHOOSE_CURSOR=${THEME_CHOOSE_CURSOR-212}
  THEME_CHOOSE_SELECTED_FG=${THEME_CHOOSE_SELECTED_FG-213}
  THEME_CHOOSE_ITEM_FG=${THEME_CHOOSE_ITEM_FG-81}

  # Fun theme fixed palette
  THEME_PRIMARY=${THEME_PRIMARY-81}
  THEME_SECONDARY=${THEME_SECONDARY-111}
  THEME_ACCENT=${THEME_ACCENT-213}
  THEME_MATCH=${THEME_MATCH-219}
  THEME_CURSOR=${THEME_CURSOR-213}
  THEME_OK=${THEME_OK-120}
  THEME_WARN=${THEME_WARN-214}
  THEME_ERR=${THEME_ERR-203}
  THEME_BORDER=${THEME_BORDER-93}
  THEME_HEADER_FG=${THEME_HEADER_FG-${THEME_ACCENT}}
  THEME_BG=${THEME_BG-236}
  THEME_HEADER_BG=${THEME_HEADER_BG-0}
  THEME_CHOOSE_CURSOR=${THEME_CHOOSE_CURSOR-${THEME_CURSOR}}
  THEME_CHOOSE_SELECTED_FG=${THEME_CHOOSE_SELECTED_FG-${THEME_ACCENT}}
  THEME_CHOOSE_ITEM_FG=${THEME_CHOOSE_ITEM_FG-${THEME_PRIMARY}}
  # Spinner names
  THEME_SPINNER=${THEME_SPINNER-pulse}
  THEME_DONE_SPINNER=${THEME_DONE_SPINNER-globe}
}

init_theme

# Export consistent color theming for gum components
export_gum_theme() {
  if ! command -v gum >/dev/null 2>&1; then return 0; fi
  # Choose
  export GUM_CHOOSE_CURSOR_FOREGROUND="${THEME_CHOOSE_CURSOR}"
  export GUM_CHOOSE_SELECTED_FOREGROUND="${THEME_CHOOSE_SELECTED_FG}"
  export GUM_CHOOSE_ITEM_FOREGROUND="${THEME_CHOOSE_ITEM_FG}"
  export GUM_CHOOSE_HEADER_FOREGROUND="${THEME_HEADER_FG}"
  export GUM_CHOOSE_SELECTED_PREFIX="✔"
  export GUM_CHOOSE_UNSELECTED_PREFIX=" "
  # Filter
  export GUM_FILTER_PROMPT_FOREGROUND="${THEME_ACCENT}"
  export GUM_FILTER_CURSOR_FOREGROUND="${THEME_CURSOR}"
  export GUM_FILTER_MATCH_FOREGROUND="${THEME_MATCH}"
  export GUM_FILTER_TEXT_FOREGROUND="${THEME_PRIMARY}"
  export GUM_FILTER_HEADER_FOREGROUND="${THEME_HEADER_FG}"
  export GUM_FILTER_SELECTED_PREFIX="✔"
  export GUM_FILTER_UNSELECTED_PREFIX=" "
  # Input
  export GUM_INPUT_PROMPT_FOREGROUND="${THEME_ACCENT}"
  export GUM_INPUT_CURSOR_FOREGROUND="${THEME_CURSOR}"
  # Confirm
  export GUM_CONFIRM_PROMPT_FOREGROUND="${THEME_PRIMARY}"
  # Spin
  export GUM_SPIN_SPINNER_FOREGROUND="${THEME_ACCENT}"
  export GUM_SPIN_TITLE_FOREGROUND="${THEME_PRIMARY}"
}

export_gum_theme

# Compute and export dynamic Gum paddings so UI elements appear centered using padding only.
_export_gum_padding() {
  # Target content width mirrors input width clamping to keep things readable
  local cols target pad left_pad right_pad
  cols=$(term_cols)
  target=$(calc_input_width)
  pad=$(((cols - $(horizontal_frame) - target) / 2))
  if [ ${pad} -lt 0 ]; then pad=0; fi
  # Symmetric padding based solely on computed left padding
  left_pad=${pad}
  right_pad=${pad}
  # Export per-component paddings (can be overridden by environment)
  : "${GUM_CHOOSE_PADDING:=0 ${left_pad} 0 ${right_pad}}"; export GUM_CHOOSE_PADDING
  : "${GUM_FILTER_PADDING:=0 ${left_pad} 0 ${right_pad}}"; export GUM_FILTER_PADDING
  : "${GUM_INPUT_PADDING:=0 ${left_pad} 0 ${right_pad}}"; export GUM_INPUT_PADDING
  : "${GUM_CONFIRM_PADDING:=0 ${left_pad} 0 ${right_pad}}"; export GUM_CONFIRM_PADDING
  # Style/spin toasts keep a slimmer default unless overridden
  : "${GUM_STYLE_PADDING:=0 1}"; export GUM_STYLE_PADDING
  : "${GUM_SPIN_PADDING:=0 ${left_pad} 0 ${right_pad}}"; export GUM_SPIN_PADDING
}

# =========================================================================
# Standard UI constants and helpers for consistent UX
# =========================================================================

# Consistent back labels
BACK_LABEL() { printf "%s" "⬅ Back"; }
BACK_TO_LABEL() { printf "⬅ Back to %s" "$1"; }

# Hints shown in headers for each component type
_hint_choose() { printf "%s" "Hint: ↑/↓ move • Enter select • ESC back"; }
_hint_filter() { printf "%s" "Hint: type to filter • Enter select • ESC back"; }
_hint_input()  { printf "%s" "Hint: Enter submit • ESC cancel"; }
_hint_multi()  { printf "%s" "Hint: Space toggle • Enter confirm • ESC cancel"; }

# Centralized clipboard copy (cross-platform)
copy_to_clipboard() {
  # Usage: copy_to_clipboard "value"
  local v
  v="$1"
  if command -v pbcopy >/dev/null 2>&1; then printf "%s" "$v" | pbcopy
  elif command -v clip.exe >/dev/null 2>&1; then printf "%s" "$v" | clip.exe
  elif command -v wl-copy >/dev/null 2>&1; then printf "%s" "$v" | wl-copy
  elif command -v xclip >/dev/null 2>&1; then printf "%s" "$v" | xclip -selection clipboard
  elif command -v xsel >/dev/null 2>&1; then printf "%s" "$v" | xsel --clipboard --input
  else
    printf "%s" "$v"
    echo "(Clipboard tool not found; printed value instead)" >&2
  fi
}

# Perform clipboard copy with a spinner title
# Usage: copy_with_spin "title" "value"
copy_with_spin() {
  local title="$1"; shift || true
  local value="$1"
  with_spin "${title}" bash -c 'v="$1"; if command -v pbcopy >/dev/null 2>&1; then printf "%s" "$v" | pbcopy; elif command -v clip.exe >/dev/null 2>&1; then printf "%s" "$v" | clip.exe; elif command -v wl-copy >/dev/null 2>&1; then printf "%s" "$v" | wl-copy; elif command -v xclip >/dev/null 2>&1; then printf "%s" "$v" | xclip -selection clipboard; elif command -v xsel >/dev/null 2>&1; then printf "%s" "$v" | xsel --clipboard --input; else printf "%s" "$v"; echo "(Clipboard tool not found; printed value instead)" >&2; fi' _ "${value}"
}

# Calculate menu padding for consistent centering across all menus
# Usage: calc_menu_padding <menu_width>
# Returns: padding string "0 <pad> 0 <pad>" for use with gum --padding
calc_menu_padding() {
  local menu_width=${1}
  local cols menu_pad gum_padding
  cols=$(term_cols)
  gum_padding=4  # Gum's internal padding
  menu_pad=$(( (cols - menu_width - gum_padding) / 2 + 9 ))  # +9 to move right
  if [ ${menu_pad} -lt 4 ]; then menu_pad=4; fi  # Minimum padding
  printf "0 %d 0 %d" "${menu_pad}" "${menu_pad}"
}




# Gum feature detection and helpers (with simple caching)
gum_timeout_opt() {
  # Emits: --timeout "<Ns>" if FASTPW_TIMEOUT is a positive integer
  local t
  t=${FASTPW_TIMEOUT-}
  if [ -n "${t}" ] && printf "%s" "${t}" | grep -Eq '^[0-9]+$' && [ "${t}" -gt 0 ]; then
    printf -- "--timeout %ss" "${t}"
  fi
}
gum_has_style_background() {
  if ! command -v gum >/dev/null 2>&1; then return 1; fi
  if [ -z "${_GUM_HAS_STYLE_BG-}" ]; then
    if gum style --help 2>&1 | grep -q -- "--background"; then
      _GUM_HAS_STYLE_BG=1
    else
      _GUM_HAS_STYLE_BG=0
    fi
  fi
  [ "${_GUM_HAS_STYLE_BG}" = "1" ]
}

style_bg_opt() {
  if gum_has_style_background; then
    printf -- "--background %s" "${THEME_BG}"
  fi
}

style_header_bg_opt() {
  if gum_has_style_background; then
    printf -- "--background %s" "${THEME_HEADER_BG}"
  fi
}

# Return "--width N" for a gum subcommand if it supports width; else nothing.
gum_width_opt() {
  # Usage: gum_width_opt <subcommand> <width>
  if ! command -v gum >/dev/null 2>&1; then return 0; fi
  local sub w
  sub="$1"; w="$2"
  # Cache per subcommand support to avoid repeated help parsing
  local var="_GUM_HAS_WIDTH_${sub//[^A-Za-z0-9_]/_}"
  if [ -z "${!var-}" ]; then
    if gum "$sub" --help 2>&1 | grep -q -- "--width"; then
      printf -v "$var" '%s' 1
    else
      printf -v "$var" '%s' 0
    fi
    # Export for future lookups within this shell
    export "$var"
  fi
  if [ "${!var}" = "1" ]; then
    printf -- "--width %s" "$w"
  fi
}
print_header() {
  if command -v gum >/dev/null 2>&1; then
    _export_gum_padding
    local w
    w=$(term_cols)
    # Use a reasonable width for the header box instead of full terminal width
    local header_width=$((w-2))
    if [ ${w} -lt ${header_width} ]; then header_width=${w}; fi

    # Center the header box on the "||" alignment markers (at cols/2)
    local center_pos=$((w / 2))
    local left_padding=$((center_pos - header_width / 2))
    if [ ${left_padding} -lt 0 ]; then left_padding=0; fi

    gum style --border double --padding "0 0 0 ${left_padding}" \
      --width "${header_width}" \
      --foreground "${THEME_HEADER_FG}" --border-foreground "${THEME_BORDER}" $(style_header_bg_opt) \
      "✨ ${APP_NAME}" "password manager CLI" "v${APP_VERSION}"
  else
    echo "${APP_NAME} (v${APP_VERSION})"
    echo "password manager CLI"
    echo
  fi
}

# Terminal sizing helpers (robust fallback chain)
term_cols() {
  local v
  v=${COLUMNS-}
  if [ -n "${v}" ] && printf "%s" "${v}" | grep -Eq '^[0-9]+$' && [ "${v}" -gt 0 ]; then
    printf "%s" "${v}"; return 0
  fi
  # First, try stty on stdin (works in most terminals)
  v=$(stty size 2>/dev/null | awk '{print $2}')
  if [ -n "${v}" ] && printf "%s" "${v}" | grep -Eq '^[0-9]+$' && [ "${v}" -gt 0 ]; then
    printf "%s" "${v}"; return 0
  fi
  # macOS: -f /dev/tty; Linux: read from /dev/tty
  v=$(stty -f /dev/tty size 2>/dev/null | awk '{print $2}')
  if [ -z "${v}" ]; then v=$(stty size </dev/tty 2>/dev/null | awk '{print $2}'); fi
  if [ -n "${v}" ] && printf "%s" "${v}" | grep -Eq '^[0-9]+$' && [ "${v}" -gt 0 ]; then
    printf "%s" "${v}"; return 0
  fi
  if command -v resize >/dev/null 2>&1; then
    v=$(resize 2>/dev/null | awk -F= '/COLUMNS/ {gsub(";","",$2); print $2}')
    if [ -n "${v}" ] && printf "%s" "${v}" | grep -Eq '^[0-9]+$' && [ "${v}" -gt 0 ]; then
      printf "%s" "${v}"; return 0
    fi
  fi
  if command -v tput >/dev/null 2>&1; then
    v=$(tput cols 2>/dev/null)
    if [ -n "${v}" ] && printf "%s" "${v}" | grep -Eq '^[0-9]+$' && [ "${v}" -gt 0 ]; then
      printf "%s" "${v}"; return 0
    fi
  fi
  printf "%s" "80"
}
term_lines() {
  local v
  v=${LINES-}
  if [ -n "${v}" ] && printf "%s" "${v}" | grep -Eq '^[0-9]+$' && [ "${v}" -gt 0 ]; then
    printf "%s" "${v}"; return 0
  fi
  v=$(stty size 2>/dev/null | awk '{print $1}')
  if [ -n "${v}" ] && printf "%s" "${v}" | grep -Eq '^[0-9]+$' && [ "${v}" -gt 0 ]; then
    printf "%s" "${v}"; return 0
  fi
  v=$(stty -f /dev/tty size 2>/dev/null | awk '{print $1}')
  if [ -z "${v}" ]; then v=$(stty size </dev/tty 2>/dev/null | awk '{print $1}'); fi
  if [ -n "${v}" ] && printf "%s" "${v}" | grep -Eq '^[0-9]+$' && [ "${v}" -gt 0 ]; then
    printf "%s" "${v}"; return 0
  fi
  if command -v resize >/dev/null 2>&1; then
    v=$(resize 2>/dev/null | awk -F= '/LINES/ {gsub(";","",$2); print $2}')
    if [ -n "${v}" ] && printf "%s" "${v}" | grep -Eq '^[0-9]+$' && [ "${v}" -gt 0 ]; then
      printf "%s" "${v}"; return 0
    fi
  fi
  if command -v tput >/dev/null 2>&1; then
    v=$(tput lines 2>/dev/null)
    if [ -n "${v}" ] && printf "%s" "${v}" | grep -Eq '^[0-9]+$' && [ "${v}" -gt 0 ]; then
      printf "%s" "${v}"; return 0
    fi
  fi
  printf "%s" "24"
}
calc_body_height() {
  local lines min padding h
  lines=$(term_lines)
  min=8
  padding=8
  h=$((lines - padding))
  if [ ${h} -lt ${min} ]; then
    printf "%s" "${min}"
  else
    printf "%s" "${h}"
  fi
}

# Estimated header height in terminal rows (content 3 + padding 2 + border 2)
header_height() { printf "%s" "7"; }

# Height for menus/lists that leaves space for vertical centering
calc_menu_height() {
  local lines min margin h max_h hdr
  lines=$(term_lines)
  min=8
  hdr=$(header_height)
  # Leave at least 4 rows spare below header to allow centering
  margin=$((hdr + 4))
  h=$((lines - margin))
  # Clamp to calc_body_height as an upper bound
  max_h=$(calc_body_height)
  if [ ${h} -gt ${max_h} ]; then h=${max_h}; fi
  if [ ${h} -lt ${min} ]; then
    printf "%s" "${min}"
  else
    printf "%s" "${h}"
  fi
}

# Print N blank lines
print_vspace() {
  local n
  n=${1-0}
  if [ -z "${n}" ] || [ "${n}" -le 0 ]; then return 0; fi
  local i=0
  while [ ${i} -lt ${n} ]; do
    printf "\n"
    i=$((i + 1))
  done
}

# Center the upcoming interactive body vertically based on terminal height
# Usage: center_body [body_height]
center_body() {
  local body lines top spare
  _export_gum_padding
  body=${1-$(calc_body_height)}
  lines=$(term_lines)
  spare=$((lines - $(header_height) - body))
  if [ ${spare} -le 0 ]; then return 0; fi
  top=$((spare / 2))
  # Only print vertical space if stdout is a TTY; avoid breaking piped output
  if [ -t 1 ]; then
    print_vspace "${top}"
  fi
}

# Compute a good input width given terminal columns, with clamping
calc_input_width() {
  local cols min max margin w
  cols=$(term_cols)
  min=${FASTPW_MIN_CONTENT_WIDTH-30}
  margin=${FASTPW_HORIZONTAL_MARGIN-10}
  w=$((cols - margin - $(horizontal_frame)))
  # By default, allow using the full available width minus margin; cap is overridable
  max=${FASTPW_MAX_CONTENT_WIDTH-${w}}
  # Initial clamp to [min, max]
  if [ ${w} -lt ${min} ]; then
    w=${min}
  elif [ ${w} -gt ${max} ]; then
    w=${max}
  fi
  # Adjust width parity so (cols - w) is even, enabling perfect symmetric padding
  if [ $(((cols - w) % 2)) -ne 0 ]; then
    w=$((w - 1))
  fi
  # Final safety clamp to fit terminal width (leave at least 2 cols for borders/margins)
  if [ ${w} -gt $((cols - 2)) ]; then
    w=$((cols - 2))
  fi
  if [ ${w} -lt 1 ]; then
    w=1
  fi
  printf "%s" "${w}"
}

# Clear the terminal screen in a portable way
clear_screen() {
  # Prefer tput if available to respect terminal capabilities
  if command -v tput >/dev/null 2>&1; then
    # Reset can be slow; use clear with cursor home for snappiness
    tput clear 2>/dev/null || printf "\033[2J"
    # Also clear scrollback where supported (xterm: ESC[3J)
    printf "\033[3J" 2>/dev/null || true
    tput cup 0 0 2>/dev/null || printf "\033[H"
  else
    printf "\033[2J\033[3J\033[H"
  fi
}

# Compact success toast with a short pause for UX polish
post_copy_animation() {
  # Usage: post_copy_animation "message"
  local msg
  msg=${1-}
  [ -z "${msg}" ] && return 0
  if command -v gum >/dev/null 2>&1; then
    local w banner_width
    w=$(term_cols)
    banner_width=$((w-2))
    if [ ${w} -lt ${banner_width} ]; then banner_width=${w}; fi
    gum style --border rounded --padding "0 2" --margin "1 0" \
      --align center --width "${banner_width}" \
      --border-foreground "${THEME_BORDER}" --foreground "${THEME_OK}" $(style_bg_opt) \
      "✅ ${msg}"
  else
    echo "${msg}"
  fi
  # Brief pause so users can register the success
  sleep 1.3
}

gum_ok() {
  gum style --foreground "${THEME_OK}" $(style_bg_opt) --padding "${GUM_STYLE_PADDING:-"0 1"}" --bold "$@"
}

gum_warn() {
  gum style --foreground "${THEME_WARN}" $(style_bg_opt) --padding "${GUM_STYLE_PADDING:-"0 1"}" --bold "$@"
}

gum_err() {
  gum style --foreground "${THEME_ERR}" $(style_bg_opt) --padding "${GUM_STYLE_PADDING:-"0 1"}" --bold "$@"
}

with_spin() {
  # Usage: with_spin "message" command args...
  local msg="$1"; shift || true
  if command -v gum >/dev/null 2>&1; then
    gum spin --spinner "${THEME_SPINNER}" --title "$msg" --padding "${GUM_SPIN_PADDING:-"0 1"}" $(gum_timeout_opt) --show-output -- "$@"
  else
    "$@"
  fi
}

# Small celebratory toast without delays
celebrate() {
  # Usage: celebrate "message"
  local msg
  msg=${1-}
  if [ -z "$msg" ]; then return 0; fi
  if command -v gum >/dev/null 2>&1; then
    local w banner_width
    w=$(term_cols)
    banner_width=$((w-2))
    if [ ${w} -lt ${banner_width} ]; then banner_width=${w}; fi
    gum style --border rounded --padding "0 2" --margin "1 0" \
      --align center --width "${banner_width}" \
      --border-foreground "${THEME_BORDER}" --foreground "${THEME_OK}" $(style_bg_opt) \
      "🎉 ${msg}"
  else
    echo "${msg}"
  fi
}

# Simple "Done" pause screen similar to Omarchy's omarchy-show-done
show_done_pause() {
  if ! command -v gum >/dev/null 2>&1; then return 0; fi
  # Skip pause in non-interactive environments (like tests) or when FASTPW_NO_PAUSE is set
  if [ ! -t 0 ] || [ "${FASTPW_NO_PAUSE-}" = "1" ]; then return 0; fi
  echo
  gum spin --spinner "${THEME_DONE_SPINNER}" --title "Done! Press any key to close..." -- bash -c 'read -n 1 -s'
}

require_gum() {
  if ! command -v gum >/dev/null 2>&1; then
    echo "Error: 'gum' is required for the interactive UI." >&2
    echo "Install instructions:" >&2
    echo "- macOS: brew install charmbracelet/tap/gum" >&2
    echo "- Linux (deb): echo 'deb [trusted=yes] https://repo.charm.sh/apt/ /' | sudo tee /etc/apt/sources.list.d/charm.list && sudo apt update && sudo apt install gum" >&2
    echo "- Linux (rpm): sudo dnf copr enable charmbracelet/gum && sudo dnf install gum" >&2
    echo "- Windows (WSL): use the Linux instructions for your distro (apt/dnf/pacman)" >&2
    exit 1
  fi
  # Ensure padding is computed before invoking any gum UI
  _export_gum_padding
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: 'jq' is required for JSON parsing." >&2
    echo "Install instructions:" >&2
    echo "- macOS: brew install jq" >&2
    echo "- Ubuntu/Debian: sudo apt-get install -y jq" >&2
    echo "- Fedora: sudo dnf install -y jq" >&2
    echo "- Windows (WSL): use your distro package manager to install jq" >&2
    exit 1
  fi
}

# ============================================================================
# STANDARDIZED UI FUNCTIONS - Use these across all menus for consistency
# ============================================================================

# Standardized menu padding calculation - consistent across all menus
get_standard_menu_padding() {
  local cols
  cols=$(term_cols)
  # Use consistent left margin for all menus (no centering)
  printf "%s" "4"
}

# Standardized filter padding calculation - consistent across all filters
get_standard_filter_padding() {
  local cols
  cols=$(term_cols)
  # Use consistent left margin for all filters (no centering)
  printf "%s" "4"
}

# Standardized menu rendering function
# Usage: render_menu item1 item2 ... OR render_menu --header "Header" item1 item2 ...
render_menu() {
  require_gum
  local header=""
  local items=()
  local menu_pad

  # Check for --header flag
  if [ "$1" = "--header" ]; then
    header="$2"
    shift 2
  fi

  # Remaining args are menu items
  items=("$@")

  menu_pad=$(get_standard_menu_padding)

  if [ -n "$header" ]; then
    local combined_header
    combined_header=$(printf "%s\n%s" "$header" "$(_hint_choose)")
    gum choose --header "$combined_header" --height "$(calc_menu_height)" --padding "0 ${menu_pad} 0 4" $(gum_width_opt choose "$(calc_input_width)") --select-if-one $(gum_timeout_opt) "${items[@]}"
  else
    GUM_CHOOSE_CURSOR_FOREGROUND="${THEME_CHOOSE_CURSOR}" \
    GUM_CHOOSE_SELECTED_FOREGROUND="${THEME_CHOOSE_SELECTED_FG}" \
    GUM_CHOOSE_ITEM_FOREGROUND="${THEME_CHOOSE_ITEM_FG}" \
    GUM_CHOOSE_SELECTED_PREFIX="✔" \
    GUM_CHOOSE_UNSELECTED_PREFIX=" " \
    gum choose --header "$(_hint_choose)" --height "$(calc_menu_height)" --padding "0 ${menu_pad} 0 4" --select-if-one $(gum_timeout_opt) "${items[@]}"
  fi
}

# Standardized multi-select menu
# Usage: render_menu_multi [--header "Header"] item1 item2 ...
render_menu_multi() {
  require_gum
  local header=""
  local items=()
  local menu_pad

  if [ "$1" = "--header" ]; then
    header="$2"
    shift 2
  fi
  items=("$@")
  menu_pad=$(get_standard_menu_padding)

  local combined_header
  if [ -n "$header" ]; then combined_header=$(printf "%s\n%s" "$header" "$(_hint_multi)"); else combined_header="$(_hint_multi)"; fi
  gum choose --no-limit --header "$combined_header" --height "$(calc_body_height)" --padding "0 ${menu_pad} 0 4" $(gum_width_opt choose "$(calc_input_width)") "${items[@]}"
}

# Standardized filter rendering function
# Usage: render_filter <placeholder> [header]
render_filter() {
  require_gum
  local placeholder="$1"
  local header="$2"
  local filter_pad

  filter_pad=$(get_standard_filter_padding)

  if [ -n "$header" ]; then
    local combined_header
    combined_header=$(printf "%s\n%s" "$header" "$(_hint_filter)")
    cat | gum filter --header "$combined_header" --placeholder "$placeholder" --height "$(calc_body_height)" --padding "0 ${filter_pad} 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt)
  else
    cat | gum filter --header "$(_hint_filter)" --placeholder "$placeholder" --height "$(calc_body_height)" --padding "0 ${filter_pad} 0 4" $(gum_width_opt filter "$(calc_input_width)") --select-if-one $(gum_timeout_opt)
  fi
}

# Standardized input rendering function
# Usage: render_input <placeholder> [prompt]
render_input() {
  require_gum
  local placeholder="$1"
  local prompt="$2"

  if [ -n "$prompt" ]; then
    gum input --placeholder "$placeholder" --prompt "$prompt" --width "$(calc_input_width)" --padding "${GUM_INPUT_PADDING:-"0 1"}" $(gum_timeout_opt)
  else
    gum input --placeholder "$placeholder" --width "$(calc_input_width)" --padding "${GUM_INPUT_PADDING:-"0 1"}" $(gum_timeout_opt)
  fi
}

# Standardized password input rendering function
# Usage: render_password <placeholder> [prompt]
render_password() {
  require_gum
  local placeholder="$1"
  local prompt="$2"

  if [ -n "$prompt" ]; then
    gum input --password --placeholder "$placeholder" --prompt "$prompt" --width "$(calc_input_width)" --padding "${GUM_INPUT_PADDING:-"0 1"}" $(gum_timeout_opt)
  else
    gum input --password --placeholder "$placeholder" --width "$(calc_input_width)" --padding "${GUM_INPUT_PADDING:-"0 1"}" $(gum_timeout_opt)
  fi
}

# Standardized confirm dialog function
# Usage: render_confirm <message> [affirmative] [negative]
render_confirm() {
  require_gum
  local message="$1"
  local affirmative="${2:-Yes}"
  local negative="${3:-No}"

  gum confirm --affirmative "$affirmative" --negative "$negative" --padding "${GUM_CONFIRM_PADDING:-"0 1"}" $(gum_timeout_opt) "$message"
}

# Standardized screen setup (no centering)
setup_screen() {
  clear_screen
  print_header
}

# Standardized submenu setup (no centering)
setup_submenu() {
  clear_screen
  print_header
}
