#!/bin/sh
# Build only cosmic-comp, with an opt-in diagnostic timing override.
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
commit=8cb1802caada438bb5cc7670dfabdaca5fad0502
work=${COSMIC_DIAG_BUILD_ROOT:-"$HOME/.cache/cosmic-frame-timing/$commit"}
mkdir -p "$work"
work=$(CDPATH= cd -- "$work" && pwd)
source_dir=$work/source

if [ ! -f "$source_dir/Cargo.toml" ]; then
    if [ -d "$source_dir" ] && [ -n "$(ls -A "$source_dir")" ]; then
        printf '%s\n' "Source directory is not empty: $source_dir" >&2
        exit 1
    fi
    mkdir -p "$source_dir" "$work/upstream"
    git -C "$work/upstream" init -q
    git -C "$work/upstream" fetch -q --depth 1 https://github.com/pop-os/cosmic-comp.git "$commit"
    git -C "$work/upstream" archive --output="$work/source.tar" FETCH_HEAD
    tar -xf "$work/source.tar" -C "$source_dir"
    rm "$work/source.tar"
fi

if ! (cd "$source_dir" && patch --batch -s --dry-run -R -p1 < "$here/frame-timing.patch") >/dev/null 2>&1; then
    (cd "$source_dir" && patch --batch --forward -p1 < "$here/frame-timing.patch")
fi

export SOURCE_GIT_HASH=$commit
export CARGO_NET_GIT_FETCH_WITH_CLI=true
export CARGO_BUILD_JOBS=${CARGO_BUILD_JOBS:-2}
export CARGO_INCREMENTAL=1
export CARGO_PROFILE_RELEASE_LTO=false
export CARGO_PROFILE_RELEASE_DEBUG=0
export CARGO_TARGET_DIR=$work/target

cargo build --release --locked --bin cosmic-comp --manifest-path "$source_dir/Cargo.toml"
printf '%s\n' "$CARGO_TARGET_DIR/release/cosmic-comp"
sha256sum "$CARGO_TARGET_DIR/release/cosmic-comp"
