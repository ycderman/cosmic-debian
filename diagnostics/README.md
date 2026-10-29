# COSMIC frame timing experiment

This experiment tests whether extra render headroom prevents missed refreshes
in the KMS composition path. It is a diagnostic experiment, not a confirmed fix.
The normal build and normal COSMIC session are unaffected.

The patch targets cosmic-comp `8cb1802caada438bb5cc7670dfabdaca5fad0502`, from
COSMIC Epoch 1.11.0. It keeps the upstream 3 ms safety margin by default and adds
`COSMIC_FRAME_SAFETY_MARGIN_MS`. No visual effect, hardware acceleration or
scanout feature is disabled. An invalid override logs a warning and uses 3 ms.
The source archive's pinned commit is embedded in the version information.

## Build

Use Debian's development packages corresponding to upstream `debian/control`.
Then run:

```sh
sh diagnostics/build-frame-timing.sh
```

Only cosmic-comp and its dependencies are built. The release build explicitly
disables LTO and adds no PGO or BOLT step. Two build jobs are the default; set
`CARGO_BUILD_JOBS` to change that. `COSMIC_DIAG_BUILD_ROOT` selects the build
cache. The build reuses cached dependencies and does not edit an existing clone.

## Install and compare

```sh
sudo sh diagnostics/install-frame-timing.sh /absolute/path/to/target/release/cosmic-comp
```

This adds **COSMIC (timing test, 3 ms)** and **COSMIC (timing test, 6 ms)** to
the login screen. Both entries use the same binary, so the margin is the only
build-level difference. Save work before logging out to select a test session.
The original COSMIC entry and packaged `/usr/bin/cosmic-comp` stay available.

Compare the same display mode and workload in both test sessions. Allow shader
caches to warm up, then repeat the same windowed presentation-feedback probe
and scrolling/dragging workload. Compare presentation intervals and missed
refreshes, not only average FPS. Verify `Using diagnostic frame safety margin`
in the session journal and check the compositor executable in `/proc`.

The test launcher also sets `COSMIC_FRAME_SAFETY_MARGIN_FILE` to the private
runtime file `$XDG_RUNTIME_DIR/cosmic-frame-timing/safety-margin-ms`. Its integer
millisecond value can be replaced atomically while the test session runs. This
allows 3/6/3 comparisons in one session, avoiding extra logouts and workload
changes. The normal build has no such file access. In the diagnostic build, an
unset file override adds no file access; an unreadable or invalid file falls
back to `COSMIC_FRAME_SAFETY_MARGIN_MS` (or upstream's 3 ms default).

Build and run the presentation probe from a terminal in the test session:

```sh
sh /opt/cosmic-frame-timing/tools/build-probe.sh
python3 /opt/cosmic-frame-timing/tools/measure-frame-timing.py "$HOME/.cache/cosmic-frame-timing/presentation-probe/probe"
```

The launcher explicitly selects the native KMS backend. The measurement script
verifies the active diagnostic executable, KMS selection and margin
file, records its binary hash, runs a windowed 3/6/3 comparison, and restores
the original margin. It excludes each window's first two seconds from the
statistics. It requires `cc`, `pkg-config`, `wayland-scanner`,
`wayland-protocols`, and the Wayland/EGL/OpenGL development packages. The
probe's separate fullscreen and fixed-timer modes are not used by this test.
The installed tools and the user's measurement cache survive a reboot.

The compositor copies its existing state on first start into
`$XDG_STATE_HOME/cosmic-frame-timing/<margin>/` (normally under `~/.local/state`),
then uses that separate state directory. Appearance configuration is shared;
ordinary applications keep their normal configuration and state paths.

## Remove

Log back into the normal COSMIC or KDE session, then run:

```sh
sudo sh diagnostics/install-frame-timing.sh --remove
```

The removal leaves user state and measurement records intact. `DESTDIR` can be
used to stage the installation and removal for inspection without touching the
live login screen.
