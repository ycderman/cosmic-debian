# cosmic-debian

The COSMIC desktop built as Debian packages for Debian testing (forky), amd64.

Everything is built straight from the official System76 sources:

- the COSMIC parts at the commits pinned in a
  [cosmic-epoch](https://github.com/pop-os/cosmic-epoch) release,
- the Pop!_OS icons, fonts, sounds and GTK theme COSMIC depends on
  ([icon-theme](https://github.com/pop-os/icon-theme),
  [fonts](https://github.com/pop-os/fonts),
  [gtk-theme](https://github.com/pop-os/gtk-theme),
  [adw-gtk3](https://github.com/pop-os/adw-gtk3)).

The `debian/` folders are the upstream ones. The few changes needed for Debian
are in `fixes/`.

Every day the build checks for a new COSMIC release. When there is one, all
packages are built again in a clean `debian:testing` container and published
to an APT repository on GitHub Pages.

## Install

```sh
sudo curl -fsSLo /etc/apt/keyrings/cosmic-debian.asc https://ycderman.github.io/cosmic-debian/key.asc
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/cosmic-debian.asc] https://ycderman.github.io/cosmic-debian forky main" \
  | sudo tee /etc/apt/sources.list.d/cosmic-debian.list
sudo apt update
sudo apt install cosmic-session
```

`cosmic-greeter` brings in `greetd`. When asked for the default display
manager, pick the one you already use if you want to keep it.

After that, COSMIC shows up as a session on the login screen. Updates come
with the usual `apt upgrade`.

## Files

- `list.sh`: what to build for a COSMIC release
- `build.sh`: builds one package
- `repo.sh`: makes the signed APT repository
- `fixes/`: small Debian changes, one file per package
- [`diagnostics/`](diagnostics/README.md): optional frame timing comparison, separate from the published packages
