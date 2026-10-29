#!/bin/sh
# Install or remove separate test sessions; do not replace packaged binaries.
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
dest=${DESTDIR:-}
prefix=$dest/opt/cosmic-frame-timing
launcher=$dest/usr/local/bin/start-cosmic-frame-timing
sessions=$dest/usr/share/wayland-sessions
marker=$prefix/managed-by-cosmic-debian

if [ "${1:-}" = --remove ]; then
    if [ ! -f "$marker" ]; then
        printf '%s\n' 'No managed timing-test installation found.' >&2
        exit 1
    fi
    rm -f "$sessions/cosmic-frame-timing-3.desktop" "$sessions/cosmic-frame-timing-6.desktop" "$launcher"
    rm -f "$prefix/bin/cosmic-comp" "$prefix/libexec/cosmic-comp" "$marker" "$prefix/build.sha256"
    if [ -d "$prefix/tools" ]; then
        rm -f "$prefix/tools/build-probe.sh" "$prefix/tools/presentation-probe.c" "$prefix/tools/measure-frame-timing.py"
        rmdir "$prefix/tools"
    fi
    rmdir "$prefix/bin" "$prefix/libexec" "$prefix"
    exit
fi

binary=${1:?Usage: install-frame-timing.sh /path/to/built/cosmic-comp | --remove}
test -f "$binary"
if [ -d "$prefix" ] && [ ! -f "$marker" ]; then
    printf '%s\n' "Refusing to overwrite an unmanaged directory: $prefix" >&2
    exit 1
fi

if ! cmp -s "$binary" "$prefix/libexec/cosmic-comp"; then
    install -Dm0755 "$binary" "$prefix/libexec/cosmic-comp.new"
    mv "$prefix/libexec/cosmic-comp.new" "$prefix/libexec/cosmic-comp"
fi
install -Dm0755 "$here/cosmic-comp-wrapper" "$prefix/bin/cosmic-comp"
install -Dm0755 "$here/start-cosmic-frame-timing" "$launcher"
install -Dm0755 "$here/build-probe.sh" "$prefix/tools/build-probe.sh"
install -Dm0644 "$here/presentation-probe.c" "$prefix/tools/presentation-probe.c"
install -Dm0755 "$here/measure-frame-timing.py" "$prefix/tools/measure-frame-timing.py"
printf '%s\n' 'cosmic-debian frame timing diagnostics' > "$marker"
sha256sum "$prefix/libexec/cosmic-comp" > "$prefix/build.sha256"

mkdir -p "$sessions"
for margin in 3 6; do
    cat > "$sessions/cosmic-frame-timing-$margin.desktop" <<EOF
[Desktop Entry]
Name=COSMIC (timing test, $margin ms)
Name[tr]=COSMIC (zamanlama testi, $margin ms)
Comment=Diagnostic compositor session; compare with the normal COSMIC session
Exec=/usr/local/bin/start-cosmic-frame-timing $margin
Type=Application
DesktopNames=COSMIC
EOF
done

printf '%s\n' 'Installed separate COSMIC timing test sessions (3 ms and 6 ms).'
