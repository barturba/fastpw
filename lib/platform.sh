#!/usr/bin/env bash

# Platform detection helpers
is_macos() { [ "$(uname -s)" = "Darwin" ]; }
is_linux() { [ "$(uname -s)" = "Linux" ]; }
is_wsl() { is_linux && grep -qi 'microsoft' /proc/version 2>/dev/null; }
