#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work=${COSMIC_PROBE_BUILD_ROOT:-"$HOME/.cache/cosmic-frame-timing/presentation-probe"}
mkdir -p "$work"
protocols=$(pkg-config --variable=pkgdatadir wayland-protocols)

wayland-scanner client-header "$protocols/stable/xdg-shell/xdg-shell.xml" "$work/xdg-shell-client-protocol.h"
wayland-scanner private-code "$protocols/stable/xdg-shell/xdg-shell.xml" "$work/xdg-shell-protocol.c"
wayland-scanner client-header "$protocols/stable/presentation-time/presentation-time.xml" "$work/presentation-time-client-protocol.h"
wayland-scanner private-code "$protocols/stable/presentation-time/presentation-time.xml" "$work/presentation-time-protocol.c"

# pkg-config deliberately returns separate compiler arguments.
cc -O2 -Wall -I"$work" "$here/presentation-probe.c" \
    "$work/xdg-shell-protocol.c" "$work/presentation-time-protocol.c" \
    -o "$work/probe" $(pkg-config --cflags --libs wayland-client wayland-egl egl gl)
printf '%s\n' "$work/probe"
