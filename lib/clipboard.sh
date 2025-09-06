#!/usr/bin/env bash

# Clipboard copy helper (expects platform helpers loaded)
clipboard_copy() {
  # Copies stdin to clipboard in a cross-platform way
  if is_macos && command -v pbcopy >/dev/null 2>&1; then
    pbcopy
  elif is_wsl && command -v clip.exe >/dev/null 2>&1; then
    clip.exe
  elif command -v wl-copy >/dev/null 2>&1; then
    wl-copy
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard
  elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --input
  else
    # Fallback: print and warn
    cat
    echo "(Clipboard tool not found; printed value instead)" >&2
  fi
}
